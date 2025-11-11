-- PublishTask.lua
-- Publish Tasks for Piwigo Publisher plugin

PublishTask = {}


-- ************************************************
function PublishTask.processRenderedPhotos(functionContext, exportContext)

    local debug = true
    local callStatus ={}


    local exportSession = exportContext.exportSession
    local propertyTable = exportContext.propertyTable

    if debug then
        log:trace('PublishTask.processRenderedPhotos - publishSettings:\n' .. utils.serialiseVar(propertyTable))
    end

    -- Set progress title.
    local nPhotos = exportSession:countRenditions()
    local progressScope = exportContext:configureProgress {
        title = "Publishing " .. nPhotos .. " photos to " .. propertyTable.host
    }

    -- check connection to piwigo
    if not (propertyTable.Connected) then
        log:info("PiwigoAPI.pwCategoriesMove 2 - logging in")
        rv = PiwigoAPI.login(propertyTable, false)
        if not rv then
            LrErrors.throwUserError('Publish photos to Piwigo - cannot connect to piwigo at ' .. propertyTable.host)
            return nil
        end
    end
    if debug then
        log:trace('PublishTask.processRenderedPhotos - publishSettings:\n' .. utils.serialiseVar(propertyTable))
    end


    local publishedCollection = exportContext.publishedCollection
    local albumId = publishedCollection:getRemoteId()
    local albumName = publishedCollection:getName()
    local checkCats
    local rv

    -- Check that collection exists as an album on Piwigo and create if not
    rv, checkCats = PiwigoAPI.pwCategories(propertyTable, albumId, debug)
    if not rv then
        LrErrors.throwUserError('Publish photos to Piwigo - cannot check category exists on piwigo at ' .. propertyTable.host)
        return nil
    end
    if debug then
        log:trace('PublishTask.processRenderedPhotos - checkcats:\n' .. utils.serialiseVar(checkCats))
    end
    if utils.nilOrEmpty(checkCats) then
        -- todo - create album on piwigo if missing
        local metaData = {}
        callStatus = {}
        metaData.albumName = albumName
        callStatus = PiwigoAPI.createCat(propertyTable, publishedCollection, metaData, callStatus, debug)
        if callStatus.status then
            --exportSession:recordRemoteCollectionId(callStatus.albumId)
            --exportSession:recordRemoteCollectionUrl(callStatus.albumURL))
        else
            LrErrors.throwUserError('Publish photos to Piwigo - cannot create Piwigo album for  ' .. albumName)
            return nil
        end
        
        -- delete once createCat is working
        LrErrors.throwUserError('Publish photos to Piwigo - missing Piwigo album for  ' .. albumName)
        return nil
    end

    -- now export photos and upload to Piwigo
    for i, rendition in exportContext:renditions { stopIfCanceled = true } do
        -- Wait for next photo to render.
        log:trace('PublishTask.processRenderedPhotos - waitForRender:')
        local lrPhoto = rendition.photo
        local lrPubPhoto = rendition.publishedPhoto
        local success, pathOrMessage = rendition:waitForRender()
        log:trace('PublishTask.processRenderedPhotos - rendered:' .. pathOrMessage)

        -- Check for cancellation again after photo has been rendered.
        if progressScope:isCanceled() then 
            if LrFileUtils.exists(pathOrMessage) then
                LrFileUtils.delete(pathOrMessage)
            end
            break
        end

        if success then
            -- photo has been exported to temporary location - upload to piwigo
         
            callStatus = {}
            local filePath = pathOrMessage
            local metaData = {}
            metaData.Albumid = albumId
            metaData.Creator = lrPhoto:getFormattedMetadata( "creator" ) or ""
            metaData.Title = lrPhoto:getFormattedMetadata("title") or ""
            metaData.Caption = lrPhoto:getFormattedMetadata("caption") or ""
            metaData.fileName = lrPhoto:getFormattedMetadata("fileName") or ""
            if lrPubPhoto then
                metaData.Remoteid = lrPubPhoto:getRemoteId()
                -- TODO check if this remoteid still exists on Piwigo
            else
                metaData.Remoteid = ""
            end
            log:trace('PublishTask.processRenderedPhotos - metaData \n' .. utils.serialiseVar(metaData))
            -- do the upload
            callStatus = PiwigoAPI.updateGallery(propertyTable, filePath ,metaData, callStatus, debug)
            if callStatus.status then
                rendition:recordPublishedPhotoId(callStatus.remoteid or "")
                rendition:recordPublishedPhotoUrl(callStatus.remoteurl or "")
                rendition:renditionIsDone(true)
            else
                rendition:uploadFailed(callStatus.message or "Upload failed")
            end
            -- When done with photo, delete temp file.
            LrFileUtils.delete(pathOrMessage)
        else
            rendition:uploadFailed(pathOrMessage or "Render failed")
        end
    end

    progressScope:done()

    
