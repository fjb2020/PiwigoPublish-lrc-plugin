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

    local body, hdrs = LrHttp.get(getUrl,headers)
    
    log:info("PWAPI.httpGet - httpHeaders\n" .. utils.serialiseVar(hdrs))
    log:info("PWAPI.httpGet - httpResponse\n" .. utils.serialiseVar(body))

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
local function httpPost(propertyTable, params)
-- generic function to call LrHttp.Post
    -- LrHttp.post( url, postBody, headers, method, timeout, totalSize )

    -- convert table of name, value pairs to a urlencoded string
    local body = utils.buildBodyFromParams(params)

end

-- *************************************************
local function httpPostMultiPart()
-- generic function to call LrHttp.PostMultiPart 
    -- LrHttp.postMultipart( url, content, headers, timeout, callbackFn, suppressFormData )
end

-- *************************************************
local function getVersion(propertyTable)

    -- call pwg.getVersion to get the Piwigo version
    local versionInfo = {}  
    local params = {
        { name = "method", value = "pwg.getVersion"},
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
local function pwGetSessionStatus( propertyTable)
-- successful connection, now get user role and token via pwg.session.getStatus
    log:info("pwGetSessionStatus")
    local Params = {
        { name = "method", value = "pwg.session.getStatus"},
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
        propertyTable.ConStatus = "Connected to Piwigo Gallery at " .. propertyTable.host .. " as " .. propertyTable.userStatus .. " - Piwigo version " .. propertyTable.pwVersion
        
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
                parentId = ids[#ids - 0]  -- the last number in the chain is this cat’s own id, so second to last is parent
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
local function createPublishCollection(catalog, publishService, propertyTable, name, remoteId, parentSet)
    -- create new collection or return existing
    log:info("createPublishCollection - " .. name .. ", " .. remoteId)
    local newColl
    catalog:withWriteAccessDo("Create PublishedCollection ", function()
        newColl = publishService:createPublishedCollection( name, parentSet, true )
    end)
    -- add remoteids and urls to collection
    catalog:withWriteAccessDo("Add Piwigo details to collection", function() 
        newColl:setRemoteId( remoteId)
        newColl:setRemoteUrl( propertyTable.host .. "/index.php?/category/" .. remoteId )
        newColl:setName( name )
    end)
    return newColl
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
    if not(parentColl) then
        LrErrors.throwUserError("Error in createCollection: No parent collection for " .. node.name)
        stat.errors = stat.errors + 1
    else
        -- look for this collection - create if not found
        existingColl = utils.recursivePubCollectionSearchByRemoteID(publishService, node.id)
        if not(existingColl) then
            -- not an existing collection/set for this node and we have got the parent collection/set
            if parentColl:type() ~= "LrPublishedCollectionSet" and parentColl:type() ~= "LrPublishService" then
                -- parentColl is not of type that can accept child collections - need to handle
                LrErrors.throwUserError("Error in createCollection: Parent collection for " .. node.name .. " is " .. parentColl:type() .. " - can't create child collection")
                stat.errors = stat.errors + 1
            else
                if isLeafNode then
                    -- create Publishedcollection
                    catalog:withWriteAccessDo("Create PublishedCollection ", function()
                        newColl = publishService:createPublishedCollection( node.name, parentColl, true )
                    end)
                    stat.collections = stat.collections + 1
                else
                    -- Create PublishedCollectionSet
                    catalog:withWriteAccessDo("Create PublishedCollectionSet ", function() 
                        newColl = publishService:createPublishedCollectionSet( node.name, parentColl, true )
                    end)
                    stat.collectionSets = stat.collectionSets + 1
                end
                -- now add remoteids and urls to collections and collection sets
                catalog:withWriteAccessDo("Add Piwigo details to collections", function() 
                    newColl:setRemoteId( node.id )
                    newColl:setRemoteUrl( propertyTable.host .. "/index.php?/category/" .. node.id )
                    newColl:setName( node.name )
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
    propertyTable._service = thisService  -- store a reference for button callbacks
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
        log:info('PiwigoAPI:login - missing host, username or password', "Error: Piwigo server URL, username or password is empty.")
        return false
    end

    local rv =  PiwigoAPI.pwConnect(propertyTable)
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
        { name  = "method", value = "pwg.session.login" },
        { name  = "username", value = propertyTable.userName },
        { name  = "password", value = propertyTable.userPW},
        { name  = "format", value = "json" },
    }
    local body = utils.buildPostBodyFromParams(urlParams)

    local headers = {
        { field = "Content-Type", value = "application/x-www-form-urlencoded" },
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
                    if nameValue and string.sub(nameValue,1,3) == "pwg" then
                        table.insert(cookies, nameValue)
                        if nameValue:match("^pwg_id=") then
                            SessionCookie = nameValue
                        end
                    end
                end
            end
            propertyTable.SessionCookie = SessionCookie
            propertyTable.cookies  = cookies
            propertyTable.cookieHeader = table.concat(propertyTable.cookies,"; ")
            propertyTable.Connected = true
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

    -- successful connection, now get user role and token via pwg.session.getStatus
    local rv = pwGetSessionStatus(propertyTable)

    return rv
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
        utils.handleError('PiwigoAPI:importAlbums - cannot find publish service - has it been saved?', "Error: Cannot find Piwigo publish service - has it been saved?")
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
            utils.handleError('PiwigoAPI:importAlbums - cannot connect to piwigo', "Error: Cannot connect to Piwigo server.")
            return
        end
    end
    -- get categories from piwigo
    local allCats
    rv, allCats  = PiwigoAPI.pwCategoriesGet(propertyTable, "")
    if not rv then
        utils.handleError('PiwigoAPI:importAlbums - cannot get categories from piwigo', "Error: Cannot get categories from Piwigo server.")
        return
    end
    if utils.nilOrEmpty(allCats) then
        utils.handleError('PiwigoAPI:importAlbums - no categories found in piwigo', "Error: No categories found in Piwigo server.")
        return
    end

    -- hierarchical table of categories
    local catHierarchy = buildCatHierarchy(allCats)

    -- in Piwigo an album can have photos as well as sub-albums. In LrC, a collectionset does not have photos
    -- ToDo - deal with this via creating a collection within each collection set for photos at this level in Piwigo - so called super-album
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
    LrDialogs.message("Import Piwigo Albums", string.format("%s new collections, %s new collection sets, %s existing, %s errors",statusData.collections,statusData.collectionSets,statusData.existing,statusData.errors ))
   
end

-- *************************************************
function PiwigoAPI.pwCategoriesGet(propertyTable, thisCat)

    -- get list of categories from Piwigo
    -- if thisCat is set then return this category and children, otherwise all categories
    local status, statusDes
    local Params = {
        { name = "method", value = "pwg.categories.getList"},
        { name = "recursive", value = "true"},
        { name = "fullname", value = "false"}
    }

    if not(utils.nilOrEmpty(thisCat))  then
        table.insert(Params,{ name = "cat_id", value = tostring(thisCat)})
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
        rv = PiwigoAPI.login(propertyTable, false)
        if not rv then
            callStatus.statusMsg =  'PiwigoAPI:pwCategoriesMove - cannot connect to piwigo'
            return callStatus
        end
    end
  
    -- check role is admin level
    if propertyTable.userStatus ~= "webmaster" then
        callStatus.statusMsg = "PiwigoAPI:pwCategoriesMove - User needs webmaster role on piwigo gallery at " .. propertyTable.host .. " to reorder albums"
        return callStatus
    end

    -- check parent category exists 
    -- newCat of 0 means move to root so no parent album
    if newCat ~= 0 then
        local checkCats
        rv, checkCats  = PiwigoAPI.pwCategoriesGet(propertyTable, tostring(newCat))
        if utils.nilOrEmpty(checkCats) then
            callStatus.statusMsg = "PiwigoAPI:pwCategoriesMove - Cannot find parent category " .. newCat .. " in Piwigo"
            return callStatus
        end
    end
    -- move album on piwigo
    -- parameters for POST
    local params = {
        { name = "method", value = "pwg.categories.move"},
        { name = "category_id", value = tostring(thisCat)} ,
        { name = "parent", value = newCat} ,
        { name = "pwg_token", value = propertyTable.token},
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
        rv = PiwigoAPI.login(propertyTable, false)
        if not rv then
            callStatus.statusMsg =  'PiwigoAPI:pwCategoriesAdd - cannot connect to piwigo'
            return callStatus
        end
    end
  
    -- check role is admin level
    if propertyTable.userStatus ~= "webmaster" then
        callStatus.statusMsg = "PiwigoAPI:pwCategoriesAdd - User needs webmaster role on piwigo gallery at " .. propertyTable.host .. " to reorder albums"
        return callStatus
    end

    local Params = {
        { name = "method", value = "pwg.categories.add"},
        { name = "name", value = metaData.name},
        { name = "pwg_token", value = propertyTable.token}
    }
    if metaData.parentCat ~= "" then
        table.insert( Params, { name = "parent", value = metaData.parentCat } )
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
        LrDialogs.message("Cannot add new category to Piwigo - ", getResponse.errorMessage )
        callStatus.status = false
    end
    return callStatus
end

-- *************************************************
function PiwigoAPI.pwCategoriesDelete( propertyTable, info, metaData, callStatus)
    -- delete category on Piwigo using pwg.categories.delete

    callStatus.status = false
    local status, statusDes
    local rv

    local checkCats
    -- check connection to piwigo
    if not (propertyTable.Connected) then
        rv = PiwigoAPI.login(propertyTable, false)
        if not rv then
            callStatus.statusMsg =  'PiwigoAPI:pwCategoriesDelete - cannot connect to piwigo'
            return callStatus
        end
    end
  
    -- check role is admin level
    if propertyTable.userStatus ~= "webmaster" then
        callStatus.statusMsg = "PiwigoAPI:pwCategoriesDelete - User needs webmaster role on piwigo gallery at " .. propertyTable.host .. " to reorder albums"
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
        { name = "method", value = "pwg.categories.delete"},
        { name = "category_id", value = metaData.catToDelete},
        { name = "photo_delete_mode", value ="delete_orphans"},
        { name = "pwg_token", value = propertyTable.token},
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
        rv = PiwigoAPI.login(propertyTable, false)
        if not rv then
            callStatus.statusMsg =  'PiwigoAPI.pwCategoriesSetinfo - cannot connect to piwigo'
            return callStatus
        end
    end

    -- check role is admin level
    if propertyTable.userStatus ~= "webmaster" then
        callStatus.statusMsg = "PiwigoAPI:pwCategoriesMove - User needs webmaster role on piwigo gallery at " .. propertyTable.host .. " to reorder albums"
        return callStatus
    end

    local remoteId = info.remoteId
    local newName = info.name

    local params = {
        { name = "method", value = "pwg.categories.setInfo" },
        { name = "category_id", value = tostring(remoteId) },
        { name = "name", value = newName },
        { name = "pwg_token", value = propertyTable.token}
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
        { name = "method", value = "pwg.images.getInfo"},
        { name = "image_id", value = pwImageID}
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
function PiwigoAPI.updateGallery(propertyTable, exportFilename, metaData, callStatus)
    -- update gallery with image via pwg.images.addSimple


    callStatus.status = false

    local params = {
        { name  = "method", value = "pwg.images.addSimple" },
        { name  = "category",value = metaData.Albumid },
        { name  = "author", value = metaData.Creator},
        { name  = "name", value = metaData.Title },
        { name  = "comment", value = metaData.Caption}
    }
    if metaData.Remoteid ~= "" then
        -- check if remote photo exists and ignore parameter if not
        log:info("PiwigoAPI.updateGallery - checking for existing photo with remoteid " .. metaData.Remoteid)  
        local rtnStatus = PiwigoAPI.checkPhoto(propertyTable, metaData.Remoteid)
        if rtnStatus.status then
            -- image exists - so we will update
            table.insert(params, { name = "image_id", value = tostring(metaData.Remoteid)})
         end
    end
    local fileType = LrPathUtils.extension(exportFilename):lower()
    local contentType = ""
    if fileType == "png" then
        contentType = "image/png"
    elseif  fileType == "jpg" or fileType == "jpeg"  then
        contentType = "image/jpeg"
    else
        callStatus.statusMsg = "Upload failed - forbidden file type"
        LrDialogs.message("Cannot upload " .. LrPathUtils.leafName(exportFilename) .. " to Piwigo - forbidden file type. Check file settings in Publishing Manager.")
        return callStatus
    end
    table.insert(params, {
                name        = "image",
                filePath    = exportFilename,                       
                fileName    = LrPathUtils.leafName(exportFilename), 
                contentType = contentType,})

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

    if httpResponse and httpResponse == "forbidden file type" then 
        callStatus.statusMsg = "Upload failed - forbidden file type"
        LrDialogs.message("Cannot upload " .. LrPathUtils.leafName(exportFilename) .. " to Piwigo - forbidden file type. Check file settings in Publishing Manager.")
        return callStatus
    end
    if httpHeaders.status == 201 or httpHeaders.status == 200 then
        local response =  JSON:decode(httpResponse)
        if response.stat == "ok" then
            callStatus.remoteid = response.result.image_id
            callStatus.remoteurl = response.result.url
            callStatus.status = true
            callStatus.statusMsg = ""
 
        -- finalise upload via pwg.images.uploadCompleted
            params = {
                { name = "method", value = "pwg.images.uploadCompleted" },
                { name = "image_id", value = tostring(callStatus.remoteid) },
                { name = "pwg_token", value = propertyTable.token},
                { name  = "category_id",value = metaData.Albumid }
            }
            local headers = {}
            if propertyTable.cookieHeader ~= nil then
                headers = { ["Cookie"] = propertyTable.cookieHeader }
            end
            local getResponse = httpGet(propertyTable.pwurl, params, headers)
            if getResponse.errorMessage or (not getResponse.response) then
                callStatus.statusMsg = "Cannot finalise upload - " .. metaData.fileName .. " to Piwigo - " .. (getResponse.errorMessage or "Unknown error")
                LrDialogs.message(callStatus.statusMsg)
                return callStatus
            else
                if getResponse.status == "ok" then
                    callStatus.status = true
                    uploadSuccess = true
                else
                    callStatus.statusMsg = "Cannot finalise upload - " .. metaData.fileName .. " to Piwigo - " .. (getResponse.errorMessage or "Unknown error")
                    LrDialogs.message(callStatus.statusMsg)
                    return callStatus
                end
            end
        end
    end
    if not(uploadSuccess) then
        if httpHeaders.error then
            statusDes = httpHeaders.error.name
            status = httpHeaders.error.errorCode
        else
            statusDes = httpHeaders.statusDes
            status = httpHeaders.status
        end
        LrDialogs.message("Cannot upload - " .. metaData.fileName .. " to Piwigo - " .. status, statusDes)
    end

    return callStatus
end



-- *************************************************
function PiwigoAPI.deletePhoto(propertyTable, pwCatID, pwImageID, callStatus)

-- delete image from piwigo via pwg.images.delete
    callStatus.status = false
    local rv
    -- check connection to piwigo
    if not (propertyTable.Connected) then
        rv = PiwigoAPI.login(propertyTable, false)
        if not rv then
            callStatus.statusMsg =  'PiwigoAPI:deletePhoto - cannot connect to piwigo'
            return callStatus
        end
    end
    local params = {
        { name = "method", value = "pwg.images.delete" },
        { name = "image_id", value = tostring(pwImageID) },
        { name = "pwg_token", value = propertyTable.token}
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
        LrErrors.throwUserError("Error in PiwigoAPI.specialCollections: Cannot find Piwigo publish service for host/user.")
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
        LrDialogs.message("Create Special Collections", "No collection sets found so no special collections created" )
        return false
    end
    local progressScope = LrProgressScope {
        title = "Create Special Collections...",
        caption = "Starting...",
        functionContext = context,
    }

    for s, thisSet in pairs(allSets) do
        progressScope:setPortionComplete(s, #allSets)
        progressScope:setCaption("Processing " .. s .. " of " .. #allSets .. " collction sets")
        local remoteId = thisSet:getRemoteId()
        local name = thisSet:getName()
        local scName = "[Photos in " .. name .. " ]"
        local scColl = createPublishCollection(catalog, publishService, propertyTable, scName, remoteId, thisSet)
        if scColl == nil then
            LrDialogs.message("Failed to create special collection for " .. name,"","warning")
        end
    end

    progressScope:done()
    LrDialogs.message("Create Special Collections", string.format("%s collection sets processed",#allSets ))
    return true
end

-- *************************************************
function PiwigoAPI.setAlbumCover(propertyTable)

    -- Set album cover on Piwigo Album
    
    log:info("PiwigoAPI.setAlbumCover")
    log:info("propertyTable\n" .. utils.serialiseVar(propertyTable))
    local catalog = LrApplication.activeCatalog()
    local selPhotos =  catalog:getTargetPhotos()
    if utils.nilOrEmpty(selPhotos) then
        LrDialogs.message("Please select a photo to set as album cover","","warning")
        return false
    end
    if #selPhotos > 1 then
        LrDialogs.message("Please select a single photo to set as album cover (" .. #selPhotos .. " currently selected)","","warning")
        return false
    end

-- we now have a single photo.
    local Photo = selPhotos[1]
    log:info("Selected photo is " .. Photo:getFormattedMetadata("fileName"))
-- need to find which collection is active to find correct Piwigo album and if it has been published
    local publishService = propertyTable.publishService  -- LrPublishConnection
    local collection = propertyTable.collection          -- LrPublishedCollection being edited

    log:info("Publishservice is\n" .. utils.serialiseVar(publishService))
    log:info("Collection is\n" ..  utils.serialiseVar(collection))

--[[
    if source:className() == "LrPublishedCollection" then
            -- It's a published collection (LrPublishedCollection)
        local publishedCollection = source
        local service = publishedCollection:getService()
        
        if service:getName() == "Your Service Name" then
            -- This collection belongs to *your* publish service
            LrDialogs.message("Selected published collection: " .. publishedCollection:getName())
        else
            LrDialogs.message("Selected published collection belongs to a different service: " .. service:getName())
        end
    else
        LrDialogs.message("Not a published collection; it's a " .. source:className())
    end
    ]]


-- check if photo exists in this piwigo album

-- set as the representative photo for an album. 
-- the Piwigo web service doesn't require that the photo belongs to the album but this function does  

-- use pwg.categories.setRepresentative, POST only, Admin only 


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