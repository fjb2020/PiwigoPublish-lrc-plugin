-- *************************************************
-- Piwigo API
-- *************************************************
-- see https://github.com/Piwigo/Piwigo/wiki/Piwigo-Web-API


local PiwigoAPI = {}


-- *************************************************
function PiwigoAPI.ConnectionChange(propertyTable)
	log:trace('PublishDialogSections.ConnectionChange')
	propertyTable.ConStatus = "Not Connected"
	propertyTable.Connected = false
	propertyTable.ConCheck = true
	propertyTable.SessionCookie = ""
	propertyTable.cookies = nil
	propertyTable.userStatus = ""
	propertyTable.token = ""
end


-- *************************************************
function PiwigoAPI.getPublishService(propertyTable, debug)
    -- get reference to publish service matching host and userName in propertyTable
    local catalog = LrApplication.activeCatalog()


--  LrTasks.startAsyncTask(function() -- commented out as the function is already called within a task

    -- Find the matching service by comparing exportPresetFields
    local services = catalog:getPublishServices()
    local thisService
    local foundService = false
    for _, s in ipairs(services) do
        local pluginSettings = s:getPublishSettings()
        local pluginID = s:getPluginId()
        local pluginName = s:getName()  
        if debug then
            log:info("Checking service " .. pluginName .. ", ID " .. pluginID .. ", settings " .. utils.serialiseVar(pluginSettings))
        end
        if pluginSettings.host == propertyTable.host and
           pluginSettings.userName == propertyTable.userName then
            thisService = s
            foundService = true
            break
        end
    end

--  end) -- commented out as the function is already called within a task

    propertyTable._service = thisService  -- store a reference for button callbacks
	return foundService
    
end

-- *************************************************
function PiwigoAPI.sanityCheckAndFixURL(url)
    --[[
    if utils.nilOrEmpty(url) then
        utils.handleError('sanityCheckAndFixURL: URL is empty', "Error: Piwigo server URL is empty.")
        return false
    end

    local sanitizedURL = string.match(url, "^https?://[%w%.%-]+[:%d]*")
    if sanitizedURL then
        if string.len(sanitizedURL) == string.len(url) then
            log:trace('sanityCheckAndFixURL: URL is completely sane.')
            url = sanitizedURL
        else
            log:trace('sanityCheckAndFixURL: Fixed URL: removed trailing paths.')
            url = sanitizedURL
        end
    elseif not string.match(url, "^https?://") then
        utils.handleError('sanityCheckAndFixURL: URL is missing protocol (http:// or https://).')
    else
        utils.handleError('sanityCheckAndFixURL: Unknown error in URL')
    end
]]
    return url
end

-- *************************************************
function PiwigoAPI.login(propertyTable, debug)
    if utils.nilOrEmpty(propertyTable.host) or utils.nilOrEmpty(propertyTable.userName) or utils.nilOrEmpty(propertyTable.userPW) then 
        utils.handleError('PiwigoAPI:login - missing host, username or password', "Error: Piwigo server URL, username or password is empty.")
        return false
    end

    return PiwigoAPI.pwConnect(propertyTable, debug)

end

-- *************************************************
local function pwGetSessionStatus( propertyTable,debug )
-- successful connection, now get user role and token via pwg.session.getStatus

    local urlParams = {
        { name = "method", value = "pwg.session.getStatus"},
    }
    -- build headers to include cookies from pwConnect call
    local headers = {
        Cookie = propertyTable.SessionCookie
    }
    local getUrl = utils.buildGet(propertyTable.pwurl, urlParams)

    if debug then
        log:info("PiwigoAPI.pwGetSessionStatus 3 - calling " .. getUrl)
        log:info("PiwigoAPI.pwGetSessionStatus 4 - headers are " .. utils.serialiseVar(headers))
    end

    local httpResponse, httpHeaders = LrHttp.get(getUrl,headers)
    
    if debug then
        log:info("PiwigoAPI.pwGetSessionStatus 5 - httpResponse " .. utils.serialiseVar(httpResponse))
        log:info("PiwigoAPI.pwGetSessionStatus 6 - httpHeaders " .. utils.serialiseVar(httpHeaders))
    end    
    
    if httpHeaders.status == 200 then
        -- got response from Piwigo
        -- now check status
        local cookies = {}
        local rtnBody = JSON:decode(httpResponse)
        if rtnBody.stat == "ok" then
            propertyTable.userStatus = rtnBody.result.status
            propertyTable.token = rtnBody.result.pwg_token
            propertyTable.Connected = true
            propertyTable.ConCheck = false
            propertyTable.ConStatus = "Connected to Piwigo Gallery at " .. propertyTable.host .. " as " .. propertyTable.userStatus
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
        LrDialogs.message("Cannot get user status from Piwigo - " .. status, statusDes)
        return false
    end
    return true
