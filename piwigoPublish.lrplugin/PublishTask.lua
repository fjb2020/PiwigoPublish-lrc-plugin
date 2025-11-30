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
    local rv
        -- Set progress title.
    local nPhotos = exportSession:countRenditions()
    local progressScope = exportContext:configureProgress {
        title = "Publishing " .. nPhotos .. " photos to " .. propertyTable.host
    }

    -- check connection to piwigo
    if not (propertyTable.Connected) then
        rv = PiwigoAPI.login(propertyTable, false)
        if not rv then
            PiwigoBusy = false
            LrErrors.throwUserError('Publish photos to Piwigo - cannot connect to piwigo at ' .. propertyTable.host)
            return nil
        end
    end

    log:info('PublishTask.processRenderedPhotos - publishSettings:\n' .. utils.serialiseVar(propertyTable))

    local publishedCollection = exportContext.publishedCollection
    local albumId = publishedCollection:getRemoteId()
    local albumName = publishedCollection:getName()
    local parentCollSet = publishedCollection:getParent()
    local parentID = ""
    local requestRepub = false
    if parentCollSet then
        parentID = parentCollSet:getRemoteId()
    end
    local checkCats

    -- Check that collection exists as an album on Piwigo and create if not
    rv, checkCats = PiwigoAPI.pwCategoriesGet(propertyTable, albumId)
    if not rv then
        PiwigoBusy = false
        LrErrors.throwUserError('Publish photos to Piwigo - cannot check category exists on piwigo at ' .. propertyTable.host)
        return nil
    end

    if utils.nilOrEmpty(checkCats) then
        -- create missing album on piwigo (may happen if album is deleted directly on Piwigo rather than via this plugin)
        -- but - album may exist and permissions may have changed so we now can't see it.
        local metaData = {}
        callStatus = {}
        metaData.name = albumName
        metaData.parentId = parentID
        callStatus = PiwigoAPI.pwCategoriesAdd(propertyTable, publishedCollection, metaData, callStatus)
        if callStatus.status then
            -- reset album id to newly created one
            albumId = callStatus.newCatId
            exportSession:recordRemoteCollectionId(albumId)
            exportSession:recordRemoteCollectionUrl(callStatus.albumURL)
            LrDialogs.message("*** Missing Piwigo album ***",  albumName ..", Piwigo Cat ID " .. albumId .. " created")
            requestRepub = true

        else
            PiwigoBusy = false
            LrErrors.throwUserError('Publish photos to Piwigo - cannot create Piwigo album for  ' .. albumName)
            return nil
        end
    end

    -- now export photos and upload to Piwigo
    for i, rendition in exportContext:renditions { stopIfCanceled = true } do
        -- Wait for next photo to render.

        local lrPhoto = rendition.photo
        local remoteId = rendition.publishedPhotoId or ""

        local success, pathOrMessage = rendition:waitForRender()

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

            -- do the upload
            callStatus = PiwigoAPI.updateGallery(propertyTable, filePath ,metaData, callStatus)

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
    
    -- Check if republishRequested

    if requestRepub then
        LrDialogs.message("*** Missing Piwigo album ***",  "Please rePublish all photos in " .. albumName)
        --[[
        ToDo
        -- trigger republish of all photos in this album - missing Piwigo Album was created
        local repub = LrDialogs.confirm("rePublish Required",  "Do you wish to republish all photos in " .. albumName, "Yes", "No" )
        log:info("PublishTask.processRenderedPhotos - republish requested " .. repub)
        if repub == "ok" then
            -- mark each photo in collection as publishedPhoto:setEditedFlag( edited ) to trigger a republish
            -- Must be called from within one of the catalog:with___WriteAccessDo gates (including withPrivateWriteAccessDo).
        end
        ]]
    end
    
end

