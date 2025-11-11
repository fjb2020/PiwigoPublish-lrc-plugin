-- *************************************************
-- Piwigo API
-- *************************************************
-- see https://github.com/Piwigo/Piwigo/wiki/Piwigo-Web-API
-- supports piwigo v16 with apiKey - https://piwigo.org/forum/viewtopic.php?id=34465

PWAPI = {}
PWAPI.__index = PWAPI

-- *************************************************
function PWAPI:new(url, apiKey)
    local o = setmetatable({}, PWAPI)
    self.deviceIdString = 'Lightroom Piwigo Publish Plugin'
    self.apiBasePath = "/ws.php?format=json"

    self.apiKey = apiKey
    self.url = url
    return o
end

-- *************************************************
function PWAPI:reconfigure(url, apiKey)

    self.apiKey = apiKey
    self.url = url
end
-- *************************************************

-- *************************************************

-- *************************************************

-- *************************************************

-- *************************************************

-- *************************************************

-- *************************************************


-- *************************************************
return PWAPI