end 

-- *************************************************
function PiwigoAPI.pwConnect(propertyTable, debug)
    -- set up connection to piwigo database
    local status, statusDes
    propertyTable.pwurl = propertyTable.host .. "/ws.php?format=json"
    propertyTable.Connected = false
    propertyTable.ConCheck = true
    propertyTable.ConStatus = "Not Connected"
    propertyTable.userStatus = ""

    local urlParams = {
        method = "pwg.session.login",
        username = propertyTable.userName,
        password = propertyTable.userPW,
        format = "json"
    }
    local body = utils.buildPost(urlParams)
--[[
    local urlParams = {
        { name  = "method", value = "pwg.session.login" },
        { name  = "username", value = propertyTable.userName },
        { name  = "password", value = propertyTable.userPW},
        { name  = "format", value = "json" },
    }
    local body = urlParams
    ]]
    local headers = {
        { field = "Content-Type", value = "application/x-www-form-urlencoded" },
        { field = "Accept-Encoding", value = "identity" },
    }

    if debug then
        log:info("PiwigoAPI.pwConnect 1 - Piwigo URL is " .. propertyTable.pwurl)
        log:info("PiwigoAPI.pwConnect 2 - Piwigo user is " .. propertyTable.userName)
        log:info("PiwigoAPI.pwConnect 3 - Piwigo password is " .. propertyTable.userPW)
        log:info("PiwigoAPI.pwConnect 5 - body is \n" .. utils.serialiseVar(body))
        log:info("PiwigoAPI.pwConnect 6 - headers are \n" .. utils.serialiseVar(headers))
    end

    local httpResponse, httpHeaders = LrHttp.post(propertyTable.pwurl, body, headers)

    if debug then 
        log:info("PiwigoAPI.pwConnect 7 - httpBody is \n" .. utils.serialiseVar(httpResponse))
        log:info("PiwigoAPI.pwConnect 8 - httpHeaders are \n" .. utils.serialiseVar(httpHeaders))
    end
    
    if (httpHeaders.status == 201) or (httpHeaders.status == 200) then
        -- successful connection to Piwigo
        -- Now check login result
        local rtnBody = JSON:decode(httpResponse)
        if rtnBody.stat == "ok" then
            -- login ok - store session cookies
            local cookies = {}
            local SessionCookie = ""
            for _, h in ipairs(httpHeaders or {}) do
                if h.field:lower() == "set-cookie" then
                    table.insert(cookies, h.value)
                    -- table.insert(cookies, LrHttp.parseCookie(h.value))
                    -- look for session cookie
                    local session = h.value:match("(pwg_id=[^;]+)")
                    if session then
                        SessionCookie = session
                    end
                end
            end
            propertyTable.SessionCookie = SessionCookie
            propertyTable.cookies  = cookies
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
    if debug then
        log:info("PiwigoAPI.pwConnect 9 - Cookies \n" .. utils.serialiseVar(propertyTable.cookies))
        log:info("PiwigoAPI.pwConnect 10 - Session Cookie \n" .. utils.serialiseVar(propertyTable.SessionCookie))
    end
    -- successful connection, now get user role and token via pwg.session.getStatus
    local rv = pwGetSessionStatus(propertyTable, debug)

    return rv
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
local function createCollection(propertyTable, node, parentNode, isLeafNode, statusData)  

    local rv
    local newColl
    local parentColl
    local existingColl, existingSet
    local catalog = LrApplication.activeCatalog()
    local stat = statusData

    -- getPublishService to get reference to this publish service - returned in propertyTable._service
    -- needs to be refreshed each time  to relfect lastest state of publishedCollections created further below
    rv = PiwigoAPI.getPublishService(propertyTable, false)
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
        -- find parent collection
        parentColl = utils.findPublishNodeByName(publishService, parentNode.name)
    end
    existingColl = utils.findPublishNodeByName(publishService, node.name)
    log:trace("createCollection - got parentColl " .. parentColl:getName(), parentColl:type())
    if not(utils.nilOrEmpty(existingColl)) then
        log:trace("createCollection - got existingColl " .. existingColl:getName(), existingColl:type())
    end

    
    if utils.nilOrEmpty(parentColl) then
       LrErrors.throwUserError("Error in createCollection: No parent collection for " .. node.name)
        stat.errors = stat.errors + 1
    else
        if not(existingColl) then
            -- not an existing collection/set for this node and we have got the parent collection/set
            if parentColl:type() ~= "LrPublishedCollectionSet" and parentColl:type() ~= "LrPublishService" then
                -- parentColl is not of type that can accept child collections - need to handle
                LrErrors.throwUserError("Error in createCollection: Parent collection for " .. node.name .. " is " .. parentColl:type() .. " - can't create child collection")
                stat.errors = stat.errors + 1
            else
                if isLeafNode then
                    -- create collection

                    catalog:withWriteAccessDo("Create PublishedCollection ", function()
                        newColl = publishService:createPublishedCollection( node.name, parentColl, true )
                    end)
                    stat.collections = stat.collections + 1
                else
                    -- Create a new collection set for intermediate levels
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
local function traverseChildren(node, parentNode, propertyTable, statusData, depth)
    -- traverseChildren
    -- Traverses a hierarchy recursively, creates collections or collections sets as needed
    -- 'node' is a table representing a category (or the root list).
    -- 'parenNode' is the node of which this node is a child
    -- 'statusData' tracks new and existing collections and sets
    -- 'depth' is used internally to track nesting level.

    local stat = statusData
    depth = depth or 0
    -- log:info("Traversing " .. node.name .. " statusData is \n" .. utils.serialiseVar(stat))
    if type(node) == 'table' and node.id then
        -- create collection or collectionSet
        local isLeafNode = false
        if node.nb_categories == 0 then
            isLeafNode = true
        else
        end
        local rv = createCollection(propertyTable, node, parentNode, isLeafNode, stat)
    end

    -- if this node has children, recurse into each child
    if node.children and type(node.children) == 'table' then
        for _, child in ipairs(node.children) do
            traverseChildren(child, node, propertyTable, stat, depth + 1)
        end
    end