-- ************************************************
function PublishTask.deletePhotosFromPublishedCollection(publishSettings, arrayOfPhotoIds, deletedCallback, localCollectionId)
    if PiwigoBusy then
        return nil
    end
    PiwigoBusy = true
    local callStatus ={}


    local catalog = LrApplication.activeCatalog()
    local publishedCollection = catalog:getPublishedCollectionByLocalIdentifier(localCollectionId)

    -- check connection to piwigo
    if not (publishSettings.Connected) then
         local rv = PiwigoAPI.login(publishSettings, false)
        if not rv then
            PiwigoBusy = false
            LrErrors.throwUserError('Delete Photos from Collection - cannot connect to piwigo at ' .. publishSettings.url)
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
            PiwigoBusy = false
            LrErrors.throwUserError('Failed to delete asset ' .. pwImageID .. ' from Piwigo - ' .. callStatus.statusMsg, 'Failed to delete photo')
        end
        deletedCallback( pwImageID)
    end
    PiwigoBusy = false
end

-- ************************************************
function PublishTask.getCommentsFromPublishedCollection(publishSettings, arrayOfPhotoInfo, commentCallback)

end

-- ************************************************
function PublishTask.shouldDeletePublishService( publishSettings, info )


    -- TODO
    -- Add dialog with details of photos and sub collections that will be orphaned if delete goes ahead

end


-- ************************************************
function PublishTask.addCommentToPublishedPhoto( publishSettings, remotePhotoId, commentText )

end

-- ************************************************
function PublishTask.shouldDeletePhotosFromServiceOnDeleteFromCatalog(publishSettings, nPhotos)
    return nil -- Show builtin Lightroom dialog.

end

-- ************************************************
function PublishTask.validatePublishedCollectionName(name)

    log:info("PublishTask.validatePublishedCollectionName")
    if PiwigoBusy then
        return false, "Piwigo is busy. Please try later."
    end
    -- look for [ and ] 
    if string.sub(name,1,1) == "[" or string.sub(name,-1) == "]" then
        return false, "Cannot use [ ] at start and end of album name - clashes with special collections"
    end

    return true

end

-- ************************************************
function PublishTask.getCollectionBehaviorInfo(publishSettings)
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

end

-- ************************************************
function PublishTask.viewForCollectionSettings( f, publishSettings, info )

end

-- ************************************************
function PublishTask.updateCollectionSettings( publishSettings, info )
    -- this callback is triggered by LrC when a change is made to an existing collectionset or a new one is created
    -- We use it only for the creation of new collections to create a corresponding album on Piwigo
    -- therefore we need to check if the associated piwigo album already exists and do nothing if so
         -- check if operation is in progress and exit if so


    local callStatus = {
        status = false,
        statusMsg = ""
    }

    local metaData = {}
    local newCollectionName = info.name
    local newCollection = info.publishedCollection

    -- check if remoteId is present on this collection and exit if so
    local remoteId = newCollection:getRemoteId()
    if not (utils.nilOrEmpty(remoteId)) then
        -- album exists on Piwigo - ignore
        callStatus.status = true
        return callStatus
    end
    -- create new album on Piwigo
    metaData.name = newCollectionName
    metaData.type = "collection"
    if utils.nilOrEmpty(info.parents) then
        -- creating album at root of publish service
        metaData.parentCat = ""
    else
        metaData.parentCat = info.parents[#info.parents].remoteCollectionId or ""
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
            "New Piwigo Album " .. metaData.name .." created with Piwigo Cat Id " .. callStatus.newCatId,
            "info"
        )
    end

    return callStatus

end


