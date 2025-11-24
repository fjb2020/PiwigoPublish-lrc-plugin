-- logging functions
local M = {}
local LrLogger = import 'LrLogger'
local logger = LrLogger('piwigoPublish')
logger:enable('print')

-- *************************************************
function M.debug(msg)
    if debugEnabled then
        logger:trace(msg)
    end
end

-- *************************************************
function M.info(msg)
    if debugEnabled then
        logger:info(msg)
    end
end

-- *************************************************
function M.error(msg)
    if debugEnabled then
        logger:error(msg)
    end
end

-- *************************************************
return M