end

-- *************************************************
function PiwigoAPI.importAlbums(propertyTable, debug)

    -- Import albums from piwigo and build local album structure based on piwigo categories
    -- will use remoteId in collections and collection sets to track piwigo category ids
    -- if collections or collections sets already exist they are maintained
    -- 
    local rv

    -- debug = true -- force debug for now

    -- check connection to piwigo
    if not propertyTable.Connected then
        if debug then
            log:info("PiwigoAPI.importAlbums 1 - connecting to Piwigo")
        end
        rv = PiwigoAPI.login(propertyTable, debug)
        if not rv then
            utils.handleError('PiwigoAPI:importAlbums - cannot connect to piwigo', "Error: Cannot connect to Piwigo server.")
            return false   
        end
    end

    log:trace('importing albums from ' ..propertyTable.pwurl)

    -- get categories from piwigo
    local allCats
    rv, allCats  = PiwigoAPI.pwCategories(propertyTable, "", debug)
    if not rv then
        utils.handleError('PiwigoAPI:importAlbums - cannot get categories from piwigo', "Error: Cannot get categories from Piwigo server.")
        return false   
    end
    if utils.nilOrEmpty(allCats) then
        utils.handleError('PiwigoAPI:importAlbums - no categories found in piwigo', "Error: No categories found in Piwigo server.")
        return false   
    end     
    if debug then
        log:trace("PiwigoAPI:importAlbums - allCats is \n" .. utils.serialiseVar(allCats))
    end

    -- getPublishService to get reference to this publish service - returned in propertyTable._service
    rv = PiwigoAPI.getPublishService(propertyTable, false)
    if not rv then
        utils.handleError('PiwigoAPI:importAlbums - cannot find publish service for host/user', "Error: Cannot find Piwigo publish service for host/user.")
        return false
    end
    local publishService = propertyTable._service
    if not publishService then
        utils.handleError('PiwigoAPI:importAlbums - publish service is nil', "Error: Piwigo publish service is nil.")
        return false
    end

    -- this routine creates collections for all piwigo albums

    -- hierarchical table of categories
    local catHierarchy = buildCatHierarchy(allCats)

    -- in Piwigo an album can have photos as well as sub-albums. In LrC, a collectionset does not have photos
    -- ToDo - deal with this via creating a collection within each collection set for photos at this level in Piwigo - so called super-album
    local statusData = {
        existing = 0,
        collectionSets = 0,
        collections = 0,
        errors = 0
    }
    for cc, thisNode in pairs(catHierarchy) do
        log:info("Top Level item " .. cc .. " is " .. thisNode.id, thisNode.name)
        traverseChildren(thisNode, "", propertyTable, statusData)
    end
    LrDialogs.message("Import Piwigo Albums", string.format("%s collections, %s collection sets, %s existing, %s errors",statusData.collections,statusData.collectionSets,statusData.existing,statusData.errors ))
    return true