end

-- ************************************************
function PublishTask.getCommentsFromPublishedCollection(publishSettings, arrayOfPhotoInfo, commentCallback)
    log:trace('PublishTask.shouldDeletePublishService')
end

-- ************************************************
function PublishTask.shouldDeletePublishService( publishSettings, info )
    log:trace('PublishTask.getCommentsFromPublishedCollection')

end

-- ************************************************
function PublishTask.willDeletePublishService( publishSettings, info )
    log:trace('PublishTask.willDeletePublishService')

end

-- ************************************************
function PublishTask.deletePhotosFromPublishedCollection(publishSettings, arrayOfPhotoIds, deletedCallback, localCollectionId)

    
    local debug = false
    local callStatus ={}
    if debug then
        log:trace('PublishTask.deletePhotosFromPublishedCollection - publishSettings:\n' .. utils.serialiseVar(publishSettings))
    end

    local catalog = LrApplication.activeCatalog()
    local publishedCollection = catalog:getPublishedCollectionByLocalIdentifier(localCollectionId)


    -- check connection to piwigo
    if not (publishSettings.Connected) then
        log:info("PiwigoAPI.pwCategoriesMove 2 - logging in")
        local rv = PiwigoAPI.login(publishSettings, false)
        if not rv then
            LrErrors.throwUserError('Delete Photos from Collection - cannot connect to piwigo at ' .. publishSettings.url)
            return nil
        end
    end

    for i = 1, #arrayOfPhotoIds do
        local pwImageID = arrayOfPhotoIds[i]
        local pwCatID = publishedCollection:getRemoteId()
        callStatus = PiwigoAPI.deletePhoto(publishSettings,pwCatID,pwImageID, callStatus, debug)
        if callStatus.status then

            deletedCallback(arrayOfPhotoIds[i])
        else
            LrErrors.throwUserError('Failed to delete asset ' .. pwImageID .. ' from Piwigo - ' .. callStatus.statusMsg, 'Failed to delete photo')
        end

    end

end

-- ************************************************
function PublishTask.deletePublishedCollection(publishSettings, info)

    log:trace('PublishTask.deletePublishedCollection called')

end

-- ************************************************
function PublishTask.renamePublishedCollection(publishSettings, info)
    log:trace("PublishTask.renamePublishedCollection")
    return true, '' -- TODO

end

-- ************************************************
function PublishTask.addCommentToPublishedPhoto( publishSettings, remotePhotoId, commentText )
    log:trace("PublishTask.addCommentToPublishedPhoto")
end

-- ************************************************
function PublishTask.shouldDeletePhotosFromServiceOnDeleteFromCatalog(publishSettings, nPhotos)
    log:trace("PublishTask.shouldDeletePhotosFromServiceOnDeleteFromCatalog")
    return nil -- Show builtin Lightroom dialog.
end

-- ************************************************
function PublishTask.validatePublishedCollectionName(name)
    log:trace("PublishTask.validatePublishedCollectionName")
    return true, '' -- TODO
end

-- ************************************************
function PublishTask.getCollectionBehaviorInfo(publishSettings)
    log:trace("PublishTask.getCollectionBehaviorInfo " .. publishSettings.host)
    return {
        defaultCollectionName = 'default',
        defaultCollectionCanBeDeleted = true,
        canAddCollection = true,
        -- Allow unlimited depth of collection sets, as requested by user.
        -- maxCollectionSetDepth = 0,
    }
end

-- ************************************************
function PublishTask.didUpdatePublishService( publishSettings, info )

    log:trace("PublishTask.didUpdatePublishService")
end


-- ************************************************
function PublishTask.reparentPublishedCollection( publishSettings, info )
  -- ablums being rearranged in publish service
    -- neee to reflect this in piwigo
    local debug = false
    local callStatus ={}
    if debug then
        log:trace("PublishTask.reparentPublishedCollection - publishSettings:\n" .. utils.serialiseVar(publishSettings))
    end
    -- which collection is being moved and to where
    local allParents= info.parents
    local myCat = info.remoteId
    local parentCat = 0
    if not(utils.nilOrEmpty(allParents)) then
        parentCat = allParents[#allParents].remoteCollectionId
    end
    LrTasks.startAsyncTask(function()
        callStatus = PiwigoAPI.pwCategoriesMove(publishSettings, info, myCat, parentCat, callStatus, debug)
        if not(callStatus.status) then
            LrErrors.throwUserError("Error moving album: " .. callStatus.statusMsg)
            return false
        end
        return true
    end)
    -- TODO - moving collection structure may leave collectionsets with no sub-collections.
    -- should these be converted to collections so photos can be added
    -- in piwigo all albums can store photos even if they have sub albums
end

