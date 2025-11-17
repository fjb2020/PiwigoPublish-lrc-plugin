--[[
   
    PWExtraOptions.lua

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

-- *************************************************
local function main()

     LrFunctionContext.callWithContext("PWExtraOptionsContext", function(context)
        -- Create a property table inside the context
        
        log.debug("PWExtraOptions - icons is at " .. _PLUGIN.path .. '/icons/icon.png')


        local allServices = PiwigoAPI.getPublishServicesForPlugin(_PLUGIN.id)
        if #allServices == 0 then
            LrDialogs.message("No Piwigo publish services found.")
            return
        end

        local props = LrBinding.makePropertyTable(context)
        local bind = LrView.bind
        -- Property table for UI bindings
        local props = bind {
            selectedServiceIndex = 1, -- default to first service
        }
        local serviceNames = {}
        for _, s in ipairs(allServices) do
            table.insert(serviceNames, s:getName())
        end

        local f = LrView.osFactory()
        local c = f:column {
            spacing = f:dialog_spacing(),
            f:row {
            -- TOP: icon + version block
                f:picture {
                    alignment = 'left',
                    value = iconPath,
                    -- value = _PLUGIN:resourceId("icons/piwigoPublish_9_5.png"),
                },
            },

            f:row {
                spacing = f:label_spacing(),

                f:static_text {
                    title = "Select publish service:",
                    alignment = 'right',
                    width = 150,
                },

                f:popup_menu {
                    value = bind 'selectedServiceIndex',
                    items = serviceNames,
                    width = 300,
                },
            },



            f:spacer { height = 20 },
            f:row {
                f:static_text {
                    title = "Applies to selected images",
                    font = "<system/bold>",
                    alignment = 'left',
                    fill_horizontal = 1,
                },
            },
            f:spacer { height = 1 },
            f:row {
                f:push_button {
                    title = 'Set Piwigo Album Cover',
                    tooltip = "Sets selected image as Piwigo album cover ",
                    action = function(button)
                        LrTasks.startAsyncTask(function()
                            PiwigoAPI.setAlbumCover(propertyTable)
                        end)
                    end,
                },
                f:static_text {
                    title = "Sets selected image as Piwigo album cover for this collection",
                    alignment = 'left',
                    -- width = share 'labelWidth',
                    width_in_chars = 50,
                },
            },
        }

        dialog = LrDialogs.presentModalDialog({
            title = "Piwigo Extra Options",
            contents = c,
            actionVerb = "Close",
        })
    end)
end

-- *************************************************
-- Run main()
LrTasks.startAsyncTask(main)