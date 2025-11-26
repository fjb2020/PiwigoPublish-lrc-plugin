--[[

	PluginInfoDialogSections.lua

	Publish Dialog Sections for Piwigo Publisher plugin

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
PluginInfoDialogSections = {}

-- *************************************************
function PluginInfoDialogSections.startDialog(propertyTable)
    if prefs.debugEnabled == nil then
       prefs.debugEnabled = false
    end
    if prefs.debugToFile == nil then 
        prefs.debugToFile = false
    end
    if prefs.debugEnabled then
        if prefs.debugToFile then
            log:enable("logfile")
        else
            log:enable("print")
        end
    else
        log:disable()
    end
    propertyTable.debugEnabled = prefs.debugEnabled
    propertyTable.debugToFile = prefs.debugToFile


end

-- *************************************************
function PluginInfoDialogSections.sectionsForBottomOfDialog(f, propertyTable)
    local bind = LrView.bind
    local share = LrView.share

    return {

        {
            bind_to_object = propertyTable,

            title = "Piwigo Publisher Plugin Logging",

            f:row {
                f:checkbox {
                    value = bind 'debugEnabled',
                },
                f:static_text {
                    title = "Enable debug logging",
                    alignment = 'left',
                    width = share 'labelWidth'
                },
            },
            f:row {
                f:checkbox {
                    value = bind 'debugToFile',
                    enabled = LrView.bind("debugEnabled"),    -- only allow if debug is enabled
                },
                f:static_text {
                    title = "Log to file instead of console",
                    alignment = 'right',
                    width = share 'labelWidth'
                },
                f:push_button {
                    title = "Show logfile",
                    enabled = LrView.bind("debugEnabled"),    -- only allow if debug is enabled
                    action = function (button)
                        LrShell.revealInShell(utils.getLogfilePath())
                    end,
                },
            },
            f:row {
                f:static_text {
                    enabled = LrView.bind("debugToFile"),
                    title = utils.getLogfilePath(),
                },
            },
        },
    }
end

-- *************************************************
function PluginInfoDialogSections.endDialog(propertyTable)
    prefs.debugEnabled = propertyTable.debugEnabled
    prefs.debugToFile = propertyTable.debugToFile

    if prefs.debugEnabled then
        if prefs.debugToFile then
            log:enable("logfile")
        else
            log:enable("print")
        end
    else
        log:disable()
    end
end