-- ************************************************
function PublishTask.viewForCollectionSetSettings( f, publishSettings, info )

  
end
-- ************************************************
function PublishTask.updateCollectionSetSettings( publishSettings, info )

    -- this callback is triggered by LrC when a change is made to an existing collectionset or a new one is created
    -- We use it only for the creation of new collections to create a corresponding album on Piwigo
    -- therefore we need to check if the associated piwigo album already exists and do nothing if so

    local callStatus = {
        status = false,
        statusMsg = ""
    }

    local metaData = {}
    local newCollectionName = info.name
    local newCollection = info.publishedCollection

    -- check if remoteId is present on this collection and exit if so
    local remoteId = newCollection:getRemoteId()
    if not (utils.nilOrEmpty(remoteId)) then
        callStatus.status = true
        return callStatus
    end

    metaData.name = newCollectionName
    metaData.type = "collectionset"
    if utils.nilOrEmpty(info.parents) then
        -- creating album at root of publish service
        metaData.parentCat = ""
    else
        metaData.parentCat = info.parents[#info.parents].remoteCollectionId or ""
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

    return callStatus
end

-- ************************************************
function PublishTask.reparentPublishedCollection( publishSettings, info )
  -- ablums being rearranged in publish service
    -- neee to reflect this in piwigo
    log:info("PublishTask.reparentPublishedCollection")
    log:info("info\n" .. utils.serialiseVar(info))
    if PiwigoBusy then
        -- pwigo processing another request - throw error
           error("Piwigo is busy. Please try later.")
    end

    -- check for special collection and prevent change if so
    local publishService = info.publishService
    local publishCollection = info.publishedCollection

    -- check for special collections and do not delete Piwigo album if so
    -- can't check remote id against parent remote id as parent will be new parent not current
    -- so just check name format
    local thisName = info.name
    if string.sub(thisName,1,1) == "[" and string.sub(thisName, -1) == "]" then
        LrErrors.throwUserError("Cannot re-parent a special collection")
        return false
    end

    local callStatus ={}
    local allParents= info.parents
    local myCat = info.remoteId
    local parentCat
    -- which collection is being moved and to where
    if utils.nilOrEmpty(allParents) then
        parentCat = 0 -- move to root
    else
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
end

-- ************************************************
function PublishTask.renamePublishedCollection(publishSettings, info)
  
    local callStatus = {}
    callStatus.status = false
    -- called for both collections and collectionsets

    local remoteId = info.remoteId
    local newName = info.name
    local collection = info.publishedCollection
    local oldName = collection:getName()
    if string.sub(oldName,1,1) == "[" and string.sub(oldName, -1) == "]" then
        callStatus.statusMsg = "Cannot re-name a special collection"
    else
        if utils.nilOrEmpty(remoteId) then
            callStatus.statusMsg = "no album found on Piwigo"
        else
            if PiwigoBusy then
                callStatus.statusMsg = "Piwigo is busy. Please try later."
            else
                callStatus = PiwigoAPI.pwCategoriesSetinfo(publishSettings,info, callStatus)
            end
        end
    end
    if not(callStatus.status) then
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
            "The Piwigo rename failed (" .. callStatus.statusMsg .. ").\nThe collection name has been reverted.",
            "warning"
        )
    end

end

-- ************************************************
function PublishTask.willDeletePublishService( publishSettings, info )

end

-- ************************************************
function PublishTask.deletePublishedCollection(publishSettings, info)

    log:info("PublishTask.deletePublishedCollection")
    log:info("info\n" .. utils.serialiseVar(info))

    if PiwigoBusy then
        -- pwigo processing another request - throw error
        error("Piwigo is busy. Please try later.")
    end

    -- called for both collections and collectionsets
    local rv
    local callStatus = {}
    callStatus.status = false
    local catToDelete = info.remoteId
    local publishService = info.publishService
    local publishCollection = info.publishedCollection


    -- check for special collections and do not delete Piwigo album if so
    local thisName = info.name
    local thisRemoteId = info.remoteId
    local parentName = ""
    local parentRemoteId = ""
    local parents = info.parents
    if #parents > 0 then
        parentName = parents[#parents].name
        parentRemoteId = parents[#parents].remoteCollectionId
    end

    if parentRemoteId == thisRemoteId then
        -- this is a special collection with the same remote id as it's parent so do not delete remote album
        -- check photos in collection and remove them from Piwigo
        if publishCollection:type() == "LrPublishedCollection" then
            local photosInCollection = publishCollection:getPublishedPhotos()
            for p, thisPhoto in pairs(photosInCollection) do
                log:info("PublishTask.deletePublishedCollection - delete photo " .. thisPhoto:getRemoteId())
                local pwImageID = thisPhoto:getRemoteId()
                local rtnStatus = PiwigoAPI.deletePhoto(publishSettings, thisRemoteId, pwImageID, callStatus)
            end
        end
        
        
        --LrDialogs.message("Delete Album","Special Collection - no Piwigo album to delete.", "warning")
        
        return true
    end

    local metaData = {
        catToDelete = catToDelete,
        publishService = publishService
    }
    if utils.nilOrEmpty(catToDelete) then
         LrDialogs.message("Delete Album", "This collection has no associated Piwigo album to delete.", "warning")
    else
        rv = PiwigoAPI.pwCategoriesDelete(publishSettings, info, metaData, callStatus)
    end
    return true

end
