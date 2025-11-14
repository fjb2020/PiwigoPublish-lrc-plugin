--[[

    utils.lua

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


local utils = {}

-- *************************************************
function utils.serialiseVar(value, indent)
    -- serialises an unknown variable
    indent = indent or ""
    local t = type(value)
    
    if t == "table" then
        local parts = {}
        table.insert(parts, "{\n")
        local nextIndent = indent .. "  "
        for k, v in pairs(value) do
            local key
            if type(k) == "string" then
                key = string.format("%q", k)
            else
                key = tostring(k)
            end
            table.insert(parts, nextIndent .. "[" .. key .. "] = " .. utils.serialiseVar(v, nextIndent) .. ",\n")
        end
        table.insert(parts, indent .. "}")
        return table.concat(parts)
    elseif t == "string" then
        return string.format("%q", value)
    else
        return tostring(value)
    end
end

-- *************************************************
function utils.uuid()
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)
end

-- *************************************************
function utils.extractNumber(inStr)
-- Extract first number (integer or decimal, optional sign) from a string

    local num = string.match(inStr, "[-+]?%d+%.?%d*")
    if num then
        return tonumber(num)
    end
    return nil -- no number found
end

-- *************************************************
function utils.dmsToDecimal(deg, min, sec, hemi)
    -- convert DMS (degrees, minutes, seconds + direction) to decimal degrees
    local decimal = tonumber(deg) + tonumber(min) / 60
    if sec and sec ~= "" then
        decimal = decimal + tonumber(sec) / 3600
    end
    if hemi == "S" or hemi == "W" then
        decimal = -decimal
    end
    return decimal
end

-- *************************************************
function utils.parseSingleGPS(coordStr)
-- Try parsing a single coordinate (works for DMS or DM)
    local deg, min, sec, hemi = string.match(coordStr, "(%d+)°(%d+)'([%d%.]+)\"%s*([NSEW])")
    if deg then
        return utils.dmsToDecimal(deg, min, sec, hemi)
    end

    local deg2, min2, hemi2 = string.match(coordStr, "(%d+)°([%d%.]+)'%s*([NSEW])")
    if deg2 then
        return utils.dmsToDecimal(deg2, min2, nil, hemi2)
    end

    return nil -- not matched
end

-- *************************************************
function utils.parseGPS(coordStr)
    -- parse a coordinate string like: 51°13'31.9379" N 3°38'5.0159" W
    -- Split into two parts (latitude + longitude)
    local latStr, lonStr = string.match(coordStr, "^(.-)%s+([%d°'\"%sNSEW%.]+)$")
    if not latStr or not lonStr then
        return nil, nil, "Invalid coordinate format"
    end

    local lat = utils.parseSingleGPS(latStr)
    local lon = utils.parseSingleGPS(lonStr)

    return lat, lon

end

-- *************************************************
function utils.findNode(xmlNode,  nodeName )
    -- iteratively find nodeName in xmlNode

    if xmlNode:name() == nodeName then
        return xmlNode
    end

    for i = 1, xmlNode:childCount() do
        local child = xmlNode:childAtIndex(i)
        if child:type() == "element" then
            local found = utils.findNode(child, nodeName)
            if found then return found end
        end
    end
    return nil
end

-- *************************************************
function utils.fileExists(fName)

    local f = io.open(fName,"r")
    if f then 
        io.close(f)
        return true
    end
    return false
end

-- *************************************************
function utils.stringtoTable(inString, delim)
    -- create table based on passed in delimited string 
    local rtnTable = {}

    for substr in string.gmatch(inString, "[^".. delim.. "]*") do
        if substr ~= nil and string.len(substr) > 0 then
            table.insert(rtnTable,substr)
        end
    end

    return rtnTable
end

-- *************************************************
function utils.tabletoString(inTable, delim)
    local rtnString = ""
    for ss,value in pairs(inTable) do
        if rtnString == "" then
            rtnString = value
        else
            rtnString = rtnString .. delim .. value
        end
    end

    return rtnString
end

-- *************************************************
function utils.tagParse(tag)
  -- parse hierarchical tag structure (delimted by |) into table of individual elements
  local tag_table = {}
  for line in (tag .. "|"):gmatch("([^|]*)|") do
    table.insert(tag_table,line)
  end
  return tag_table
end

-- *************************************************
function utils.handleError(logMsg, userErrorMsg)
    -- function to log errors and throw user errors
    log:error(logMsg)
    LrDialogs.showError(userErrorMsg)
end

-- *************************************************
function utils.cutApiKey(key)
    -- replace characters of private string with elipsis
    return string.sub(key, 1, 20) .. '...'
end

---- *************************************************
function utils.GetKWHierarchy(kwHierarchy,thisKeyword,pos)
    -- build hierarchical list of parent keywords 
    kwHierarchy[pos] = thisKeyword
    if thisKeyword:getParent() == nil then
        return kwHierarchy
    end
    pos = pos + 1
    return(utils.GetKWHierarchy(kwHierarchy,thisKeyword:getParent(),pos))

end

---- *************************************************
function utils.GetKWfromHeirarchy(LrKeywords,kwStructure,logger)
    -- returns keyword from lowest element of hierarchical kwStructure (in form level1|level2|level3 ...)

    -- spilt kwStructure into individual elements
    local kwTable = utils.tagParse(kwStructure)
    local thisKW = nil
    local lastKWName = kwTable[#kwTable]
    if kwTable then
        for kk, kwName in ipairs(kwTable) do
            if thisKW then
                if thisKW:getName() == lastKWName then
                    return thisKW
                else
                    thisKW = utils.GetLrKeyword(thisKW:getChildren(),kwName)
                end
            else
                thisKW = utils.GetLrKeyword(LrKeywords,kwName)
            end

        end
    end
    return thisKW
end

-- *************************************************
function utils.GetLrKeyword(LrKeywords,keywordName)
    -- recursive function to return keyword with name matching keywordName
    for _, thisKeyword in ipairs(LrKeywords) do
        if thisKeyword:getName() == keywordName then
            return thisKeyword
        end
        -- Recursively search children
        local childMatch = utils.GetLrKeyword(thisKeyword:getChildren(), keywordName)
        if childMatch then
            return childMatch
        end
    end
    return nil
    
end

-- *************************************************
function utils.checkKw(thisPhoto, searchKw)
    -- does image contain keyword - returns keyword  or nil
    -- searchKw is string containing keyword to search for

    local kwHierarchy = {}
    local thisKwName = ""

    -- searchKw may be hierarchical - so split into each level
    local searchKwTable = utils.tagParse(searchKw)
    local searchKwLevels = #searchKwTable
    --log.debug("Looking for " .. searchKw .. " - " .. searchKwLevels .. " levels - " .. utils.serialiseVar(searchKwTable))

    local foundKW = nil -- return the keyword we find in this variable
    local stopSearch = false
    for ii, thisKeyword in ipairs(thisPhoto:getRawMetadata("keywords")) do

        -- thisKeyword is leaf node
        -- now need to build full hierarchical structure for thiskeyword
        kwHierarchy = {}
        kwHierarchy = utils.GetKWHierarchy(kwHierarchy,thisKeyword,1)
        local thisKwLevels = #kwHierarchy
        --log.debug("Checking image kw " .. thisKeyword:getName() .. " - " ..  thisKwLevels.. " levels ")
   
        for kk,kwLevel in ipairs(kwHierarchy) do
            local kwLevelName = kwLevel:getName()
            --log.debug("Level " .. kk .. " is " .. kwLevelName)
            if not stopSearch then
                if kwLevelName == searchKwTable[1] then
                    -- if we're looking for hierarchical kw need to check other levels for match aswell
                    if searchKwLevels > 1 then
                        --log.debug("Multi level kw search - " .. kwLevelName )
                        if thisKwLevels >= searchKwLevels then
                            local foundHKW = true
                            for hh = 2, searchKwLevels do
                                --log.debug("Multi level kw search at level - " .. hh .. ", " .. searchKwTable[hh] .. ", " .. kwHierarchy[kk-hh+1]:getName())
                                if searchKwTable[hh] ~= kwHierarchy[kk-hh+1]:getName() then
                                    foundHKW = false
                                end
                            end
                            if foundHKW then
                                foundKW = thisKeyword
                                --log.debug("Multilevel - Found " .. foundKW:getName())
                                stopSearch = true
                            end
                        end
                    else
                        foundKW = thisKeyword
                        --log.debug("Single Level - Found " .. foundKW:getName())
                        stopSearch = true
                    end
                end
            end
        end
    end
    return foundKW
end

-- *************************************************
local function normaliseId(id)
-- Normalise IDs for consistent comparison
    if id == nil then return nil end
    return tostring(id)
end

-- *************************************************
function utils.recursiveSearch(collNode, findName)
-- Recursively search for a published collection or published collection set
-- matching a given remoteId (string or number)

    --log.debug("recursiveSearch - collNode: " .. collNode:getName() .. " for name: " .. findName)
    --log.debug("recursiveSearch - collNode type is " .. tostring(collNode:type()))

    -- Check this collNode if it has a remote ID (only if collNode is a collection or set)
    if collNode:type() == 'LrPublishService' or collNode:type() == 'LrPublishedCollectionSet' then
        --log.debug("recursiveSearch 1 - " .. collNode:type(), collNode:getName())
        local thisName = collNode:getName()
        if thisName == findName then
            -- this collection or set matches
            --log.debug("recursiveSearch - ** MATCH ** collNode is matching node: " .. collNode:getName())
            return collNode
        end
    end
    -- Search immediate child collections
    if collNode.getChildCollections then
        local children = collNode:getChildCollections()
        if children then
            for _, coll in ipairs(children) do
                local type = coll:type()
                local thisName = coll:getName()
             --  log.debug("recursiveSearch 2 - " .. type,thisName)
                if thisName == findName then
                    -- this collection matches
                    --log.debug("recursiveSearch - ** MATCH ** Found matching collection: " .. coll:getName())
                    return coll
                end
            end
        end
    end

    -- Search child sets recursively
    if collNode.getChildCollectionSets then
        local collSets = collNode:getChildCollectionSets()
        if  collSets then
            for _, set in ipairs(collSets) do
                local foundSet = utils.recursiveSearch(set, findName)
                if foundSet then 
                    -- this set matches
                    --log.debug("recursiveSearch - ** MATCH ** Found matching collection set: " .. foundSet:getName())
                    return foundSet
                end
            end
        end
    end
    -- nothing found
    return nil
end

-- *************************************************
function utils.findPublishNodeByName(service, name)
    if not service or not name then 
        return nil 
    end
    return utils.recursiveSearch(service, normaliseId(name))
end

-- *************************************************
function utils.clean_spaces(text)
  --removes spaces from the front and back of passed in text
  text = string.gsub(text,"^%s*","")
  text = string.gsub(text,"%s*$","")
  return text
end

-- *************************************************
function utils.nilOrEmpty(val)

    if val == nil then
        return true
    end
    if type(val) == "string" and val == "" then
        return true
    end
    if type(val) == "table" then
        -- Check if table has any elements (non-empty)
        for _ in pairs(val) do
            return false
        end
        return true
    end
    return false
end

-- *************************************************
-- http utiils
-- *************************************************
function utils.urlEncode(str)
    if str then
        str = string.gsub(str, "\n", "\r\n")
        str = string.gsub(str, "([^%w _%%%-%.~])",
            function(c) return string.format("%%%02X", string.byte(c)) end)
        str = string.gsub(str, " ", "+")
    end
    return str
end

-- *************************************************
function utils.buildGet(url,params)
  -- Helper to build GET URL with params
    local encoded = {}
    for k, param in pairs(params) do
        local name = utils.urlEncode(param.name) or ""
        local value = utils.urlEncode(param.value) or ""
        table.insert(encoded, name .. "=" ..value)
    end
    return url .. "&" .. table.concat(encoded, "&")
end

-- *************************************************
function utils.buildPost(params)
  -- Helper to build urlencoded POST params
    local post = {}
    for k, v in pairs(params) do
      table.insert(post, k .. "=" .. utils.urlEncode(v))
    end
    return table.concat(post, "&")

end

-- *************************************************
function utils.buildPostBodyFromParams(params)
  -- Helper to build urlencoded POST params
  -- take param table with name value pairs and return urlencoded string

    local parts = {}
    for _, pair in ipairs(params) do
        local name  = utils.urlEncode(pair.name or "")
        local value = utils.urlEncode(pair.value or "")
        table.insert(parts, string.format("%s=%s", name, value))
    end
    return table.concat(parts, "&")


end

-- *************************************************
function utils.buildHeader(params)
  -- Helper to build GET URL with params
   
    --[[
    local header = {}
    for k, param in pairs(params) do
        local name = param.name
able.concat(post, "&")        local value = param.value
        table.insert(header, name .. "=" ..value)
    end
    return table.concat(header, "&")
    ]]
    return params
end

-- *************************************************
function utils.mergeSplitCookies(headers)
    -- fix issue where LrHttp splits headers on commas, breaking some date values in cookies

    local merged = {}
    local lastWasCookie = false

    for _, h in ipairs(headers or {}) do
        if h.field:lower() == "set-cookie" then
            if lastWasCookie and h.value:match("^%s*%d%d%s") then
                -- This looks like a continuation of an Expires date (e.g. "Thu, 01 Jan 1970...")
                merged[#merged].value = merged[#merged].value .. ", " .. h.value
            else
                table.insert(merged, { field = h.field, value = h.value })
            end
            lastWasCookie = true
        else
            lastWasCookie = false
        end
    end

    return merged
end

-- *************************************************
function utils.extract_cookies(raw)
  -- Helper function to parse Set-Cookie headers into "key=value" pairs

  local cookies = {}
  -- Split by comma to separate multiple Set-Cookie headers
  for _, cookieStr in ipairs(raw) do
        -- A cookie string looks like: "SESSIONID=abc123; Path=/; HttpOnly"
        local firstPart = cookieStr:match("^[^;]+")   -- take only before first ";"
        if firstPart then
            local k, v = firstPart:match("^%s*([^=]+)=(.*)$")
            if k and v then
                cookies[k] = v
            end
        end
  end
  return cookies

end


-- *************************************************
return utils