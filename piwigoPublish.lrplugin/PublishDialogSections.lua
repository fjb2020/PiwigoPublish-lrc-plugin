--[[

	PublishDialogSections.lua

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

PublishDialogSections = {}





-- *************************************************
function PublishDialogSections.startDialog(propertyTable)

	propertyTable:addObserver('host', PiwigoAPI.ConnectionChange)
	propertyTable:addObserver('userName', PiwigoAPI.ConnectionChange)
	propertyTable:addObserver('userPW', PiwigoAPI.ConnectionChange)
	propertyTable:addObserver('tagRoot', PiwigoAPI.ConnectionChange)

	local doInit = false

	if (utils.nilOrEmpty(propertyTable.Connected)) then
		doInit = true
	else
		if not(propertyTable.Connected) then
			doInit = true
		end
	end
	if doInit then
		PiwigoAPI.ConnectionChange(propertyTable)
	end


end

-- *************************************************
function PublishDialogSections.endDialog(propertyTable, why)
  
end

-- *************************************************
local function connectionDialog (f, propertyTable, pwInstance)
	local bind = LrView.bind
	local share = LrView.share

return {
    title = "Piwigo Host Settings",
    bind_to_object = propertyTable,

	f:row {
		spacing = 60,
		f:picture {
			value = _PLUGIN:resourceId( "icons/icon_med.png" ),

		},
		f:column {
			spacing = f:control_spacing(),
			f:row {
				f:static_text {
					title = "",
					alignment = 'left',
					width = share 'labelWidth',
				},
			},
			f:row {
				f:static_text {
					title = "Piwigo Publisher Plugin",
					alignment = 'left',
					width = share 'labelWidth',
				},
			},
			f:row {
				f:static_text {
					title = "Plugin Version 20251117.3",
					alignment = 'left',
					width = share 'labelWidth',
				},
			},
		},
	},
    --f:column {
        spacing = f:control_spacing(),

        f:row {
            f:static_text {
                title = "Piwigo Host:",
                alignment = 'right',
                width = share 'labelWidth',
            },

            f:edit_field {
                value = bind 'host',
                truncation = 'middle',
                immediate = false,
                fill_horizontal = 1,

                validate = function(v, host)
                    local sanitizedURL = PiwigoAPI.sanityCheckAndFixURL(host)
                    if sanitizedURL == host then
                        return true, host, ''
                    elseif sanitizedURL ~= nil then
                        LrDialogs.message('Entered URL was autocorrected to ' .. sanitizedURL)
                        return true, sanitizedURL, ''
                    end
                    return false, host, 'Entered URL not valid.\nShould look like https://piwigo.domain.uk'
                end,
            },

            f:push_button {
                title = 'Check connection',
                enabled = bind('ConCheck', propertyTable),
                action = function(button)
                    LrTasks.startAsyncTask(function()
                        if not PiwigoAPI.login(propertyTable) then
                            LrDialogs.message('Connection NOT successful')
                        end
                    end)
                end,
            },
        },

        f:row {
            f:static_text {
                title = "User Name:",
                alignment = 'right',
                width = share 'labelWidth',
                visible = bind 'hasNoError',
            },

            f:edit_field {
                value = bind 'userName',
                width_in_chars = 24,
                truncation = 'middle',
                immediate = true,
                fill_horizontal = 1,
            },
        },

        f:row {
            f:static_text {
                title = "Password:",
                alignment = 'right',
                width = share 'labelWidth',
                visible = bind 'hasNoError',
            },

            f:password_field {
                value = bind 'userPW',
                truncation = 'middle',
                immediate = true,
                fill_horizontal = 1,
            },
        },

        f:row {
            f:static_text {
                title = bind 'ConStatus',
                alignment = 'center',
                fill_horizontal = 1,
                width = share 'labelWidth',
            },
        },
    --},
}
end

-- *************************************************
local function prefsDialog (f, propertyTable)
	local bind = LrView.bind
	local share = LrView.share

	-- get reference to this 

	return {

		title = "Piwigo Service Configuration Extras",
		bind_to_object = propertyTable,
		f:row {
			f:static_text {
				title = "For entire Piwigo Publish Service",
				alignment = 'left',
				fill_horizontal = 1,
			},		
		},
		f:spacer { height = 3 },
		f:row {
			f:static_text {
				title = "Import existing albums from Piwigo",
				alignment = 'right',
            	width = share 'labelWidth',
				tooltip = "Click to fetch the current album structure from the Piwigo Host above. Only albums the user has permission to see will be included",

			},
			f:push_button {
				title = 'Import Albums',
				enabled = bind('Connected', propertyTable),
				tooltip = "Click to fetch the current album structure from the Piwigo Host above. Only albums the user has permission to see will be included",
				action = function(button)
					local result = LrDialogs.confirm("Import Piwigo Albums","Are you sure you want to import the album structure from Piwigo?\nThis may overwrite or recreate existing collections.","Import","Cancel")
					if result == 'ok' then
						LrTasks.startAsyncTask(function()
							PiwigoAPI.importAlbums(propertyTable)
						end)
					end
				end,
			},
			f:static_text {
				title = "Note - this only updates Lightroom's local album list. It does not download any photos.",
				alignment = 'left',
				fill_horizontal = 1,
			},
		},
	}
end
--
-- *************************************************
function PublishDialogSections.sectionsForTopOfDialog(f, propertyTable )

	local conDlg = connectionDialog(f, propertyTable)
	local prefDlg = prefsDialog(f, propertyTable)
	if utils.nilOrEmpty(propertyTable.host) or utils.nilOrEmpty(propertyTable.userName) or utils.nilOrEmpty(propertyTable.userPW) then 
		propertyTable.Connected = false
		propertyTable.ConCheck = true
		propertyTable.ConStatus = "Not Connected"	
	else

	end

	return { conDlg , prefDlg }
end

-- *************************************************
function PublishDialogSections.viewForCollectionSettings(f, propertyTable, info)

	return {

		title = "Piwigo Service View for Collection Settings",
		bind_to_object = propertyTable,
		f:row {
			f:static_text {
				title = "For entire Piwigo Publish Service",
				alignment = 'left',
				fill_horizontal = 1,
			},		
		},
	}
end


-- *************************************************
function PublishDialogSections.sectionsForBottomOfDialog(f, propertyTable)
	
	return {}

end