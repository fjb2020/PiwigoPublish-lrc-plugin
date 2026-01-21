--[[
    UpdateChecker.lua
    
    Auto-update functionality for Piwigo Publisher plugin
    Checks GitHub Releases API for new versions

    Copyright (C) 2024 Fiona Boston <fiona@fbphotography.uk>.
    Copyright (C) 2026 Julien Moreau <contact@julien-moreau.fr>.

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

local LrHttp = import 'LrHttp'
local LrTasks = import 'LrTasks'
local LrDialogs = import 'LrDialogs'
local LrDate = import 'LrDate'

local UpdateChecker = {}

-- Configuration
UpdateChecker.GITHUB_OWNER = "Piwigo"
UpdateChecker.GITHUB_REPO = "PiwigoPublish-lrc-plugin"
UpdateChecker.CHECK_INTERVAL_DAYS = 1

-- *************************************************
function UpdateChecker.parseVersion(versionStr)
    -- Converts version string like "20260111.26" to comparable number
    -- Format: YYYYMMDD.revision
    if not versionStr or versionStr == "" then
        return 0
    end
    
    -- Remove 'v' prefix if present
    versionStr = versionStr:gsub("^[vV]", "")
    
    local major, minor = versionStr:match("^(%d+)%.?(%d*)")
    if major then
        minor = minor or "0"
        return tonumber(major) * 1000 + tonumber(minor)
    end
    return 0
end

-- *************************************************
function UpdateChecker.shouldCheckForUpdates()
    -- Returns true if enough time has passed since last check
    local lastCheck = prefs.lastUpdateCheck or 0
    local now = LrDate.currentTime()
    local daysSinceCheck = (now - lastCheck) / (24 * 60 * 60)
    
    log:info("UpdateChecker.shouldCheckForUpdates - days since last check: " .. string.format("%.1f", daysSinceCheck))
    
    return daysSinceCheck >= UpdateChecker.CHECK_INTERVAL_DAYS
end

-- *************************************************
function UpdateChecker.checkForUpdates(silent)
    log:info("UpdateChecker.checkForUpdates - silent: " .. tostring(silent))
    
    LrTasks.startAsyncTask(function()
        -- Build GitHub API URL
        local url = string.format(
            "https://api.github.com/repos/%s/%s/releases/latest",
            UpdateChecker.GITHUB_OWNER,
            UpdateChecker.GITHUB_REPO
        )
        
        log:info("UpdateChecker.checkForUpdates - fetching: " .. url)
        
        -- Make HTTP request
        local response, headers = LrHttp.get(url, {
            { field = "Accept", value = "application/vnd.github.v3+json" },
            { field = "User-Agent", value = "PiwigoPublish-Lightroom-Plugin" }
        })
        
        log:info("UpdateChecker.checkForUpdates - HTTP status: " .. tostring(headers and headers.status))
        
        -- Update last check timestamp
        prefs.lastUpdateCheck = LrDate.currentTime()
        
        -- Handle errors
        if not response or (headers and headers.status ~= 200) then
            log:info("UpdateChecker.checkForUpdates - failed to fetch release info")
            if not silent then
                LrDialogs.message(
                    "Update Check Failed",
                    "Could not connect to GitHub to check for updates.\nPlease check your internet connection.",
                    "warning"
                )
            end
            return
        end
        
        -- Parse JSON response
        local ok, data = pcall(function() return JSON:decode(response) end)
        if not ok or not data then
            log:info("UpdateChecker.checkForUpdates - failed to parse JSON response")
            if not silent then
                LrDialogs.message(
                    "Update Check Failed",
                    "Could not parse update information from GitHub.",
                    "warning"
                )
            end
            return
        end
        
        -- Extract version info
        local remoteVersion = data.tag_name
        if not remoteVersion then
            log:info("UpdateChecker.checkForUpdates - no tag_name in response")
            if not silent then
                LrDialogs.message(
                    "Update Check Failed",
                    "No release information found on GitHub.",
                    "warning"
                )
            end
            return
        end
        
        log:info("UpdateChecker.checkForUpdates - remote version: " .. remoteVersion)
        log:info("UpdateChecker.checkForUpdates - current version: " .. pluginVersion)
        
        local currentNum = UpdateChecker.parseVersion(pluginVersion)
        local remoteNum = UpdateChecker.parseVersion(remoteVersion)
        
        log:info("UpdateChecker.checkForUpdates - currentNum: " .. currentNum .. ", remoteNum: " .. remoteNum)
        
        if remoteNum > currentNum then
            -- New version available
            local changelog = data.body or "No changelog available."
            -- Truncate changelog if too long
            if #changelog > 500 then
                changelog = changelog:sub(1, 500) .. "..."
            end
            
            local downloadUrl = data.html_url or 
                string.format("https://github.com/%s/%s/releases/latest", 
                    UpdateChecker.GITHUB_OWNER, UpdateChecker.GITHUB_REPO)
            
            -- Store for later use
            prefs.latestVersion = remoteVersion
            prefs.latestVersionUrl = downloadUrl
            
            log:info("UpdateChecker.checkForUpdates - new version available!")
            
            local result = LrDialogs.confirm(
                "Update Available",
                string.format(
                    "A new version of Piwigo Publisher is available!\n\n" ..
                    "Current version: %s\n" ..
                    "New version: %s\n\n" ..
                    "Changes:\n%s\n\n" ..
                    "Would you like to download it now?",
                    pluginVersion,
                    remoteVersion,
                    changelog
                ),
                "Download",
                "Later"
            )
            
            if result == "ok" then
                UpdateChecker.openDownloadPage(downloadUrl)
            end
        else
            log:info("UpdateChecker.checkForUpdates - already up to date")
            if not silent then
                LrDialogs.message(
                    "No Updates Available",
                    string.format("You are running the latest version (%s).", pluginVersion),
                    "info"
                )
            end
        end
    end)
end

-- *************************************************
function UpdateChecker.openDownloadPage(url)
    log:info("UpdateChecker.openDownloadPage - opening: " .. url)
    LrHttp.openUrlInBrowser(url)
    
    LrDialogs.message(
        "Download Started",
        "The download page has been opened in your browser.\n\n" ..
        "After downloading:\n" ..
        "1. Quit Lightroom Classic\n" ..
        "2. Replace the plugin folder with the new version\n" ..
        "3. Restart Lightroom Classic",
        "info"
    )
end

-- *************************************************
function UpdateChecker.getUpdateStatus()
    -- Returns a status string for display in Plugin Manager
    local latestVersion = prefs.latestVersion
    local currentNum = UpdateChecker.parseVersion(pluginVersion)
    local latestNum = UpdateChecker.parseVersion(latestVersion or "")
    
    if latestNum > currentNum then
        return string.format("Update available: %s", latestVersion)
    else
        return "Up to date"
    end
end

return UpdateChecker