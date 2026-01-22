--[[

    PWStatusManager.lua

    Copyright (C) 2025 Fiona Boston <fiona@fbphotography.uk>.

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

--*******************************************
-- manage service status between functions

local PWStatusManager = {}

local pwServiceState = {}
--*******************************************
local function ensureState(publishService)
    local id = publishService.localIdentifier
    local state = pwServiceState[id]
    if not state then
        state = {
            PiwigoBusy = false,
            RenderPhotos = false,
            isCloningSync = false,
            RemoteInfoTable = {},
        }
        pwServiceState[id] = state
        log:info("PWStatusManager: created new state for service " .. id)
    end
    return state
end

--*******************************************
function PWStatusManager.getServiceState(publishService)
    -- manage per publish service status flags
    return ensureState(publishService)
end

--*******************************************
function PWStatusManager.setPiwigoBusy(publishService, setValue)
    ensureState(publishService).PiwigoBusy = setValue
end

--*******************************************
function PWStatusManager.setRenderPhotos(publishService, setValue)
    ensureState(publishService).RenderPhotos = setValue
end

--*******************************************
function PWStatusManager.setisCloningSync(publishService, setValue)
    ensureState(publishService).isCloningSync = setValue
end

--*******************************************
-- store remote info for a collection
function PWStatusManager.storeRemoteInfo(publishService, collId, RemoteInfoTable)
    local state = ensureState(publishService)
    state.RemoteInfoTable[collId] = RemoteInfoTable
end

--*******************************************
-- get remote info for a collection
function PWStatusManager.getRemoteInfo(publishService, collId)
    local state = ensureState(publishService)
    return state.RemoteInfoTable[collId]
end

--*******************************************
-- clear remote info for a collection
function PWStatusManager.clearRemoteInfo(publishService, collId)
    local state = ensureState(publishService)
    state.RemoteInfoTable[collId] = nil
end

--*******************************************
return PWStatusManager
