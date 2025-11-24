--[[

    PublishTask.lua
    
    Publish Tasks for Piwigo Publisher plugin

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

PublishTask = {}


-- ************************************************
function PublishTask.processRenderedPhotos(functionContext, exportContext)
    if PiwigoBusy then
        return nil
    end
    PiwigoBusy = true
    local callStatus ={}
    local exportSession = exportContext.exportSession
    local propertyTable = exportContext.propertyTable

    log.debug('PublishTask.processRenderedPhotos - publishSettings:\n' .. utils.serialiseVar(propertyTable))


    -- Set progress title.
    local nPhotos = exportSession:countRenditions()
    local progressScope = exportContext:configureProgress {
        title = "Publishing " .. nPhotos .. " photos to " .. propertyTable.host
    }

    -- check connection to piwigo
    if not (propertyTable.Connected) then
        log.debug("PublishTask.processRenderedPhotos - logging in")
        rv = PiwigoAPI.login(propertyTable, false)
        if not rv then
            LrErrors.throwUserError('Publish photos to Piwigo - cannot connect to piwigo at ' .. propertyTable.host)
            PiwigoBusy = false
            return nil
        end
    end

    log.debug('PublishTask.processRenderedPhotos - publishSettings:\n' .. utils.serialiseVar(propertyTable))

    local publishedCollection = exportContext.publishedCollection
    local albumId = publishedCollection:getRemoteId()
    local albumName = publishedCollection:getName()
    local checkCats
    local rv

    -- Check that collection exists as an album on Piwigo and create if not
    rv, checkCats = PiwigoAPI.pwCategoriesGet(propertyTable, albumId)
    if not rv then
        LrErrors.throwUserError('Publish photos to Piwigo - cannot check category exists on piwigo at ' .. propertyTable.host)
        PiwigoBusy = false
        return nil
    end

    log.debug('PublishTask.processRenderedPhotos - checkcats:\n' .. utils.serialiseVar(checkCats))

    if utils.nilOrEmpty(checkCats) then
        -- todo - create album on piwigo if missing
        -- but - album may exist and permissions may have changed so we now can't see it.
        local metaData = {}
        callStatus = {}
        metaData.albumName = albumName
        callStatus = PiwigoAPI.pwCategoriesCreate(propertyTable, publishedCollection, metaData, callStatus)
        if callStatus.status then
            --exportSession:recordRemoteCollectionId(callStatus.albumId)
            --exportSession:recordRemoteCollectionUrl(callStatus.albumURL))
        else
            LrErrors.throwUserError('Publish photos to Piwigo - cannot create Piwigo album for  ' .. albumName)
            PiwigoBusy = false
            return nil
        end
        
        -- this shouldn't happen as piwigo albums are created as part of the LrC create album / create publishedCollectionSet routines
        LrErrors.throwUserError('Publish photos to Piwigo - missing Piwigo album for  ' .. albumName)
        PiwigoBusy = false
        return nil
    end

    -- now export photos and upload to Piwigo
    for i, rendition in exportContext:renditions { stopIfCanceled = true } do
        -- Wait for next photo to render.

        local lrPhoto = rendition.photo
        local remoteId = rendition.publishedPhotoId or ""

        log.debug('PublishTask.processRenderedPhotos - waitForRender - remoteId is :' .. remoteId)

        local success, pathOrMessage = rendition:waitForRender()

        log.debug('PublishTask.processRenderedPhotos - rendered:' .. pathOrMessage)

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
            metaData.Remoteid = remoteId
            -- TODO check if this remoteid still exists on Piwigo

            log.debug('PublishTask.processRenderedPhotos - metaData \n' .. utils.serialiseVar(metaData))

            -- do the upload
            callStatus = PiwigoAPI.updateGallery(propertyTable, filePath ,metaData, callStatus)

            log.debug('PublishTask.processRenderedPhotos - callStatus \n' .. utils.serialiseVar(callStatus))

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
    PiwigoBusy = false
end

-- ************************************************
function PublishTask.deletePhotosFromPublishedCollection(publishSettings, arrayOfPhotoIds, deletedCallback, localCollectionId)
    if PiwigoBusy then
        return nil
    end
    PiwigoBusy = true
    local callStatus ={}

    log.debug('PublishTask.deletePhotosFromPublishedCollection - publishSettings:\n' .. utils.serialiseVar(publishSettings))


    local catalog = LrApplication.activeCatalog()
    local publishedCollection = catalog:getPublishedCollectionByLocalIdentifier(localCollectionId)

    -- check connection to piwigo
    if not (publishSettings.Connected) then
        log.debug("PiwigoAPI.pwCategoriesMove 2 - logging in")
        local rv = PiwigoAPI.login(publishSettings, false)
        if not rv then
            LrErrors.throwUserError('Delete Photos from Collection - cannot connect to piwigo at ' .. publishSettings.url)
            PiwigoBusy = false
            return nil
        end
    end

    for i = 1, #arrayOfPhotoIds do
        local pwImageID = arrayOfPhotoIds[i]
        local pwCatID = publishedCollection:getRemoteId()

-- check if image is another album on Piwigo
-- if not, can delete image,otherwise remove association with this ablum

        callStatus = PiwigoAPI.deletePhoto(publishSettings,pwCatID,pwImageID, callStatus)
        if callStatus.status then
            deletedCallback(arrayOfPhotoIds[i])
        else
            LrErrors.throwUserError('Failed to delete asset ' .. pwImageID .. ' from Piwigo - ' .. callStatus.statusMsg, 'Failed to delete photo')
        end

    end
    PiwigoBusy = false
end

-- ************************************************
function PublishTask.getCommentsFromPublishedCollection(publishSettings, arrayOfPhotoInfo, commentCallback)
    log.debug('PublishTask.getCommentsFromPublishedCollection')

end

-- ************************************************
function PublishTask.shouldDeletePublishService( publishSettings, info )


    log.debug('PublishTask.shouldDeletePublishService')
    log.debug('publishSettings\n' .. utils.serialiseVar(publishSettings))
    log.debug('info\n' .. utils.serialiseVar(info))

    -- TODO
    -- Add dialog with details of photos and sub collections that will be orphaned if delete goes ahead

end


-- ************************************************
function PublishTask.addCommentToPublishedPhoto( publishSettings, remotePhotoId, commentText )

    log.debug("PublishTask.addCommentToPublishedPhoto")
end

-- ************************************************
function PublishTask.shouldDeletePhotosFromServiceOnDeleteFromCatalog(publishSettings, nPhotos)

    log.debug("PublishTask.shouldDeletePhotosFromServiceOnDeleteFromCatalog")
    return nil -- Show builtin Lightroom dialog.

end

-- ************************************************
function PublishTask.validatePublishedCollectionName(name)

    log.debug("PublishTask.validatePublishedCollectionName")
    if PiwigoBusy then
        return false, "Piwigo is busy. Please try later."
    end
    return true

end

-- ************************************************
function PublishTask.getCollectionBehaviorInfo(publishSettings)
    log.debug("PublishTask.getCollectionBehaviorInfo " .. publishSettings.host)
    return {
        defaultCollectionName = 'default',
        defaultCollectionCanBeDeleted = true,
        canAddCollection = true,
        -- Allow unlimited depth of collection sets
        -- maxCollectionSetDepth = 0,
    }
end

-- ************************************************
function PublishTask.didUpdatePublishService( publishSettings, info )

    log.debug("PublishTask.didUpdatePublishService")

end

-- ************************************************
function PublishTask.viewForCollectionSettings( f, publishSettings, info )

    log.debug("PublishTask.viewForCollectionSettings")

end

-- ************************************************
function PublishTask.updateCollectionSettings( publishSettings, info )
    -- this callback is triggered by LrC when a change is made to an existing collectionset or a new one is created
    -- We use it only for the creation of new collections to create a corresponding album on Piwigo
    -- therefore we need to check if the associated piwigo album already exists and do nothing if so

    log.debug("PublishTask.updateCollectionSettings")
    log.debug('publishSettings\n' .. utils.serialiseVar(publishSettings))
    log.debug('info\n' .. utils.serialiseVar(info))
    
    local callStatus = {
        status = false,
        statusMsg = ""
    }
    local parentCat
    local metaData = {}
    local newCollectionName = info.name
    local newCollection = info.publishedCollection

    -- check if remoteId is present on this collection and exit if so
    local remoteId = newCollection:getRemoteId()
    if not (utils.nilOrEmpty(remoteId)) then
        if debug then
            log.debug("PublishTask.updateCollectionSettings - existing album " .. remoteId)
        end
        callStatus.status = true
        return callStatus
    end
    metaData.name = newCollectionName
    metaData.type = "collection"
    if utils.nilOrEmpty(info.parents) then
        -- creating album at root of publish service
        parentCat = "root"
        metaData.parentCat = ""
    else
        parentCat = info.parents[#info.parents].remoteCollectionId or ""
        metaData.parentCat = parentCat
    end

    if parentCat == "" then
        -- no parent album on Piwigo - can't create sub album
    end
    callStatus = PiwigoAPI.pwCategoriesAdd(publishSettings, info, metaData, callStatus)
    if callStatus.status then
        -- add remote id and url to collection
        local catalog = LrApplication.activeCatalog()
        catalog:withWriteAccessDo("Add Piwigo details to collections", function() 
            newCollection:setRemoteId( callStatus.newCatId )
            newCollection:setRemoteUrl( publishSettings.host .. "/index.php?/category/" .. callStatus.newCatId )
        end)
        LrDialogs.message(
            "New Piwigo Album",
            "New Piwigo Album " .. metaData.name .." created with id " .. callStatus.newCatId,
            "info"
        )
    end
    log.debug("PublishTask.updateCollectionSettings - name, parent" .. newCollectionName, parentCat)
    

end


-- ************************************************
function PublishTask.viewForCollectionSetSettings( f, publishSettings, info )

    log.debug("PublishTask.viewForCollectionSetSettings")

end
-- ************************************************
function PublishTask.updateCollectionSetSettings( publishSettings, info )

    -- this callback is triggered by LrC when a change is made to an existing collectionset or a new one is created
    -- We use it only for the creation of new collections to create a corresponding album on Piwigo
    -- therefore we need to check if the associated piwigo album already exists and do nothing if so

    log.debug("PublishTask.updateCollectionSetSettings")
    log.debug('publishSettings\n' .. utils.serialiseVar(publishSettings))
    log.debug('info\n' .. utils.serialiseVar(info))

    local callStatus = {
        status = false,
        statusMsg = ""
    }

    local parentCat
    local metaData = {}
    local newCollectionName = info.name
    local newCollection = info.publishedCollection

    -- check if remoteId is present on this collection and exit if so
    local remoteId = newCollection:getRemoteId()
    if not (utils.nilOrEmpty(remoteId)) then

        log.debug("PublishTask.updateCollectionSetSettings - existing album " .. remoteId)

        callStatus.status = true
        return callStatus
    end


    metaData.name = newCollectionName
    metaData.type = "collectionset"
    if utils.nilOrEmpty(info.parents) then
        -- creating album at root of publish service
        parentCat = "root"
        metaData.parentCat = ""
    else
        parentCat = info.parents[#info.parents].remoteCollectionId or ""
        metaData.parentCat = parentCat
    end

    if parentCat == "" then
        -- no parent album on Piwigo - can't create sub album
    end
    callStatus = PiwigoAPI.pwCategoriesAdd(publishSettings, info, metaData, callStatus)
    if callStatus.status then
        -- add remote id and url to collection
        local catalog = LrApplication.activeCatalog()
        catalog:withWriteAccessDo("Add Piwigo details to collections", function() 
            newCollection:setRemoteId( callStatus.newCatId )
            newCollection:setRemoteUrl( publishSettings.host .. "/index.php?/category/" .. callStatus.newCatId )
        end)
        LrDialogs.message(
            "New Piwigo Album",
            "New Piwigo Album " .. metaData.name .." created with id " .. callStatus.newCatId,
            "info"
        )
    end
    log.debug("PublishTask.updateCollectionSettings - name, parent" .. newCollectionName, parentCat)
    return callStatus
end

-- ************************************************
function PublishTask.reparentPublishedCollection( publishSettings, info )
  -- ablums being rearranged in publish service
    -- neee to reflect this in piwigo

    if PiwigoBusy then
        -- pwigo processing another request - throw error
           error("Piwigo is busy. Please try later.")
    end

    local callStatus ={}
    local allParents= info.parents
    local myCat = info.remoteId
    local parentCat

    log.debug("PublishTask.reparentPublishedCollection")
    log.debug('publishSettings\n' .. utils.serialiseVar(publishSettings))
    log.debug('info\n' .. utils.serialiseVar(info))
    log.debug('allParents\n' .. utils.serialiseVar(allParents))

    -- which collection is being moved and to where
    if utils.nilOrEmpty(allParents) then
        parentCat = 0 -- move to root
    else
        log.debug('allParents\n' .. utils.serialiseVar(allParents))
        parentCat = allParents[#allParents].remoteCollectionId
    end
    LrTasks.startAsyncTask(function()
        callStatus = PiwigoAPI.pwCategoriesMove(publishSettings, info, myCat, parentCat, callStatus)
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

-- ************************************************
function PublishTask.renamePublishedCollection(publishSettings, info)
  
    local callStatus = {}
    callStatus.status = false
    -- called for both collections and collectionsets

    log.debug("PublishTask.renamePublishedCollection")
    log.debug('publishSettings\n' .. utils.serialiseVar(publishSettings))
    log.debug('info\n' .. utils.serialiseVar(info))

    local remoteId = info.remoteId
    local newName = info.name
    local collection = info.publishedCollection
    local oldName = collection:getName()


    log.debug("PublishTask.renamePublishedCollection - change name of remoteId " .. (remoteId or "") .. " from " .. oldName .. " to " .. newName)

    if utils.nilOrEmpty(remoteId) then
        callStatus.statusDesc = "no album found on Piwigo"
    else
        if PiwigoBusy then
            callStatus.statusDesc = "Piwigo is busy. Please try later."
        else
            callStatus = PiwigoAPI.pwCategoriesSetinfo(publishSettings,info, callStatus)
        end
    end
    if not(callStatus.status) then
        log.debug("PublishTask.renamePublishedCollection - reverting name back to " .. oldName .. " from " .. newName)
        LrTasks.startAsyncTask(function()
            LrFunctionContext.callWithContext("revertRename", function(context)
                local cat = LrApplication.activeCatalog()
                cat:withWriteAccessDo("Revert failed rename", function()
                    collection:setName(oldName)
                end)
            end)
        end)
        LrDialogs.message(
            "Rename Failed",
            "The Piwigo rename failed (" .. callStatus.statusDesc .. ").\nThe collection name has been reverted.",
            "warning"
        )
    end

end

-- ************************************************
function PublishTask.willDeletePublishService( publishSettings, info )

    log.debug('PublishTask.willDeletePublishService')
    log.debug('publishSettings\n' .. utils.serialiseVar(publishSettings))
    log.debug('info\n' .. utils.serialiseVar(info))

end

-- ************************************************
function PublishTask.deletePublishedCollection(publishSettings, info)

    if PiwigoBusy then
        -- pwigo processing another request - throw error
        error("Piwigo is busy. Please try later.")
    end
    local callStatus = {}
    callStatus.status = false
    -- called for both collections and collectionsets

    log.debug('PublishTask.deletePublishedCollection')
    log.debug('publishSettings\n' .. utils.serialiseVar(publishSettings))
    log.debug('info\n' .. utils.serialiseVar(info))

    -- if there are images in album what should happen? 
    -- Piwigo will create orphans if the album is just deleted
    --
    local catToDelete = info.remoteId
    local publishService = info.publishService
    local metaData = {
        catToDelete = catToDelete,
        publishService = publishService
    }
    if utils.nilOrEmpty(catToDelete) then
        callStatus.statusMsg = "This collection has no associated Piwigo album to delete."
    else
        callStatus = PiwigoAPI.pwCategoriesDelete(publishSettings, info, metaData, callStatus)
    end

    if not callStatus.status then
        LrDialogs.message(
            "Delete Album",
            callStatus.statusMsg,
            "warning"
        )
    end

end
