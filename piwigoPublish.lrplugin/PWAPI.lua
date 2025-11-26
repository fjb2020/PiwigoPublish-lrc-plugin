--[[

    PWAPI.lua

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

local PWAPI = {}
-- includes Piwigo v16 API key support

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
local function httpGet(url, params, headers)
-- generic function to call LrHttp.Get
    -- LrHttp.get( url, headers, timeout )  


end

-- *************************************************
function PWAPI.getVersion(propertyTable, method)
-- call pwg.getVersion to get the Piwigo version
    local url = propertyTable.apiUrl .. '?method=pwg.getVersion'
    local headers = PWAPI.createHeaders(propertyTable)
    local params = {}

    local response, errorMessage = httpGet(url, params, headers)    

    if errorMessage then
        return nil, errorMessage
    end

    local responseTable = utils.parseJsonResponse(response)
    if not responseTable then
        return nil, "Failed to parse JSON response"
    end

    if responseTable.stat == "ok" then
        return responseTable.result.version, nil
    else
        return nil, "API Error: " .. (responseTable.message or "Unknown error")
    end
end
-- *************************************************

-- *************************************************

-- *************************************************

-- *************************************************


-- *************************************************


-- *************************************************
function PWAPI.createHeaders(propertyTable)
    return {
        { field = 'pwg_token',    value = propertyTable.token },
        { field = 'Accept',       value = 'application/json' },
        { field = 'Content-Type', value = 'application/json' },
    }
end

-- *************************************************
function PWAPI.createHeadersForMultipart(propertyTable)
    return {
        { field = 'pwg_token', value = propertyTable.token },
        { field = 'Accept',    value = 'application/json' },
    }
end

-- *************************************************
function PWAPI.createHeadersForMultipartPut(propertyTable, boundary, length)
    return {
        { field = 'pwg_token',      value = propertyTable.token },
        { field = 'Accept',         value = 'application/json' },
        { field = 'Content-Type',   value = 'multipart/form-data;boundary="' .. boundary .. '"' },
        { field = 'Content-Length', value = length },
    }
end
return PWAPI