end

-- *************************************************
function PiwigoAPI.pwCategories(propertyTable, thisCat, debug)

    -- get list of categories from Piwigo
    -- if thisCat is set then return this category and children, otherwise all categories

    if debug then
        log:info("PiwigoAPI.pwCategories 1 - thiscat " .. thisCat)
    end

    local urlParams = {
        { name = "method", value = "pwg.categories.getList"},
        { name = "recursive", value = "true"},
        { name = "fullname", value = "false"}
    }

    if not(utils.nilOrEmpty(thisCat))  then
        table.insert(urlParams,{ name = "cat_id", value = tostring(thisCat)})
    end

    -- build headers to include cookies from pwConnect call
    local headers = {["Cookie"] =  propertyTable.cookies}

    local getUrl = utils.buildGet(propertyTable.pwurl, urlParams)

    if debug then
        log:info("PiwigoAPI.pwCategories 2 - calling " .. getUrl)
        log:info("PiwigoAPI.pwCategories 3 - headers are " .. utils.serialiseVar(headers))
    end

    local httpResponse, httpHeaders = LrHttp.get(getUrl,headers)

    if httpHeaders.status == 200 then
        -- got response from Piwigo

        local cookies = {}
        SessionCookie = ""
        local rtnBody = JSON:decode(httpResponse)
        if rtnBody.stat == "ok" then
            local allCats = rtnBody.result.categories
            return true, allCats
        else
            LrDialogs.message("Cannot get categories from Piwigo - ", rtnBody.err .. ", " .. rtnBody.message)
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
        LrDialogs.message("Cannot get categories from Piwigo - " .. status, statusDes)
        return false
    end


end

-- *************************************************
function PiwigoAPI.pwCategoriesMove(propertyTable, info, thisCat, newCat, callStatus, debug)
    -- move piwigo categeory using pwg.categories.move
    
    callStatus.status = false
    callStatus.statusMsg = ""
    local rv

    -- check connection to piwigo
    if not (propertyTable.Connected) then
        log:info("PiwigoAPI.pwCategoriesMove 2 - logging in")
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
    
    local checkCats
    rv, checkCats  = PiwigoAPI.pwCategories(propertyTable, tostring(newCat), debug)
    if utils.nilOrEmpty(checkCats) then
        callStatus.statusMsg = "PiwigoAPI:pwCategoriesMove - Cannot find parent category " .. newCat .. " in Piwigo"
        return callStatus
    end

    -- move album on piwigo
    -- parameters for POST
    local params = {
        { name = "method", value = "pwg.categories.move"},
        { name = "category_id", value = tostring(thisCat)} ,
        { name = "parent", value = tostring(newCat)} ,
        { name = "pwg_token", value = propertyTable.token},
    }

    local httpResponse, httpHeaders = LrHttp.post(
        propertyTable.pwurl,
        params,
        {
            headers = { field = "Cookie", value = propertyTable.cookies }
        }
    )
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
function PiwigoAPI.createCat(propertyTable, publishedCollection, metaData, callStatus, debug )
    -- create new pwigo category
    callStatus.status = false

    -- get parent collection for publishedCollection
    -- if root then create new category with no parent otherwise use remote id for pareent
    


    return callStatus
end

-- *************************************************
function PiwigoAPI.deletePhoto(propertyTable, pwCatID, pwImageID, callStatus , debug)

