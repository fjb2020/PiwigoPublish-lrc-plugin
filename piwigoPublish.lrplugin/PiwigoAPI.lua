--[[

    PiwigoAPI.lua

    lua functions to accss the Piwigo Web API
    see https://github.com/Piwigo/Piwigo/wiki/Piwigo-Web-API

    Copyright (C) 2024 Fiona Boston <fiona@fbphotography.uk>.

    This file is part of PiwigoPublish

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

local PiwigoAPI = {}

-- *************************************************
-- L O C A L   F U N C T I O N S
-- *************************************************

-- *************************************************
local function httpGet(url, params, headers)
    -- generic function to call LrHttp.Get
    local getResponse = {}
    local getUrl = utils.buildGet(url, params)

    log:info("PWAPI.httpGet - calling " .. getUrl)
    log:info("PWAPI.httpGet - headers are " .. utils.serialiseVar(headers))

    local body, hdrs = LrHttp.get(getUrl, headers)

    --log:info("PWAPI.httpGet - httpHeaders\n" .. utils.serialiseVar(hdrs))
    --log:info("PWAPI.httpGet - httpResponse\n" .. utils.serialiseVar(body))

    -- Missing or empty HTTP body
    if not body then
        getResponse.status = "error"
        getResponse.errormessage = "No response body received"
        getResponse.response = nil
        return getResponse
    end

    -- HTTP status check
    local statusCode = hdrs and hdrs.status or nil
    if not statusCode or statusCode < 200 or statusCode > 299 then
        getResponse.status = "error"
        getResponse.errorMessage = string.format("HTTP error %s", tostring(statusCode))
        getResponse.response = nil
        return getResponse
    end

    -- Try decoding JSON
    local decoded = JSON:decode(body)
    if not decoded then
        getResponse.status = "error"
        getResponse.errorMessage = "Failed to parse JSON: " .. utils.serialiseVar(body)
        getResponse.response = nil
        return getResponse
    end

    -- Piwigo API uses its own status
    if decoded.stat == "fail" or decoded.status == "fail" then
        getResponse.status = "error"
        getResponse.errorMessage = decoded.err .. " - " .. decoded.message
        getResponse.response = decoded
        return getResponse
    end

    -- Return success
    getResponse.status = "ok"
    getResponse.errorMessage = nil
    getResponse.response = decoded
    return getResponse
end

-- *************************************************
local function httpPost(propertyTable, params, headers)
    -- generic function to call LrHttp.Post
    -- LrHttp.post( url, postBody, headers, method, timeout, totalSize )

    -- convert table of name, value pairs to a urlencoded string
    local body = utils.buildBodyFromParams(params)

    log:info("PiwigoAPI.pwConnect - connecting to " .. propertyTable.pwurl)
    log:info("PiwigoAPI.pwConnect - body:\n" .. utils.serialiseVar(body))

    local httpResponse, httpHeaders = LrHttp.post(propertyTable.pwurl, body, headers)

    log:info("PiwigoAPI.pwConnect - response headers:\n" .. utils.serialiseVar(httpHeaders))
    log:info("PiwigoAPI.pwConnect - response body:\n" .. tostring(httpResponse))

    if (httpHeaders.status == 201) or (httpHeaders.status == 200) then
        -- successful connection to Piwigo
        -- Now check login result
        local rtnBody = JSON:decode(httpResponse)
        if rtnBody.stat == "ok" then
            -- login ok - store session cookies
            local cookies = {}
            local SessionCookie = ""
            local allCookies = {}
            local fixedHeaders = utils.mergeSplitCookies(httpHeaders)
            for _, h in ipairs(fixedHeaders or {}) do
                if h.field:lower() == "set-cookie" then
                    table.insert(allCookies, h.value)
                    local nameValue = h.value:match("^([^;]+)")
                    if nameValue and string.sub(nameValue, 1, 3) == "pwg" then
                        table.insert(cookies, nameValue)
                        if nameValue:match("^pwg_id=") then
                            SessionCookie = nameValue
                        end
                    end
                end
            end
            propertyTable.SessionCookie = SessionCookie
            propertyTable.cookies       = cookies
            propertyTable.cookieHeader  = table.concat(propertyTable.cookies, "; ")
            propertyTable.Connected     = true
        else
            LrDialogs.message("Cannot log in to Piwigo - ", rtnBody.err .. ", " .. rtnBody.message)
            return false
        end
    else
        if httpHeaders.error then
            statusDes = httpHeaders.error.name
            status = httpHeaders.error.errorCode
        else
            statusDes = httpHeaders.statusDes
            status = httpHeaders.status
        end
        LrDialogs.message("Cannot log in to Piwigo - ", status .. ", " .. statusDes)
        return false
    end
end



-- *************************************************
local function getVersion(propertyTable)
    -- call pwg.getVersion to get the Piwigo version
    local versionInfo = {}
    local params = {
        { name = "method", value = "pwg.getVersion" },
    }

    -- build headers to include cookies from pwConnect call
    local headers = {}

    if propertyTable.cookieHeader ~= nil then
        headers = { ["Cookie"] = propertyTable.cookieHeader }
    end

    local getResponse = httpGet(propertyTable.pwurl, params, headers)

    if getResponse.errorMessage or (not getResponse.response) then
        versionInfo.version = nil
        versionInfo.errormessage = getResponse.errorMessage
        return versionInfo
    end

    if getResponse.status == "ok" then
        versionInfo.version = getResponse.response.result
        versionInfo.errormessage = nil
        return versionInfo
    else
        versionInfo.version = nil
        versionInfo.errormessage = "API Error: " .. (getResponse.errorMessage or "Unknown error")
        return versionInfo
    end
end

-- *************************************************
local function pwGetSessionStatus(propertyTable)
    -- successful connection, now get user role and token via pwg.session.getStatus
    log:info("pwGetSessionStatus")
    local Params = {
        { name = "method", value = "pwg.session.getStatus" },
    }
    -- build headers to include cookies from pwConnect call
    local headers = {}
    if propertyTable.cookieHeader ~= nil then
        headers = { ["Cookie"] = propertyTable.cookieHeader }
    end
    local getResponse = httpGet(propertyTable.pwurl, Params, headers)
    if getResponse.errorMessage or (not getResponse.response) then
        LrDialogs.message("Cannot get user status from Piwigo - " .. (getResponse.errorMessage or "Unknown error"))
        return false
    end
    if getResponse.status == "ok" then
        propertyTable.userStatus = getResponse.response.result.status
        propertyTable.token = getResponse.response.result.pwg_token
        propertyTable.pwVersion = getResponse.response.result.version
        propertyTable.Connected = true
        propertyTable.ConCheck = false
        propertyTable.ConStatus = "Connected to Piwigo Gallery at " ..
            propertyTable.host .. " as " .. propertyTable.userStatus .. " - Piwigo version " .. propertyTable.pwVersion

        return true
    else
        LrDialogs.message("Cannot log in to Piwigo - ", (getResponse.errorMessage or "Unknown error"))
        return false
    end
end

-- *************************************************
local function buildCatHierarchy(allCats)
    -- Step 1: Build a lookup table by id
    local lookup = {}
    for _, cat in ipairs(allCats) do
        lookup[cat.id] = cat
        cat.children = {}
    end

    -- Step 2: Build the hierarchy
    local hierarchy = {}

    for _, cat in ipairs(allCats) do
        -- uppercats is a comma-separated list like "16,28" or "24,27"
        local uppercats = cat.uppercats
        local parentId = nil

        if uppercats then
            local ids = {}
            for id in uppercats:gmatch("[^,]+") do
                table.insert(ids, tonumber(id))
            end

            -- parentId is the last id in uppercats before this category
            if #ids > 1 then
                parentId = ids
                    [#ids - 0] -- the last number in the chain is this cat’s own id, so second to last is parent
                if parentId == cat.id then
                    parentId = ids[#ids - 1]
                end
            elseif #ids == 1 and ids[1] ~= cat.id then
                parentId = ids[1]
            end
        end

        -- attach to parent if there is one, else it's a root
        if parentId and lookup[parentId] then
            table.insert(lookup[parentId].children, cat)
        else
            table.insert(hierarchy, cat)
        end
    end
    return hierarchy
end

-- *************************************************
local function findCat(allCats, findID)
    -- return cat from allCats based on cat id
    local foundCat = {}
    for jj, thisCat in pairs(allCats) do
        if thisCat.id == findID then
            foundCat = thisCat
            break
        end
    end

    return foundCat
end

-- *************************************************
local function buildCategoryPath(cat, allCats)
    -- Given a leaf category `cat` and the full list `allCats`,
    -- return a table representing the ordered path of category objects
    -- from root → leaf, each entry being { id, name, nb_categories }


    local path = {}

    -- cat.uppercats might look like "1,3,5"
    local upper = cat.uppercats
    if not upper or upper == "" then
        return { { id = cat.id, name = cat.name, nb_categories = cat.nb_categories } }
    end

    -- Split by comma
    for idStr in string.gmatch(upper, "([^,]+)") do
        local idNum = tonumber(idStr)
        -- Find the matching category in allCats
        for _, c in ipairs(allCats) do
            if tonumber(c.id) == idNum then
                table.insert(path, { id = c.id, name = c.name, nb_categories = c.nb_categories })
                break
            end
        end
    end

    return path
end

-- *************************************************
local function normalisePiwigoAlbums(piwigoTree)
    -- build normalised view of Piwigo album tree
    local indexByPath = {}
    local indexById   = {}
    -- *************************************************
    local function visit(node, parentPath, parentId)
        if not node.name or not node.id then
            return
        end

        -- Album paths must be composed ONLY from normalized keys.
        -- Raw names are for display only.
        local key = utils.makePathKey(node.name)
        local name = node.name
        local path = parentPath and (parentPath .. "/" .. key) or key

        local entry = {
            id       = node.id,
            name     = name,
            key      = key,
            path     = path,
            parentId = parentId,
            children = {},
        }

        indexByPath[path] = entry
        indexById[node.id] = entry

        if node.children then
            for _, child in ipairs(node.children) do
                visit(child, path, node.id)
                table.insert(entry.children, path .. "/" .. child.name)
            end
        end
    end
    -- *************************************************
    for _, root in ipairs(piwigoTree) do
        visit(root, nil, nil)
    end

    return indexByPath, indexById
end

-- *************************************************
local function normalisePublishService(publishService)
    local indexByPath = {}
    local indexById   = {}
    local visit
    local visitSet
    local visitCollection
    log:info("normalisePublishService - processing\n" .. utils.serialiseVar(publishService))
    -- *************************************************
    visit = function (container, parentPath, parentId)
        local children = container:getChildCollectionSets()
        local collections = container:getChildCollections()

        -- Visit child collection sets first
        for _, set in ipairs(children) do
            visitSet(set, parentPath, parentId)
        end

        -- Then collections
        for _, col in ipairs(collections) do
            visitCollection(col, parentPath, parentId)
        end
    end
    -- *************************************************
    -- Forward declarations
    visitSet = function (set, parentPath, parentId)
        local name = set:getName()
        local key  = utils.makePathKey(name)
        local path = parentPath and (parentPath .. "/" .. key) or key

        local entry = {
            id       = set.localIdentifier,
            name     = name,
            key      = key,
            path     = path,
            parentId = parentId,
            kind     = "set",
            remoteId = set:getRemoteId(),
            children = {},
        }

        indexByPath[path] = entry
        indexById[entry.id] = entry

        -- recurse into this set
        visit(set, path, entry.id)
    end
    -- *************************************************
    visitCollection = function(col, parentPath, parentId)
        local name = col:getName()
        local key  = utils.makePathKey(name)
        local path = parentPath and (parentPath .. "/" .. key) or key

        local entry = {
            id       = col.localIdentifier,
            name     = name,
            key      = key,
            path     = path,
            parentId = parentId,
            kind     = "collection",
            remoteId = col:getRemoteId(),
            children = {}, -- always empty
        }

        indexByPath[path] = entry
        indexById[entry.id] = entry

        -- attach to parent
        if parentPath then
            table.insert(indexByPath[parentPath].children, path)
        end
    end

    visit(publishService, nil, nil)
    return indexByPath, indexById

end

-- *************************************************

local function validatePublishAgainstPiwigo(lrIndexByPath, piwigoIndexByPath)
    local issues = {
        missingRemote = {},      -- local collection missing on Piwigo
        remoteIdMismatch = {},   -- remoteId != Piwigo ID
        orphanPiwigo = {},       -- Piwigo albums missing locally
        specialCollections = {}, -- Special collections
    }

    -- 1. Check Lightroom collections against Piwigo
    for path, lrEntry in pairs(lrIndexByPath) do
        if lrEntry.kind == "collection" or lrEntry.kind == "set" then
            -- check for special collections that won't / shouldn't exist on Piwigo as a separate album
            
            if (string.sub(lrEntry.key, 1, 1) == "[" and string.sub(lrEntry.key, -1) == "]") or (lrEntry.key:match("^※")) then
                -- special collection from pwigo published or piwigo export plugins
                -- check remote id is that of parent piwgo album
                table.insert(issues.specialCollections, {
                    key  = lrEntry.key,
                    path = path,
                    id   = lrEntry.id,
                })
            else
                local piwigoEntry = piwigoIndexByPath[path]
                if not piwigoEntry then
                    table.insert(issues.missingRemote, {
                        path = path,
                        kind = lrEntry.kind,
                        id   = lrEntry.id,
                    })
                else
                    -- compare remoteId
                    local remoteId = lrEntry.remoteId
                    local piwigoId = piwigoEntry.id
                    if tostring(remoteId) ~= tostring(piwigoId) then
                        table.insert(issues.remoteIdMismatch, {
                            path        = path,
                            kind        = lrEntry.kind,
                            localId     = lrEntry.id,
                            remoteId    = remoteId,
                            piwigoId    = piwigoId,
                        })
                    end
                end
            end
  
        end
    end

    -- 2. Optional: detect Piwigo albums missing locally
    for path, piwigoEntry in pairs(piwigoIndexByPath) do
        local lrEntry = lrIndexByPath[path]
        if (piwigoEntry.kind == nil or piwigoEntry.kind == "collection" or piwigoEntry.kind == "set")
           and not lrEntry then
            table.insert(issues.orphanPiwigo, {
                path = path,
                kind = "collection",
                piwigoId = piwigoEntry.id,
            })
        end
    end

    return issues
end
-- *************************************************
local function vps_fixRemoteIdMismatchesAndUpdateDets(catalog, propertyTable, publishService,lrIndexByPath, lrIndexById, pwIndexByPath,  issues)
    -- fix mismtach between collection/set remote id and Piwigo album id  identified in issues.remoteIdMismatch
    local fixRemote = 0
    for _, mismatch in ipairs(issues.remoteIdMismatch) do
        local lrEntry = lrIndexById[mismatch.localId]
        if lrEntry then
            local oldId = lrEntry.remoteId
            lrEntry.remoteId = mismatch.piwigoId
            local colOrSet = catalog:getPublishedCollectionByLocalIdentifier(mismatch.localId)
            -- Determine parent set for setCollectionDets
            local parentSet = nil

            if lrEntry.parentId then
                parentSet = catalog:getPublishedCollectionByLocalIdentifier(lrEntry.parentId)
            end

            -- Call PiwigoAPI to update collection details in the catalog
            PiwigoAPI.setCollectionDets(colOrSet, catalog, propertyTable, lrEntry.name, lrEntry.remoteId, parentSet)

            -- Logging
            if not oldId or oldId == "" then
                log:info(string.format(
                    "Set missing remoteId and updated collection details for %s: %s -> %s",
                    lrEntry.path, lrEntry.kind, tostring(lrEntry.remoteId)
                ))
            else
                log:info(string.format(
                    "Updated remoteId and collection details for %s: %s (old: %s, new: %s)",
                    lrEntry.path, lrEntry.kind, tostring(oldId), tostring(lrEntry.remoteId)
                ))
            end
            fixRemote = fixRemote + 1

        else
            log:warn(string.format(
                "Cannot find Lightroom entry for localId %s (path: %s)",
                tostring(mismatch.localId), mismatch.path
            ))
        end
    end
    return fixRemote
end

-- *************************************************
local function vps_createMissingPiwigoAlbumsFromIssues(catalog, propertyTable, publishService, lrIndexByPath, lrIndexById, pwIndexByPath, issues)
    --create Piwigo albums identified in issues.missingRemote
    

    local missing = issues.missingRemote
    -- Sort paths top-down so parents are created before children
    table.sort(missing, function(a, b)
        return #a.path < #b.path
    end)
    log:info("createMissingPiwigoAlbumsFromIssues - missing\n",utils.serialiseVar(missing))
    log:info("createMissingPiwigoAlbumsFromIssues - lrIndexByPath\n",utils.serialiseVar(lrIndexByPath))
    log:info("createMissingPiwigoAlbumsFromIssues - lrIndexById\n",utils.serialiseVar(lrIndexById))
    local numCreated = 0
    local numFailed = 0
    for _, miss in ipairs(missing) do
        local lrEntry = lrIndexByPath[miss.path]
        local colLocalIdentifier = miss.id
        -- Determine parent remote ID
        local parentRemoteId = nil
        local parentSet = nil
        local parentLocalIdentifier = nil
        if lrEntry.parentId then
            local parentEntry = lrIndexById[lrEntry.parentId]
            if parentEntry then
                parentRemoteId = parentEntry.remoteId
                parentLocalIdentifier = parentEntry.id 
                parentSet = catalog:getPublishedCollectionByLocalIdentifier(parentLocalIdentifier)
            end
        end

        -- get publishedCollection
        
        local ColOrSet = catalog:getPublishedCollectionByLocalIdentifier( colLocalIdentifier  )
        
        --log:info("createMissingPiwigoAlbumsFromIssues - ColOrSet is " .. ColOrSet:getName() ..", a " .. ColOrSet:type())
        -- Create album in Piwigo
        local metaData = {}
        local callStatus = {}
        local albumName = lrEntry.name
        metaData.name = albumName
        metaData.parentCat = parentRemoteId
        local albumId
        local albumUrl

        --log:info("createMissingPiwigoAlbumsFromIssues - creating pwAlbum " .. albumName .. " under " .. (parentRemoteId or ""))
        callStatus = PiwigoAPI.pwCategoriesAdd(propertyTable, ColOrSet, metaData, callStatus)

        if callStatus.status then
            -- reset album id to newly created one
            albumId = callStatus.newCatId
            albumUrl = callStatus.albumURL
            PiwigoAPI.setCollectionDets(ColOrSet, catalog, propertyTable, albumName, albumId, parentSet)
            numCreated = numCreated + 1
        else
            log:info("createMissingPiwigoAlbumsFromIssues - unable to create pwAlbum " .. albumName .. " under " .. (parentRemoteId or ""))
            numFailed = numFailed + 1
        end
     

        -- Update Lightroom entry
        lrEntry.remoteId = albumId

        -- Update Piwigo index
        pwIndexByPath[miss.path] = {
            id       = albumId,
            name     = lrEntry.name,
            key      = lrEntry.key,
            path     = miss.path,
            parentId = lrEntry.parentId,
            kind     = lrEntry.kind,
            children = {},
        }
        -- Attach to parent in Piwigo index
        if parentRemoteId and lrEntry.parentId then
            local lrIndexByIdEntry = lrIndexById[lrEntry.parentId]
            local parentPath = lrIndexByIdEntry.path
            table.insert(pwIndexByPath[parentPath].children, miss.path)
        end
        log:info(string.format("Created missing Piwigo %s: %s (ID %s)",lrEntry.kind, miss.path, tostring(albumId) ))
    end

    return numCreated, numFailed
end

-- *************************************************
local function vps_fixSpecialCollections(catalog, propertyTable, publishService, lrIndexByPath, lrIndexById, pwIndexByPath, issues)
-- fix mismtach between collection/set remote id and Piwigo album id  identified in issues.remoteIdMismatch
    local fixSpecial = 0

    for _, specialCollection in ipairs(issues.specialCollections) do
        local scIdentifier = specialCollection.id

        local scColOrSet = catalog:getPublishedCollectionByLocalIdentifier(scIdentifier)

        if scColOrSet then
            -- if this is a special collection created by this plugin, check remote is correct
            -- if an alloyphoto imported special collection, rename and check remote id is correct
            -- get parent
            local scName = scColOrSet:getName()
            local scRemoteId = scColOrSet:getRemoteId()
            local parentColSet = scColOrSet:getParent()

            if parentColSet then
                local parentName = parentColSet:getName()
                local parentRemoteId = parentColSet:getRemoteId()
                local checkName = PiwigoAPI.buildSpecialCollectionName(parentName)
                if (checkName ~= scName) or (scRemoteId ~= parentRemoteId) then
                    PiwigoAPI.setCollectionDets(scColOrSet, catalog, propertyTable, checkName, parentRemoteId, parentColSet)
                    fixSpecial = fixSpecial + 1
                end
            end
        end
    end
    return fixSpecial
end

-- *************************************************
local function createCollection(propertyTable, node, parentNode, isLeafNode, statusData)
    local rv
    local newColl
    local parentColl
    local existingColl, existingSet
    local catalog = LrApplication.activeCatalog()
    local stat = statusData

    -- getPublishService to get reference to this publish service - returned in propertyTable._service
    -- needs to be refreshed each time  to relfect lastest state of publishedCollections created further below
    log:info("createCollection for node " .. node.id .. ", " .. node.name)

    rv = PiwigoAPI.getPublishService(propertyTable)
    if not rv then
        LrErrors.throwUserError("Error in createCollection: Cannot find Piwigo publish service for host/user.")
        return false
    end
    local publishService = propertyTable._service
    if not publishService then
        LrErrors.throwUserError("Error in createCollection: Piwigo publish service is nil.")
        return false
    end
    -- get parent collection or collection set
    if parentNode == "" then
        -- no parent node so we start at root with the publishService
        parentColl = publishService
    else
        -- find parent publishcollection in this publish service
        parentColl = utils.recursivePubCollectionSearchByRemoteID(publishService, parentNode.id)
    end
    if not (parentColl) then
        LrErrors.throwUserError("Error in createCollection: No parent collection for " .. node.name)
        stat.errors = stat.errors + 1
    else
        -- look for this collection - create if not found
        existingColl = utils.recursivePubCollectionSearchByRemoteID(publishService, node.id)
        if not (existingColl) then
            -- not an existing collection/set for this node and we have got the parent collection/set
            if parentColl:type() ~= "LrPublishedCollectionSet" and parentColl:type() ~= "LrPublishService" then
                -- parentColl is not of type that can accept child collections - need to handle
                LrErrors.throwUserError("Error in createCollection: Parent collection for " ..
                    node.name .. " is " .. parentColl:type() .. " - can't create child collection")
                stat.errors = stat.errors + 1
            else
                if isLeafNode then
                    -- create Publishedcollection
                    catalog:withWriteAccessDo("Create PublishedCollection ", function()
                        newColl = publishService:createPublishedCollection(node.name, parentColl, true)
                    end)
                    stat.collections = stat.collections + 1
                else
                    -- Create PublishedCollectionSet
                    catalog:withWriteAccessDo("Create PublishedCollectionSet ", function()
                        newColl = publishService:createPublishedCollectionSet(node.name, parentColl, true)
                    end)
                    stat.collectionSets = stat.collectionSets + 1
                end
                -- now add remoteids and urls to collections and collection sets
                catalog:withWriteAccessDo("Add Piwigo details to collections", function()
                    newColl:setRemoteId(node.id)
                    newColl:setRemoteUrl(propertyTable.host .. "/index.php?/category/" .. node.id)
                    newColl:setName(node.name)
                end)
            end
        else
            stat.existing = stat.existing + 1
        end
    end
    return stat
end

-- *************************************************
local function createCollectionsFromCatHierarchy(catNode, parentNode, propertyTable, statusData, depth)
    -- Traverses the category hierarchy recursively, creating collections or collections sets as needed
    -- catNode is an category table item returned by pwg.categories.getList
    -- parenNode is the category table item of which this node is a child (blank for top level category)
    -- statusData tracks new and existing collections and sets
    -- depth is used internally to track nesting level.

    log:info("createCollectionsFromCatHierarchy - processing " .. catNode.id, catNode.name)
    depth = depth or 0
    if depth > statusData.maxDepth then
        statusData.maxDepth = depth
    end
    -- process catNode
    if type(catNode) == 'table' and catNode.id then
        -- catNode is valid and processible
        -- create collection or collectionSet
        local isLeafNode = false
        if catNode.nb_categories == 0 then
            -- this category doesn't contain subcategories so it is a leaf node
            isLeafNode = true
        end
        local rv = createCollection(propertyTable, catNode, parentNode, isLeafNode, statusData)
    end
    -- now recursively process children of catNode
    if catNode.children and type(catNode.children) == 'table' then
        for _, child in ipairs(catNode.children) do
            createCollectionsFromCatHierarchy(child, catNode, propertyTable, statusData, depth + 1)
        end
    end
end

-- *************************************************
-- G L O B A L   F U N C T I O N S
-- *************************************************

-- *************************************************
function PiwigoAPI.fixSpecialCollectionNames(catalog, publishService, propertyTable)
    -- fix extra space in specialCollectionNames
    -- get all collectionsets
    local collSets = {}
    collSets = utils.recursePubCollectionSets(publishService, collSets)

    -- Now look for specialCollections for each collset
    for cs, collSet in pairs(collSets) do
        local childColls = collSet:getChildren()
        if childColls then
            local parentName = collSet:getName()
            for cc, childCol in pairs(childColls) do
                local ccName = childCol:getName()
                local remoteId = childCol:getRemoteId()
                if string.sub(ccName, 1, 11) == "[ Photos in" and string.sub(ccName, -2) == " ]" then
                    -- special collection - fix name by removing space prior to ]
                    
                    local newName = PiwigoAPI.buildSpecialCollectionName(parentName)
                    log:info("PiwigoAPI.fixSpecialCollectionNames - " .. ccName .. " fixed to " .. newName)
                    catalog:withWriteAccessDo("Set Collection Name", function()
                        childCol:setName(newName)
                    end)
                end
            end
        end
    end
end

-- *************************************************
function PiwigoAPI.buildSpecialCollectionName(name)
    -- consistently build special collection name
    local scName = "[Photos in " .. name .. " ]"
    return scName
end

-- *************************************************
function PiwigoAPI.setCollectionDets(thisCollorSet, catalog, propertyTable, name, remoteId, parentSet)
    catalog:withWriteAccessDo("Add Piwigo details to collection", function()
        thisCollorSet:setRemoteId(remoteId)
        thisCollorSet:setRemoteUrl(propertyTable.host .. "/index.php?/category/" .. remoteId)
        thisCollorSet:setName(name)
        thisCollorSet:setParent(parentSet)
    end)
    return true
end

-- *************************************************
function PiwigoAPI.createPublishCollectionSet(catalog, publishService, propertyTable, name, remoteId, parentSet)
    --PiwigoAPI.createPublishCollectionSet(catalog, useService, publishSettings, selCollName, catId, selColParent)
    -- create new publish collection set or return existing
    log:info("createPublishCollectionSet - " .. name .. ", " .. remoteId)
    local newColl
    catalog:withWriteAccessDo("Create PublishedCollectionSet ", function()
        newColl = publishService:createPublishedCollectionSet(name, parentSet, true)
    end)
    -- add remoteids and urls to collection
    PiwigoAPI.setCollectionDets(newColl, catalog, propertyTable, name, remoteId, parentSet)

    return newColl
end

-- *************************************************
function PiwigoAPI.createPublishCollection(catalog, publishService, propertyTable, name, remoteId, parentSet)
    -- create new publish collection or return existing
    log:info("createPublishCollection - " .. name .. ", " .. remoteId)
    local newColl
    catalog:withWriteAccessDo("Create PublishedCollection ", function()
        newColl = publishService:createPublishedCollection(name, parentSet, true)
    end)
    -- add remoteids and urls to collection
    PiwigoAPI.setCollectionDets(newColl, catalog, propertyTable, name, remoteId, parentSet)

    return newColl
end

-- *************************************************
function PiwigoAPI.validatePiwigoStructure(propertyTable)
    -- function to check remote Piwigo structure is consistent with local collection / set structure
    -- does each collection / set have a corresponding Piwigo album
    -- are collection / set remooteIds correct

    -- will create Piwigo albums if missing
    -- will add remoteIds to local collection / sets if missing
    -- will not create any new collection / sets
    
    local rv, allCats
    local catalog = LrApplication.activeCatalog()
    rv = PiwigoAPI.getPublishService(propertyTable)
    if not rv then
        LrErrors.throwUserError("Error in validatePiwigoStructure: Cannot find Piwigo publish service for host/user.")
        return false
    end
    local publishService = propertyTable._service
    if not publishService then
        LrErrors.throwUserError("Error in validatePiwigoStructure: Piwigo publish service is nil.")
        return false
    end

    -- get all categories from Piwigo
   
    rv, allCats = PiwigoAPI.pwCategoriesGet(propertyTable, "")
    if not rv then
        utils.handleError('PiwigoAPI:validatePiwigoStructure - cannot get categories from piwigo',
            "Error: Cannot get categories from Piwigo server.")
        return
    end
    if utils.nilOrEmpty(allCats) then
        utils.handleError('PiwigoAPI:validatePiwigoStructure - no categories found in piwigo',
            "Error: No categories found in Piwigo server.")
        return
    end
    -- hierarchical table of categories
    local catHierarchy = buildCatHierarchy(allCats)

    -- build normalised views of Piwigo Albums and local collection / sets
    local pwIndexByPath, pwIndexById = normalisePiwigoAlbums(catHierarchy)
    --log:info("PiwigoAPI.validatePiwigoStructure - pwIndexByPath\n" .. utils.serialiseVar(pwIndexByPath))
    --log:info("PiwigoAPI.validatePiwigoStructure - pwIndexById\n" .. utils.serialiseVar(pwIndexById))

    local lrIndexByPath, lrIndexById
    catalog:withReadAccessDo(function()
        lrIndexByPath, lrIndexById = normalisePublishService(publishService)
    end)
    --log:info("PiwigoAPI.validatePiwigoStructure - lrIndexByPath\n" .. utils.serialiseVar(lrIndexByPath))
    --log:info("PiwigoAPI.validatePiwigoStructure - lrIndexById\n" .. utils.serialiseVar(lrIndexById))
    
    -- compare tables of album paths and ceate table of issues e.g.
    local issues = validatePublishAgainstPiwigo(lrIndexByPath, pwIndexByPath)
    log:info("PiwigoAPI.validatePiwigoStructure - issues\n" .. utils.serialiseVar(issues))

    -- now process any issues
 
    local numCreated, numFailed =  vps_createMissingPiwigoAlbumsFromIssues(catalog, propertyTable, publishService, lrIndexByPath, lrIndexById, pwIndexByPath, issues)
    local numFixed = vps_fixRemoteIdMismatchesAndUpdateDets(catalog, propertyTable, publishService,lrIndexByPath, lrIndexById, pwIndexByPath,  issues)
    local numSpecial = vps_fixSpecialCollections(catalog, propertyTable, publishService, lrIndexByPath, lrIndexById, pwIndexByPath, issues)
    LrDialogs.message(
        "Check Piwigo Structure", 
        string.format("Albums created on Piwigo: %s, Piwigo links updated: %s, Albums unable to create: %s (check log file for details)",numCreated,numFixed,numFailed
        ))

end

-- *************************************************
function PiwigoAPI.ConnectionChange(propertyTable)
    log:info('PublishDialogSections.ConnectionChange')
    propertyTable.ConStatus = "Not Connected"
    propertyTable.Connected = false
    propertyTable.ConCheck = true
    propertyTable.SessionCookie = ""
    propertyTable.cookies = nil
    propertyTable.userStatus = ""
    propertyTable.token = ""
end

-- *************************************************
function PiwigoAPI.storeMetaData(catalog, propertyTable, lrPhoto, pluginData)
    log:info("PiwigoAPI.storeMetaData - pluginData\n" .. utils.serialiseVar(pluginData))

    -- set metadata for photo
    catalog:withWriteAccessDo("Updating " .. lrPhoto:getFormattedMetadata("fileName"),
        function()
            lrPhoto:setPropertyForPlugin(_PLUGIN, "pwHostURL", pluginData.pwHostURL)
            lrPhoto:setPropertyForPlugin(_PLUGIN, "pwAlbumName", pluginData.albumName)
            lrPhoto:setPropertyForPlugin(_PLUGIN, "pwAlbumURL", pluginData.albumUrl)
            lrPhoto:setPropertyForPlugin(_PLUGIN, "pwImageURL", pluginData.ImageURL)
            lrPhoto:setPropertyForPlugin(_PLUGIN, "pwUploadDate", pluginData.pwUploadDate)
            lrPhoto:setPropertyForPlugin(_PLUGIN, "pwUploadTime", pluginData.pwUploadTime)
        end)


    -- store mapping between lrPhoto and pwigo id
    propertyTable.publishedPhotoMap[pluginData.pwImageID] = lrPhoto.localIdentifier
end

-- *************************************************
function PiwigoAPI.getPublishServicesForPlugin(pluginID)
    -- Helper to get all publish service connections for this plugin
    local catalog = LrApplication.activeCatalog()
    local services = catalog:getPublishServices() or {}
    local myServices = {}

    for _, s in ipairs(services) do
        if s:getPluginId() == pluginID then
            table.insert(myServices, s)
        end
    end

    return myServices
end

-- *************************************************
function PiwigoAPI.getPublishService(propertyTable)
    -- get reference to publish service matching host and userName in propertyTable
    local catalog = LrApplication.activeCatalog()
    local services = catalog:getPublishServices()
    local thisService
    local foundService = false

    for _, s in ipairs(services) do
        local pluginSettings = s:getPublishSettings()
        local pluginID = s:getPluginId()
        local pluginName = s:getName()

        if pluginSettings.host == propertyTable.host and
            pluginSettings.userName == propertyTable.userName then
            thisService = s
            foundService = true
            break
        end
    end
    propertyTable._service = thisService -- store a reference for button callbacks
    return foundService
end

-- *************************************************
function PiwigoAPI.sanityCheckAndFixURL(url)
    if utils.nilOrEmpty(url) then
        utils.handleError('sanityCheckAndFixURL: URL is empty', "Error: Piwigo server URL is empty.")
        return false
    end
    --local sanitizedURL = string.match(url, "^https?://[%w%.%-]+[:%d]*")
    local sanitizedURL = url:gsub("/$", "")
    if sanitizedURL then
        if string.len(sanitizedURL) == string.len(url) then
            log:info('sanityCheckAndFixURL: URL is completely sane.')
            url = sanitizedURL
        else
            log:info('sanityCheckAndFixURL: Fixed URL: removed trailing paths.')
            url = sanitizedURL
        end
    elseif not string.match(url, "^https?://") then
        utils.handleError('sanityCheckAndFixURL: URL is missing protocol (http:// or https://).')
    else
        utils.handleError('sanityCheckAndFixURL: Unknown error in URL')
    end

    return url
end

-- *************************************************
function PiwigoAPI.login(propertyTable)
    if utils.nilOrEmpty(propertyTable.host) or utils.nilOrEmpty(propertyTable.userName) or utils.nilOrEmpty(propertyTable.userPW) then
        log:info('PiwigoAPI:login - missing host, username or password',
            "Error: Piwigo server URL, username or password is empty.")
        return false
    end

    local rv = PiwigoAPI.pwConnect(propertyTable)
    return rv
end

-- *************************************************
function PiwigoAPI.pwConnect(propertyTable)
    -- set up connection to piwigo database
    log:info("PiwigoAPI.pwConnect")
    local status, statusDes
    propertyTable.pwurl = propertyTable.host .. "/ws.php?format=json"
    propertyTable.Connected = false
    propertyTable.ConCheck = true
    propertyTable.ConStatus = "Not Connected"
    propertyTable.userStatus = ""

    -- Try to login using pwg.session.login
    local urlParams = {
        { name = "method",   value = "pwg.session.login" },
        { name = "username", value = propertyTable.userName },
        { name = "password", value = propertyTable.userPW },
        { name = "format",   value = "json" },
    }
    local body = utils.buildPostBodyFromParams(urlParams)

    local headers = {
        { field = "Content-Type",    value = "application/x-www-form-urlencoded" },
        { field = "Accept-Encoding", value = "identity" },
    }
    log:info("PiwigoAPI.pwConnect - connecting to " .. propertyTable.pwurl)
    log:info("PiwigoAPI.pwConnect - body:\n" .. utils.serialiseVar(body))

    local httpResponse, httpHeaders = LrHttp.post(propertyTable.pwurl, body, headers)

    log:info("PiwigoAPI.pwConnect - response headers:\n" .. utils.serialiseVar(httpHeaders))
    log:info("PiwigoAPI.pwConnect - response body:\n" .. tostring(httpResponse))

    if (httpHeaders.status == 201) or (httpHeaders.status == 200) then
        -- successful connection to Piwigo
        -- Now check login result
        -- Decode JSON safely
        local ok, rtnBody = pcall(JSON.decode, JSON, httpResponse)
        if not ok or type(rtnBody) ~= "table" then
            LrDialogs.message(
                "Cannot log in to Piwigo",
                "Invalid or unreadable server response"
            )
            return false
        end
        if rtnBody.stat == "ok" then
            -- login ok - store session cookies
            local cookies = {}
            local SessionCookie = ""
            local allCookies = {}
            local fixedHeaders = utils.mergeSplitCookies(httpHeaders)
            for _, h in ipairs(fixedHeaders or {}) do
                if h.field:lower() == "set-cookie" then
                    table.insert(allCookies, h.value)
                    local nameValue = h.value:match("^([^;]+)")
                    if nameValue and string.sub(nameValue, 1, 3) == "pwg" then
                        table.insert(cookies, nameValue)
                        if nameValue:match("^pwg_id=") then
                            SessionCookie = nameValue
                        end
                    end
                end
            end
            propertyTable.SessionCookie = SessionCookie
            propertyTable.cookies       = cookies
            propertyTable.cookieHeader  = table.concat(propertyTable.cookies, "; ")
            propertyTable.Connected     = true
        else
            LrDialogs.message(
                "Cannot log in to Piwigo",
                tostring(rtnBody.err or "Unknown error")
                .. (rtnBody.message and (", " .. rtnBody.message) or "")
            )
            return false
        end
    else
        local statusCode, statusDesc
        status = httpHeaders and httpHeaders.status
        if httpHeaders and httpHeaders.error then
            statusCode = httpHeaders.error.errorCode or "?"
            statusDesc = httpHeaders.error.name or "Unknown error"
        else
            statusCode = status or "?"
            statusDesc = (httpHeaders and (httpHeaders.statusDes or httpHeaders.statusDesc)) or ""
        end

        LrDialogs.message(
            "Cannot log in to Piwigo",
            tostring(statusCode) .. (statusDesc ~= "" and (", " .. statusDesc) or "")
        )
        return false
    end

    -- successful connection, now get user role and token via pwg.session.getStatus
    local rv = pwGetSessionStatus(propertyTable)

    -- get list of all tagIDs
    rv, propertyTable.tagTable = PiwigoAPI.getTagList(propertyTable)
    if not rv then
        LrDialogs.message('PiwigoAPI.pwConnect - cannot get taglist from Piwigo')
        return false
    end


    return rv
end

-- *************************************************
function PiwigoAPI.checkAdmin(propertyTable)
    local rv
    local callStatus = {}
    callStatus.status = false
    -- check connection to piwigo
    if not (propertyTable.Connected) then
        rv = PiwigoAPI.login(propertyTable)
        if not rv then
            callStatus.statusMsg = 'PiwigoAPI:updateMetadata - cannot connect to piwigo'
            return callStatus
        end
    end

    -- check role is admin level
    if propertyTable.userStatus == "webmaster" then
        callStatus.status = true
    end
    return callStatus
end

-- *************************************************
function PiwigoAPI.importAlbums(propertyTable)
    -- Import albums from piwigo and build local album structure based on piwigo categories
    -- will use remoteId in collections and collection sets to track piwigo category ids
    -- if collections or collections sets already exist they are maintained

    local rv
    log:info("PiwigoAPI:importAlbums")
    -- getPublishService to get reference to this publish service - returned in propertyTable._service
    rv = PiwigoAPI.getPublishService(propertyTable, false)
    if not rv then
        utils.handleError('PiwigoAPI:importAlbums - cannot find publish service - has it been saved?',
            "Error: Cannot find Piwigo publish service - has it been saved?")
        return
    end
    local publishService = propertyTable._service
    if not publishService then
        utils.handleError('PiwigoAPI:importAlbums - publish service is nil', "Error: Piwigo publish service is nil.")
        return
    end
    -- check connection to piwigo
    if not propertyTable.Connected then
        rv = PiwigoAPI.login(propertyTable)
        if not rv then
            utils.handleError('PiwigoAPI:importAlbums - cannot connect to piwigo',
                "Error: Cannot connect to Piwigo server.")
            return
        end
    end
    -- get categories from piwigo
    local allCats
    rv, allCats = PiwigoAPI.pwCategoriesGet(propertyTable, "")
    if not rv then
        utils.handleError('PiwigoAPI:importAlbums - cannot get categories from piwigo',
            "Error: Cannot get categories from Piwigo server.")
        return
    end
    if utils.nilOrEmpty(allCats) then
        utils.handleError('PiwigoAPI:importAlbums - no categories found in piwigo',
            "Error: No categories found in Piwigo server.")
        return
    end

    -- hierarchical table of categories
    local catHierarchy = buildCatHierarchy(allCats)

    local statusData = {
        existing = 0,
        collectionSets = 0,
        collections = 0,
        errors = 0,
        maxDepth = 0
    }
    local progressScope = LrProgressScope {
        title = "Import album structure...",
        caption = "Starting...",
        functionContext = context,
    }

    for cc, thisNode in pairs(catHierarchy) do
        -- each thisNode is a top level Piwigo album
        if progressScope:isCanceled() then
            break
        end
        progressScope:setPortionComplete(cc, #catHierarchy)
        progressScope:setCaption("Processing " .. cc .. " of " .. #catHierarchy .. " top level albums")
        local parentNode = "" -- set to empty string to start at publishservice collection root
        -- now create publishcollectionsets and publishcollections for this album and it's sub albums
        createCollectionsFromCatHierarchy(thisNode, parentNode, propertyTable, statusData)
    end
    progressScope:done()
    LrDialogs.message("Import Piwigo Albums",
        string.format("%s new collections, %s new collection sets, %s existing, %s errors", statusData.collections,
            statusData.collectionSets, statusData.existing, statusData.errors))
end

-- *************************************************
function PiwigoAPI.pwCategoriesGet(propertyTable, thisCat)
    -- get list of categories from Piwigo
    -- if thisCat is set then return this category and children, otherwise all categories
    local status, statusDes
    local Params = {
        { name = "method",    value = "pwg.categories.getList" },
        { name = "recursive", value = "true" },
        { name = "fullname",  value = "false" }
    }

    if not (utils.nilOrEmpty(thisCat)) then
        table.insert(Params, { name = "cat_id", value = tostring(thisCat) })
    end

    -- build headers to include cookies from pwConnect call
    local headers = {}
    if propertyTable.cookieHeader ~= nil then
        headers = { ["Cookie"] = propertyTable.cookieHeader }
    end
    local getResponse = httpGet(propertyTable.pwurl, Params, headers)
    if getResponse.errorMessage or (not getResponse.response) then
        LrDialogs.message("Cannot get categories from Piwigo - ", (getResponse.errorMessage or "Unknown error"))
        return false
    end
    if getResponse.status == "ok" then
        local allCats = getResponse.response.result.categories
        return true, allCats
    else
        LrDialogs.message("Cannot get categories from Piwigo - ", (getResponse.errorMessage or "Unknown error"))
        return false
    end
end

-- *************************************************
function PiwigoAPI.pwCategoriesMove(propertyTable, info, thisCat, newCat, callStatus)
    -- move piwigo categeory to a different parent using pwg.categories.move

    callStatus.status = false
    callStatus.statusMsg = ""
    local rv

    -- check connection to piwigo
    if not (propertyTable.Connected) then
        rv = PiwigoAPI.login(propertyTable)
        if not rv then
            callStatus.statusMsg = 'PiwigoAPI:pwCategoriesMove - cannot connect to piwigo'
            return callStatus
        end
    end

    -- check role is admin level
    if propertyTable.userStatus ~= "webmaster" then
        callStatus.statusMsg = "PiwigoAPI:pwCategoriesMove - User needs webmaster role on piwigo gallery at " ..
            propertyTable.host .. " to reorder albums"
        return callStatus
    end

    -- check parent category exists
    -- newCat of 0 means move to root so no parent album
    if newCat ~= 0 then
        local checkCats
        rv, checkCats = PiwigoAPI.pwCategoriesGet(propertyTable, tostring(newCat))
        if utils.nilOrEmpty(checkCats) then
            callStatus.statusMsg = "PiwigoAPI:pwCategoriesMove - Cannot find parent category " .. newCat .. " in Piwigo"
            return callStatus
        end
    end
    -- move album on piwigo
    -- parameters for POST
    local params = {
        { name = "method",      value = "pwg.categories.move" },
        { name = "category_id", value = tostring(thisCat) },
        { name = "parent",      value = newCat },
        { name = "pwg_token",   value = propertyTable.token },
    }

    local httpResponse, httpHeaders = LrHttp.postMultipart(
        propertyTable.pwurl,
        params,
        {
            headers = { field = "Cookie", value = propertyTable.cookies }
        }
    )

    local parseResp
    if httpResponse then
        parseResp = JSON:decode(httpResponse)
    end
    if httpHeaders.status == 201 or httpHeaders.status == 200 then
        if parseResp.stat == "ok" then
            callStatus.status = true
            callStatus.statusMsg = ""
        else
            callStatus.status = false
            callStatus.statusMsg = parseResp.message or ""
        end
    else
        callStatus.status = false
        callStatus.statusMsg = parseResp.message or ""
    end

    return callStatus
end

-- *************************************************
function PiwigoAPI.pwCategoriesAdd(propertyTable, info, metaData, callStatus)
    -- create new pwigo category
    callStatus.status = false
    local status, statusDes
    local rv
    -- get parent collection for publishedCollection
    -- if root then create new category with no parent otherwise use remote id for pareent

    -- use pwg.categories.add
    -- check connection to piwigo
    if not (propertyTable.Connected) then
        rv = PiwigoAPI.login(propertyTable)
        if not rv then
            callStatus.statusMsg = 'PiwigoAPI:pwCategoriesAdd - cannot connect to piwigo'
            return callStatus
        end
    end

    -- check role is admin level
    if propertyTable.userStatus ~= "webmaster" then
        callStatus.statusMsg = "PiwigoAPI:pwCategoriesAdd - User needs webmaster role on piwigo gallery at " ..
            propertyTable.host .. " to reorder albums"
        return callStatus
    end

    local Params = {
        { name = "method",    value = "pwg.categories.add" },
        { name = "name",      value = metaData.name },
        { name = "pwg_token", value = propertyTable.token }
    }
    if metaData.parentCat ~= "" then
        table.insert(Params, { name = "parent", value = metaData.parentCat })
    end

    -- build headers to include cookies from pwConnect call
    local headers = {}
    if propertyTable.cookieHeader ~= nil then
        headers = { ["Cookie"] = propertyTable.cookieHeader }
    end
    local getResponse = httpGet(propertyTable.pwurl, Params, headers)

    if getResponse.errorMessage or (not getResponse.response) then
        LrDialogs.message("Cannot add new category to Piwigo - ", getResponse.errorMessage)
        callStatus.status = false
        return callStatus
    end
    if getResponse.status == "ok" then
        callStatus.newCatId = getResponse.response.result.id
        callStatus.albumURL = propertyTable.host .. "/index.php?/category/" .. callStatus.newCatId
        callStatus.status = true
    else
        LrDialogs.message("Cannot add new category to Piwigo - ", getResponse.errorMessage)
        callStatus.status = false
    end
    return callStatus
end

-- *************************************************
function PiwigoAPI.pwCategoriesDelete(propertyTable, info, metaData, callStatus)
    -- delete category on Piwigo using pwg.categories.delete

    callStatus.status = false
    local status, statusDes
    local rv

    local checkCats
    -- check connection to piwigo
    if not (propertyTable.Connected) then
        rv = PiwigoAPI.login(propertyTable)
        if not rv then
            callStatus.statusMsg = 'PiwigoAPI:pwCategoriesDelete - cannot connect to piwigo'
            return callStatus
        end
    end

    -- check role is admin level
    if propertyTable.userStatus ~= "webmaster" then
        callStatus.statusMsg = "PiwigoAPI:pwCategoriesDelete - User needs webmaster role on piwigo gallery at " ..
            propertyTable.host .. " to reorder albums"
        return callStatus
    end

    -- Check that collection exists as an album on Piwigo
    rv, checkCats = PiwigoAPI.pwCategoriesGet(propertyTable, metaData.catToDelete)
    if not rv then
        callStatus.statusMsg = 'Delete Album - cannot check album exists on piwigo at ' .. propertyTable.host
        return callStatus
    end

    if utils.nilOrEmpty(checkCats) then
        -- if album is missing from Piwigo we can still go ahead and delete collection on LrC
        -- so set callStatus.status to true
        callStatus.status = true
        callStatus.statusMsg = 'Delete Album - Album does not exist on piwigo at ' .. propertyTable.host
        return callStatus
    end
    -- delete album on piwigo
    -- parameters for POST
    -- photo_deletion_mode can be:
    --      "no_delete" (may create orphan photos),
    --      "delete_orphans" (default mode, only deletes photos linked to no other album)
    --      "force_delete" (delete all photos, even those linked to other albums)
    --
    local params = {
        { name = "method",            value = "pwg.categories.delete" },
        { name = "category_id",       value = metaData.catToDelete },
        { name = "photo_delete_mode", value = "delete_orphans" },
        { name = "pwg_token",         value = propertyTable.token },
    }

    local httpResponse, httpHeaders = LrHttp.postMultipart(
        propertyTable.pwurl,
        params,
        {
            headers = { field = "Cookie", value = propertyTable.cookies }
        }
    )

    local parseResp
    if httpResponse then
        parseResp = JSON:decode(httpResponse)
    end
    if httpHeaders.status == 201 or httpHeaders.status == 200 then
        if parseResp.stat == "ok" then
            callStatus.status = true
            callStatus.statusMsg = ""
        else
            callStatus.status = false
            callStatus.statusMsg = parseResp.message or ""
        end
    else
        callStatus.status = false
        callStatus.statusMsg = parseResp.message or ""
    end
    return callStatus
end

-- *************************************************
function PiwigoAPI.pwCategoriesSetinfo(propertyTable, info, callStatus)
    -- Set info on category - change name etc
    callStatus.status = false
    callStatus.statusMsg = ""
    local rv

    -- check connection to piwigo
    if not (propertyTable.Connected) then
        rv = PiwigoAPI.login(propertyTable)
        if not rv then
            callStatus.statusMsg = 'PiwigoAPI.pwCategoriesSetinfo - cannot connect to piwigo'
            return callStatus
        end
    end

    -- check role is admin level
    if propertyTable.userStatus ~= "webmaster" then
        callStatus.statusMsg = "PiwigoAPI:pwCategoriesMove - User needs webmaster role on piwigo gallery at " ..
            propertyTable.host .. " to reorder albums"
        return callStatus
    end

    local remoteId = info.remoteId
    local newName = info.name

    local params = {
        { name = "method",      value = "pwg.categories.setInfo" },
        { name = "category_id", value = tostring(remoteId) },
        { name = "name",        value = newName },
        { name = "pwg_token",   value = propertyTable.token }
    }
    log:info("PiwigoAPI.pwCategoriesSetinfo - params \n" .. utils.serialiseVar(params))

    local httpResponse, httpHeaders = LrHttp.postMultipart(
        propertyTable.pwurl,
        params,
        {
            headers = { field = "Cookie", value = propertyTable.cookies }
        }
    )

    log:info("PiwigoAPI.pwCategoriesSetinfo - httpHeaders\n" .. utils.serialiseVar(httpHeaders))
    log:info("PiwigoAPI.pwCategoriesSetinfo - httpResponse\n" .. utils.serialiseVar(httpResponse))

    local body
    if httpResponse then
        body = JSON:decode(httpResponse)
    end
    if httpHeaders.status == 201 or httpHeaders.status == 200 then
        if body.stat == "ok" then
            callStatus.status = true
            callStatus.statusMsg = ""
        else
            callStatus.status = false
            callStatus.statusMsg = "Category " .. tostring(remoteId) .. " - " .. (body.message or "")
        end
    else
        callStatus.status = false
        callStatus.statusMsg = "Category " .. tostring(remoteId) .. " - " .. (body.message or "")
    end

    return callStatus
end

-- *************************************************
function PiwigoAPI.checkPhoto(propertyTable, pwImageID)
    -- check if image with this id exists on Piwigo
    -- pwg.images.getInfo
    local rtnStatus = {}
    rtnStatus.status = false

    local status, statusDes
    local Params = {
        { name = "method",   value = "pwg.images.getInfo" },
        { name = "image_id", value = pwImageID }
    }

    -- build headers to include cookies from pwConnect call
    local headers = {}
    if propertyTable.cookieHeader ~= nil then
        headers = { ["Cookie"] = propertyTable.cookieHeader }
    end
    local getResponse = httpGet(propertyTable.pwurl, Params, headers)
    if getResponse.errorMessage or (not getResponse.response) then
        rtnStatus.httpStatus = getResponse.status
        rtnStatus.httpStatusDes = (getResponse.errorMessage or "Unknown error")
    end
    if getResponse.status == "ok" then
        local imageDets = getResponse.response.result
        rtnStatus.status = true
        rtnStatus.httpStatus = getResponse.status
        rtnStatus.httpStatusDes = ""
        rtnStatus.imageDets = imageDets
    else
        rtnStatus.httpStatus = getResponse.status
        rtnStatus.httpStatusDes = (getResponse.errorMessage or "Unknown error")
    end
    return rtnStatus
end

-- *************************************************
function PiwigoAPI.updateGallery(propertyTable, exportFilename, metaData)
    -- update gallery with image via pwg.images.addSimple

    local callStatus = {}
    callStatus.status = false

    local params = {
        { name = "method",   value = "pwg.images.addSimple" },
        { name = "category", value = metaData.Albumid },
        { name = "author",   value = metaData.Creator },
        { name = "name",     value = metaData.Title },
        { name = "comment",  value = metaData.Caption }
    }
    -- keywords
    if metaData.tagString and metaData.tagString ~= "" then
        table.insert(params,
            { name = "tags", value = metaData.tagString })
    end

    if metaData.Remoteid ~= "" then
        -- check if remote photo exists and ignore parameter if not
        log:info("PiwigoAPI.updateGallery - checking for existing photo with remoteid " .. metaData.Remoteid)
        local rtnStatus = PiwigoAPI.checkPhoto(propertyTable, metaData.Remoteid)
        if rtnStatus.status then
            -- image exists - so we will update
            table.insert(params, { name = "image_id", value = tostring(metaData.Remoteid) })
        end
    end
    local fileType = LrPathUtils.extension(exportFilename):lower()
    local contentType = ""
    if fileType == "png" then
        contentType = "image/png"
    elseif fileType == "jpg" or fileType == "jpeg" then
        contentType = "image/jpeg"
    else
        callStatus.statusMsg = "Upload failed - forbidden file type"
        LrDialogs.message("Cannot upload " ..
            LrPathUtils.leafName(exportFilename) ..
            " to Piwigo - forbidden file type. Check file settings in Publishing Manager.")
        return callStatus
    end
    table.insert(params, {
        name        = "image",
        filePath    = exportFilename,
        fileName    = LrPathUtils.leafName(exportFilename),
        contentType = contentType,
    })



    local uploadSuccess = false
    -- Build multipart POST request to pwg.images.addSimple
    log:info("PiwigoAPI.updateGallery - params \n" .. utils.serialiseVar(params))

    local status, statusDes
    local httpResponse, httpHeaders = LrHttp.postMultipart(
        propertyTable.pwurl,
        params,
        {
            headers = { field = "Cookie", value = propertyTable.cookies }
        }
    )
    log:info("PiwigoAPI.updateGallery - httpHeaders\n" .. utils.serialiseVar(httpHeaders))
    log:info("PiwigoAPI.updateGallery - httpResponse\n" .. utils.serialiseVar(httpResponse))

    if httpHeaders.status == 201 or httpHeaders.status == 200 then
        local rv, response = pcall(function() return JSON:decode(httpResponse) end)
        if not (rv) then
            callStatus.statusMsg = "Upload failed - Invalid JSON response - " .. tostring(httpResponse)
            LrDialogs.message("Cannot upload " ..
                LrPathUtils.leafName(exportFilename) .. " to Piwigo - Invalid JSON response - " .. tostring(httpResponse))
            return callStatus
        end
        if response.stat == "ok" then
            callStatus.remoteid = response.result.image_id
            callStatus.remoteurl = response.result.url
            callStatus.status = true
            callStatus.statusMsg = ""

            -- finalise upload via pwg.images.uploadCompleted
            params = {
                { name = "method",      value = "pwg.images.uploadCompleted" },
                { name = "image_id",    value = tostring(callStatus.remoteid) },
                { name = "pwg_token",   value = propertyTable.token },
                { name = "category_id", value = metaData.Albumid }
            }
            local headers = {}
            if propertyTable.cookieHeader ~= nil then
                headers = { ["Cookie"] = propertyTable.cookieHeader }
            end
            local getResponse = httpGet(propertyTable.pwurl, params, headers)
            if getResponse.errorMessage or (not getResponse.response) then
                callStatus.statusMsg = "Cannot finalise upload - " ..
                    metaData.fileName .. " to Piwigo - " .. (getResponse.errorMessage or "Unknown error")
                LrDialogs.message(callStatus.statusMsg)
                return callStatus
            else
                if getResponse.status == "ok" then
                    callStatus.status = true
                    uploadSuccess = true
                else
                    callStatus.statusMsg = "Cannot finalise upload - " ..
                        metaData.fileName .. " to Piwigo - " .. (getResponse.errorMessage or "Unknown error")
                    LrDialogs.message(callStatus.statusMsg)
                    return callStatus
                end
            end
        end
    end
    if not (uploadSuccess) then
        if httpHeaders.error then
            statusDes = httpHeaders.error.name
            status = httpHeaders.error.errorCode
        else
            statusDes = httpHeaders.statusDes
            status = httpHeaders.status
        end
        LrDialogs.message("Cannot upload - " .. metaData.fileName .. " to Piwigo - " .. status, statusDes)
        callStatus.statusMsg = "Cannot upload - " .. metaData.fileName .. " to Piwigo - " .. status .. ", " .. statusDes
    end
    return callStatus
end

-- *************************************************
function PiwigoAPI.updateMetadata(propertyTable, lrPhoto, metaData)
    -- update metadata of photo on Piwigo
    local callStatus = {}
    callStatus.status = false
    local rv
    -- check connection to piwigo
    if not (propertyTable.Connected) then
        rv = PiwigoAPI.login(propertyTable)
        if not rv then
            callStatus.statusMsg = 'PiwigoAPI:updateMetadata - cannot connect to piwigo'
            return callStatus
        end
    end
    -- check role is admin level
    if propertyTable.userStatus ~= "webmaster" then
        callStatus.statusMsg = "User needs webmaster role on piwigo gallery at " ..
            propertyTable.host .. " to update metadata"
        return callStatus
    end
    if metaData.Remoteid ~= "" then
        log:info("PiwigoAPI.updateMetadata - checking for existing photo with remoteid " .. metaData.Remoteid)
        local rtnStatus = PiwigoAPI.checkPhoto(propertyTable, metaData.Remoteid)
        if not rtnStatus.status then
            callStatus.statusMsg = "PiwigoAPI.updateMetadata - cannot locate image " ..
                metaData.Remoteid .. " on Piwigo - cannot update metadata"
            return callStatus
        end
    else
        callStatus.statusMsg = "PiwigoAPI.updateMetadata - missing Piwigo image ID - cannot update metadata"
        return callStatus
    end

    local params = {
        { name = "method",              value = "pwg.images.setInfo" },
        { name = "image_id",            value = tostring(metaData.Remoteid) },
        { name = "author",              value = metaData.Creator },
        { name = "name",                value = metaData.Title },
        { name = "comment",             value = metaData.Caption },
        { name = "date_creation",       value = metaData.dateCreated },
        { name = "single_value_mode",   value = "replace" }, -- force metadata to be replaced rather than appended
        { name = "multiple_value_mode", value = "replace" }, -- force tags to be replaced rather than appended
        { name = "pwg_token",           value = propertyTable.token }
    }
    -- keywords
    if metaData.tagString and metaData.tagString ~= "" then
        -- convert tagString to list of tagIDS
        if not (propertyTable.tagTable) then
            -- get list of all tagIDs if not already available
            rv, propertyTable.tagTable = PiwigoAPI.getTagList(propertyTable)
            if not rv then
                callStatus.statusMsg = 'PiwigoAPI:updateMetadata - cannot get taglist from Piwigo'
                return callStatus
            end
        end
        local tagIdList, missingTags = utils.tagsToIds(propertyTable.tagTable, metaData.tagString)

        if #missingTags > 0 then
            -- need to create tags for missingTags
            local rv, newTags = PiwigoAPI.createTags(propertyTable, missingTags)
            if rv then
                -- add new tags to image's tag id list
                tagIdList = tagIdList .. "," .. utils.tabletoString(newTags, ",")
            end
        end

        if tagIdList and tagIdList ~= "" then
            table.insert(params, { name = "tag_ids", value = tagIdList })
        end
    end

    -- now update Piwigo
    local postResponse = PiwigoAPI.httpPostMultiPart(propertyTable, params)
    if not postResponse.status then
        callStatus.statusMsg = "Unable to set metadata - " .. postResponse.statusMsg
        return callStatus
    end
    callStatus.status = true
    return callStatus
end

-- *************************************************
function PiwigoAPI.deletePhoto(propertyTable, pwCatID, pwImageID, callStatus)
    -- delete image from piwigo via pwg.images.delete
    callStatus.status = false
    local rv
    -- check connection to piwigo
    if not (propertyTable.Connected) then
        rv = PiwigoAPI.login(propertyTable)
        if not rv then
            callStatus.statusMsg = 'PiwigoAPI:deletePhoto - cannot connect to piwigo'
            return callStatus
        end
    end
    local params = {
        { name = "method",    value = "pwg.images.delete" },
        { name = "image_id",  value = tostring(pwImageID) },
        { name = "pwg_token", value = propertyTable.token }
    }

    log:info("PiwigoAPI.deletePhoto - propertyTable \n " .. utils.serialiseVar(propertyTable))
    log:info("PiwigoAPI.deletePhoto - params \n" .. utils.serialiseVar(params))
    --log:info("PiwigoAPI.deletePhoto - headrs \n" .. utils.serialiseVar(headers))

    local httpResponse, httpHeaders = LrHttp.postMultipart(
        propertyTable.pwurl,
        params,
        {
            headers = { field = "Cookie", value = propertyTable.cookies }
        }
    )

    log:info("PiwigoAPI.deletePhoto - httpResponse \n" .. utils.serialiseVar(httpResponse))
    log:info("PiwigoAPI.deletePhoto - httpHeaders \n" .. utils.serialiseVar(httpHeaders))

    local body
    if httpResponse then
        body = JSON:decode(httpResponse)
    end

    if httpHeaders.status == 201 or httpHeaders.status == 200 then
        if body.stat == "ok" then
            callStatus.status = true
            callStatus.statusMsg = ""
        else
            callStatus.status = false
            callStatus.statusMsg = body.message or ""
        end
    else
        callStatus.status = false
        callStatus.statusMsg = body.message or ""
    end
    return callStatus
end

-- *************************************************
function PiwigoAPI.associateImages(propertyTable)
end

-- *************************************************
function PiwigoAPI.specialCollections(propertyTable)
    -- create special collections to allow photos to be published to Piwigo albums with sub albums
    -- for each publishedCollectionSet look for child collection with name format
    -- [Photos in collectionname]
    -- if missing, create it using the same remoteId as the publishedCollectionSet uses

    log:info("PiwigoAPI.specialCollections")
    local rv
    local catalog = LrApplication.activeCatalog()
    local allSets = {}

    -- getPublishService to get reference to this publish service - returned in propertyTable._service
    rv = PiwigoAPI.getPublishService(propertyTable)
    if not rv then
        LrErrors.throwUserError(
            "Error in PiwigoAPI.specialCollections: Cannot find Piwigo publish service for host/user.")
        return false
    end
    local publishService = propertyTable._service
    if not publishService then
        LrErrors.throwUserError("PiwigoAPI.specialCollections: Piwigo publish service is nil.")
        return false
    end

    -- get all publishedcollectionsets in this publish service
    utils.recursePubCollectionSets(publishService, allSets)
    if #allSets == 0 then
        LrDialogs.message("Create Special Collections", "No collection sets found so no special collections created")
        return false
    end
    local progressScope = LrProgressScope {
        title = "Create Special Collections...",
        caption = "Starting...",
        functionContext = context,
    }
    --[[
    -- check if scNameFix has been run and run it if not
    if not(propertyTable.scNameFix) then
        log:info("PiwigoAPI.specialCollections - running scNameFix")
        rv = PiwigoAPI.fixSpecialCollectionNames(catalog, publishService, propertyTable)
        propertyTable.scNameFix = true
    end
    ]]
    for s, thisSet in pairs(allSets) do
        progressScope:setPortionComplete(s, #allSets)
        progressScope:setCaption("Processing " .. s .. " of " .. #allSets .. " collction sets")
        local remoteId = thisSet:getRemoteId()
        local name = thisSet:getName()
        local scName = PiwigoAPI.buildSpecialCollectionName(name)
        local scColl = PiwigoAPI.createPublishCollection(catalog, publishService, propertyTable, scName, remoteId,
            thisSet)
        if scColl == nil then
            LrDialogs.message("Failed to create special collection for " .. name, "", "warning")
        end
    end

    progressScope:done()
    LrDialogs.message("Create Special Collections", string.format("%s collection sets processed", #allSets))
    return true
end

-- *************************************************
function PiwigoAPI.setAlbumCover(publishService)
    -- Set album cover on Piwigo Album

    log:info("PiwigoAPI.setAlbumCover")
    log:info("publishservice" .. publishService:getName())
    local catalog = LrApplication.activeCatalog()
    local publishSettings = publishService:getPublishSettings()
    log:info("publishSettings\n" .. utils.serialiseVar(publishSettings))

    if not publishSettings then
        LrDialogs.message("PiwigoAPI.setAlbumCover - Can't find PublishSettings for this publish collection", "",
            "warning")
        return false
    end
    local selPhotos = catalog:getTargetPhotos()
    local sources = catalog:getActiveSources()
    if utils.nilOrEmpty(selPhotos) then
        LrDialogs.message("Please select a photo to set as album cover", "", "warning")
        return false
    end
    if #selPhotos > 1 then
        LrDialogs.message("Please select a single photo to set as album cover (" .. #selPhotos .. " currently selected)",
            "", "warning")
        return false
    end

    -- we now have a single photo.
    local selPhoto = selPhotos[1]
    log:info("Selected photo is " .. selPhoto.localIdentifier)

    -- is source a LrPublishedCollection or LrPublishedCollectionSet in selected published service
    local useService = nil
    local useSource = nil
    local catId = nil
    for s, source in pairs(sources) do
        if source:type() == "LrPublishedCollection" or source:type() == "LrPublishedCollectionSet" then
            log:info("Source " .. s .. " is " .. source:getName())
            local thisService = source:getService()
            if thisService:getName() == publishService:getName() then
                useService = thisService
                useSource = source
                catId = source:getRemoteId()
                break
            end
        end
    end
    if not useService then
        LrDialogs.message("Please select a photo in the selected publish service (" .. publishService:getName() .. ")",
            "", "warning")
        return false
    end
    if not useSource then
        LrDialogs.message("Please select a photo in the selected publish service (" .. publishService:getName() .. ")",
            "", "warning")
        return false
    end
    if not catId then
        LrDialogs.message(
            "PiwigoAPI.setAlbumCover - Can't find Piwigo album ID for remoteId for this publish collection", "",
            "warning")
        return false
    end
    log:info("Source is " .. useSource:getName())
    -- is photo in that source
    -- if so then we can set it as reference photo for album on Piwigo
    -- find publised photo in this collection / set
    local thisPubPhoto = utils.findPhotoInCollectionSet(useSource, selPhoto)
    if not thisPubPhoto then
        LrDialogs.message("PiwigoAPI.setAlbumCover - Can't find this photo in collection set or collections", "",
            "warning")
        return false
    end
    local remoteId = thisPubPhoto:getRemoteId()
    if not remoteId then
        LrDialogs.message("PiwigoAPI.setAlbumCover - Can't find Piwigo photo ID for this photo", "", "warning")
        return false
    end
    -- get reference to this photo in useSource to get remoteId

    log:info("useService is " .. useService:getName())
    local result = LrDialogs.confirm("Set Piwigo Album Cover",
        "Set select photo as cover photo for " .. useSource:getName() .. "?", "Ok", "Cancel")
    if result ~= 'ok' then
        return false
    end

    log:info("Setting  photo " .. remoteId .. " as cover for " .. catId)
    -- set as the representative photo for an album.
    -- the Piwigo web service doesn't require that the photo belongs to the album but this function does
    -- use pwg.categories.setRepresentative(categoryId, photoId), POST only, Admin only

    local rv

    -- check connection to piwigo
    if not (publishSettings.Connected) then
        rv = PiwigoAPI.login(publishSettings)
        if not rv then
            LrDialogs.message('PiwigoAPI.setAlbumCover - cannot connect to piwigo')
            return false
        end
    end

    -- check role is admin level
    if publishSettings.userStatus ~= "webmaster" then
        LrDialogs.message("User needs webmaster role on piwigo gallery at " ..
            publishSettings.host .. " to set album cover")
        return false
    end

    -- now update Piwigo
    local params = {
        { name = "method",      value = "pwg.categories.setRepresentative" },
        { name = "category_id", value = catId },
        { name = "image_id",    value = remoteId },
    }
    local postResponse = PiwigoAPI.httpPostMultiPart(publishSettings, params)

    if not postResponse.status then
        LrDialogs.message("Unable to set cover photo - " .. postResponse.statusMsg)
        return false
    end

    return true
end

-- *************************************************
function PiwigoAPI.getTagList(propertyTable)
    -- return table of all tags on Piwigo
    -- return as allTags

    local rv
    -- check connection to piwigo
    if not (propertyTable.Connected) then
        rv = PiwigoAPI.login(propertyTable)
        if not rv then
            LrDialogs.message("PiwigoAPI.getTagList - cannot connect to piwigo")
            return false
        end
    end
    local Params = {
        --{ name = "method", value = "pwg.tags.getList"},
        { name = "method", value = "pwg.tags.getAdminList" },
    }
    -- build headers to include cookies from pwConnect call
    local headers = {}
    if propertyTable.cookieHeader ~= nil then
        headers = { ["Cookie"] = propertyTable.cookieHeader }
    end
    local getResponse = httpGet(propertyTable.pwurl, Params, headers)
    if getResponse.errorMessage or (not getResponse.response) then
        LrDialogs.message("Cannot get tag list from Piwigo - ", (getResponse.errorMessage or "Unknown error"))
        return false
    end
    if getResponse.status == "ok" then
        local allTags = getResponse.response.result.tags
        return true, allTags
    else
        LrDialogs.message("Cannot get tag list from Piwigo - ", (getResponse.errorMessage or "Unknown error"))
        return false
    end
end

-- *************************************************
function PiwigoAPI.createTags(propertyTable, missingTags)
    -- create a Piwigo tag for each entry in missingTags using pwg.tags.add
    -- return comma speparated list of created id
    -- update propertyTable.allTags

    local rv
    local createdTagIds = {}
    if #missingTags == 0 then
        return false, createdTagIds
    end
    local callStatus = PiwigoAPI.checkAdmin(propertyTable)
    if not callStatus.status then
        callStatus.statusMsg = "User needs webmaster role on piwigo gallery at " .. propertyTable.host .. " to add tags"
        return false, createdTagIds
    end

    for _, tagString in pairs(missingTags) do
        local Params = {
            { name = "method", value = "pwg.tags.add" },
            { name = "name",   value = tagString }
        }

        -- build headers to include cookies from pwConnect call
        local headers = {}
        if propertyTable.cookieHeader ~= nil then
            headers = { ["Cookie"] = propertyTable.cookieHeader }
        end
        local getResponse = httpGet(propertyTable.pwurl, Params, headers)
        if getResponse.errorMessage or (not getResponse.response) then
            LrDialogs.message("Cannot add tag " .. tagString .. " to Piwigo - ",
                (getResponse.errorMessage or "Unknown error"))
        else
            if getResponse.status == "ok" then
                local tagID = getResponse.response.result.id
                table.insert(createdTagIds, tagID)
            else
                LrDialogs.message("Cannot add tag " .. tagString .. " to Piwigo - ",
                    (getResponse.errorMessage or "Unknown error"))
            end
        end
    end

    -- refresh cached tag list
    rv, propertyTable.tagTable = PiwigoAPI.getTagList(propertyTable)

    return true, createdTagIds
end

-- *************************************************
function PiwigoAPI.httpPostMultiPart(propertyTable, params)
    -- generic function to call LrHttp.PostMultiPart
    -- LrHttp.postMultipart( url, content, headers, timeout, callbackFn, suppressFormData )
    local postResponse = {}
    local postHeaders = {}
    log:info("PiwigoAPI.httpPostMultiPart - params\n" .. utils.serialiseVar(params))
    local httpResponse, httpHeaders = LrHttp.postMultipart(
        propertyTable.pwurl,
        params,
        {
            headers = { field = "Cookie", value = propertyTable.cookies }
        }
    )
    log:info("PiwigoAPI.httpPostMultiPart - httpResponse \n" .. utils.serialiseVar(httpResponse))
    log:info("PiwigoAPI.httpPostMultiPart - httpHeaders \n" .. utils.serialiseVar(httpHeaders))

    local body
    if httpResponse then
        body = JSON:decode(httpResponse)
    end
    if httpHeaders then
        postHeaders.status = httpHeaders.status
        postHeaders.statusDesc = (httpHeaders and (httpHeaders.statusDes or httpHeaders.statusDesc)) or ""
    end
    if not body then
        postResponse.status = false
        postResponse.statusMsg = postHeaders.status .. " - " .. postHeaders.statusDesc
        return postResponse
    end
    if httpHeaders.status == 201 or httpHeaders.status == 200 then
        if body.stat == "ok" then
            postResponse.status = true
            postResponse.statusMsg = ""
        else
            postResponse.status = false
            postResponse.statusMsg = body.message or ""
        end
    else
        postResponse.status = false
        postResponse.statusMsg = body.message or ""
    end
    return postResponse
end

-- *************************************************
function PiwigoAPI.createHeaders(propertyTable)
    return {
        { field = 'pwg_token',    value = propertyTable.token },
        { field = 'Accept',       value = 'application/json' },
        { field = 'Content-Type', value = 'application/json' },
    }
end

-- *************************************************
function PiwigoAPI.createHeadersForMultipart(propertyTable)
    return {
        { field = 'pwg_token', value = propertyTable.token },
        { field = 'Accept',    value = 'application/json' },
    }
end

-- *************************************************
function PiwigoAPI.createHeadersForMultipartPut(propertyTable, boundary, length)
    return {
        { field = 'pwg_token',      value = propertyTable.token },
        { field = 'Accept',         value = 'application/json' },
        { field = 'Content-Type',   value = 'multipart/form-data;boundary="' .. boundary .. '"' },
        { field = 'Content-Length', value = length },
    }
end

-- *************************************************
return PiwigoAPI