-- delete image from piwigo via pwg.images.delete
    callStatus.status = false
    
    local params = {
        { name = "method", value = "pwg.images.delete" },
        { name = "image_id", value = tostring(pwImageID) },
        { name = "pwg_token", value = propertyTable.token}
    }

    --[[
    local urlParams = {
        method = "pwg.images.delete",
        image_id = tostring(pwImageID) ,
        pwg_token = propertyTable.token,
        format = "json"
    }
    local body = utils.buildPost(urlParams)
    local headers = {
        { field = "Content-Type", value = "application/x-www-form-urlencoded" },
        { field = "Cookie", value = propertyTable.SessionCookie }
    }
]]
    if debug then
        log:info("PiwigoAPI.deletePhoto - propertyTable \n " .. utils.serialiseVar(propertyTable))
        log:info("PiwigoAPI.deletePhoto - params \n" .. utils.serialiseVar(Params))
        --log:info("PiwigoAPI.deletePhoto - headrs \n" .. utils.serialiseVar(headers))
    end
    local httpResponse, httpHeaders = LrHttp.postMultipart(
        propertyTable.pwurl, 
        params,
        {
            headers = { field = "Cookie", value = propertyTable.cookies } 
        }
    
    )
    if debug then
        log:info("PiwigoAPI.deletePhoto - httpResponse \n" .. utils.serialiseVar(httpResponse))
        log:info("PiwigoAPI.deletePhoto - httpHeaders \n" .. utils.serialiseVar(httpHeaders))
    end

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
function PiwigoAPI.updateGallery(propertyTable, exportFilename, metaData, callStatus, debug)
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
        table.insert(params, { name = "image_id", value = tostring(metaData.Remoteid)})
    end

    table.insert(params, {
                name        = "image",
                filePath    = exportFilename,                       
                fileName    = LrPathUtils.leafName(exportFilename), 
                contentType = "image/jpeg",})

    if debug then
        log:info("PiwigoAPI.updateGallery - Params for addsimple are \n" .. utils.serialiseVar(params))
    end
    local uploadSuccess = false
-- Build multipart POST request to pwg.images.addSimple
    local statusDes
    local status
    local httpResponse, httpHeaders = LrHttp.postMultipart(
        propertyTable.pwurl,
        params,
        {
            headers = { field = "Cookie", value = propertyTable.cookies }
        }
    )

    if debug then
        log:info("PiwigoAPI.updateGallery - response from addsimple \n" .. utils.serialiseVar(httpResponse))
    end

    if httpHeaders.status == 201 or httpHeaders.status == 200 then
        local response = JSON:decode(httpResponse)
        if response.stat == "ok" then
            callStatus.remoteid = response.result.image_id
            callStatus.remoteurl = response.result.url
            callStatus.status = true
            callStatus.statusMsg = ""
            if debug then
                log:info("PiwigoAPI.updateGallery - callstatus is \n" .. utils.serialiseVar(callStatus))
            end
        -- finalise upload via pwg.images.uploadCompleted
            params = {
                { name = "method", value = "pwg.images.uploadCompleted" },
                { name = "image_id", value = tostring(callStatus.remoteid) },
                { name = "pwg_token", value = propertyTable.token},
                { name  = "category_id",value = metaData.Albumid }
            }
            if debug then
                log:info("PiwigoAPI.updateGallery - params for uploadcompleted are " .. utils.serialiseVar(params))
            end

            local headers = {["Cookie"] =  propertyTable.cookies}
            local getUrl = utils.buildGet(propertyTable.pwurl, params)

            if debug then
                log:info("PiwigoAPI.pwCategories 2 - calling " .. getUrl)
                log:info("PiwigoAPI.pwCategories 3 - headers are " .. utils.serialiseVar(headers))
            end

            local finaliseResult, finaliseHeaders = LrHttp.get(getUrl,headers)
            if finaliseHeaders.status == 200 then

                local parseResult = JSON:decode(finaliseResult)
                if parseResult.stat == "ok" then
                    callStatus.status = true
                    uploadSuccess = true
                end

                if debug then
                    log:info("updated imaage id " .. callStatus.remoteid)
                    log:info("parsedata is \n" .. utils.serialiseVar(parseData))
                    log:info("finalizeResult is \n" .. utils.serialiseVar(parseResult))
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
        return callStatus
    end



    return callStatus
    
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