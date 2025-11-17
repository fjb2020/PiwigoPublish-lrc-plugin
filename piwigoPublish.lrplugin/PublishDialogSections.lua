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

  	log.debug('PublishDialogSections.startDialog')

	-- log.debug('propertyTable contents: ' .. utils.serialiseVar(propertyTable))
	propertyTable:addObserver('host', PiwigoAPI.ConnectionChange)
	propertyTable:addObserver('userName', PiwigoAPI.ConnectionChange)
	propertyTable:addObserver('userPW', PiwigoAPI.ConnectionChange)
	propertyTable:addObserver('tagRoot', PiwigoAPI.ConnectionChange)

--[[
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
]]
	if propertyTable.host and propertyTable.userName and propertyTable.userPW then
		-- try to login 
		LrTasks.startAsyncTask(function()
			if not PiwigoAPI.login(propertyTable) then
				-- LrDialogs.message('Connection NOT successful')
			end
		end)
	end
	


end

-- *************************************************
function PublishDialogSections.endDialog(propertyTable, why)
  	log.debug('PublishDialogSections.endDialog - ' .. why)
	-- 

end

-- *************************************************
local function connectionDialog (f, propertyTable, pwInstance)
	local bind = LrView.bind
	local share = LrView.share

return {
		title = "Piwigo Host Settings",
		bind_to_object = propertyTable,
		f:row {
		-- TOP: icon + version block
            f:picture {
				alignment = 'left',
                value = iconPath,
				--value = _PLUGIN:resourceId("icons/piwigoPublish_9_5.png"),
            },
		},
		-- PW Host
		f:spacer { height = 1 },
        f:row {
			f:static_text {
				title = "",
				alignment = 'left',
				width_in_chars = 7,
			},

			f:static_text {
				title = "Piwigo Host:",
				font = "<system/bold>",
				alignment = 'left',
				width_in_chars = 8,
			},
			f:edit_field {
				value = bind 'host',
				alignment = 'left',
				width_in_chars = 30,
			},
			f:push_button {
				title = "Check connection",
				enabled = bind('ConCheck', propertyTable),
				font = "<system/bold>",
				action = function()
					LrTasks.startAsyncTask(function()
						if not PiwigoAPI.login(propertyTable) then
							LrDialogs.message('Connection NOT successful')
						end
					end)
				end,
			},
		},

		-- Username
		f:spacer { height = 1 },
		f:row {
			f:static_text {
				title = "",
				alignment = 'left',
				width_in_chars = 7,
			},
			f:static_text {
				title = "User Name:",
				font = "<system/bold>",
				alignment = 'left',
				width_in_chars = 8,
				visible = bind 'hasNoError',
			},
			f:edit_field {
				value = bind 'userName',
				alignment = 'left',
				width_in_chars = 30,
			},
		},

		-- Password
		f:spacer { height = 1 },
		f:row {
			f:static_text {
				title = "",
				alignment = 'left',
				width_in_chars = 7,
			},
			f:static_text {
				title = "Password:",
				font = "<system/bold>",
				alignment = 'left',
				width_in_chars = 8,
				visible = bind 'hasNoError',
			},
			f:password_field {
				value = bind 'userPW',
				alignment = 'left',
				width_in_chars = 30,
			},
		},

		-- Status row
		f:spacer { height = 1 },
		f:row {
			f:static_text {
				title = bind 'ConStatus',
				font = "<system/bold>",
				alignment = 'center',
				fill_horizontal = 1,
			},
		},
	}

end

-- *************************************************
local function prefsDialog (f, propertyTable)
	local bind = LrView.bind
	local share = LrView.share

	return {
		title = "Piwigo Publish Service Configuration Extras",
		bind_to_object = propertyTable,
		f:row {
			f:static_text {
				title = "Applies to all Collections and Collection Sets in this Service",
				font = "<system/bold>",
				alignment = 'left',
				fill_horizontal = 1,
			},
		},
		f:spacer { height = 2 },
		f:row {
			f:push_button {
				title = 'Import Albums',
				width = share 'buttonwidth',
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
				title = "Import existing albums from Piwigo",
				alignment = 'left',
            	-- width = share 'labelWidth',
				width_in_chars = 50,
				tooltip = "Click to fetch the current album structure from the Piwigo Host above. Only albums the user has permission to see will be included",
			},
		},
		f:spacer { height = 2 },
		f:row {
			f:push_button {
				title = 'Create special collections',
				width = share 'buttonwidth',
				enabled = bind('Connected', propertyTable),
				tooltip = "Create special publish collections for collection sets, allowing images to be published to albums with sub-albums on Piwigo",
				action = function(button)
					LrTasks.startAsyncTask(function()
						PiwigoAPI.specialCollections(propertyTable)
					end)
				end,
			},
        	f:static_text {
				title = "Create special publish collections to allow images to be published to albums with sub-albums on Piwigo",
				alignment = 'left',
            	-- width = share 'labelWidth',
				width_in_chars = 50,
				tooltip = "Create special collections to allow images to be published to albums with sub-albums on Piwigo"
			},
   		},
		f:spacer { height = 2 },
		f:row {
			f:push_button {
				title = 'Associate Images',
				width = share 'buttonwidth',
				enabled = bind('Connected', propertyTable),
				tooltip = "For each image on your Piwigo host, attempt to match an image in your LrC catalog",
				action = function(button)
					LrTasks.startAsyncTask(function()
						PiwigoAPI.associateImages(propertyTable)
					end)
				end,
			},
			f:static_text {
				title = "Associate images from Piwigo host with images in LrC Catalog",
				alignment = 'left',
            	-- width = share 'labelWidth',
				width_in_chars = 50,
				tooltip = "For each image on your Piwigo host, attempt to match an image in your LrC catalog",
			},
		},
		f:spacer { height = 2 },
		f:row {
			f:push_button {
				title = 'Check Images',
				width = share 'buttonwidth',
				enabled = bind('Connected', propertyTable),
				tooltip = "Check for missing images",
				action = function(button)
					LrTasks.startAsyncTask(function()
						PiwigoAPI.checkImages(propertyTable)
					end)
				end,
			},
			f:static_text {
				title = "Associate images from Piwigo host with images in LrC Catalog",
				alignment = 'left',
            	-- width = share 'labelWidth',
				width_in_chars = 50,
				tooltip = "For each image on your Piwigo host, attempt to match an image in your LrC catalog",
			},
		},



		
	}
end
--
-- *************************************************
function PublishDialogSections.sectionsForTopOfDialog(f, propertyTable )

  	log.debug('PublishDialogSections.sectionsForTopOfDialog')


	local conDlg = connectionDialog(f, propertyTable)
	local prefDlg = prefsDialog(f, propertyTable)
	if utils.nilOrEmpty(propertyTable.host) or utils.nilOrEmpty(propertyTable.userName) or utils.nilOrEmpty(propertyTable.userPW) then 
		propertyTable.Connected = false
		propertyTable.ConCheck = true
		propertyTable.ConStatus = "Not Connected"	
	else
		--[[
		LrTasks.startAsyncTask(function()
			if PiwigoAPI.login(propertyTable,false) then
				propertyTable.Connected = true
				propertyTable.ConCheck = false
				propertyTable.ConStatus = "Connected to Piwigo Gallery at " .. propertyTable.host
				log.debug('Token is ' .. propertyTable.token)

			else
				LrDialogs.message('Connection NOT successful')
				propertyTable.Connected = false
				propertyTable.ConCheck = true
				propertyTable.ConStatus = "Not Connected"
			end
		end)
		]]
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

	log.debug('PublishDialogSections.sectionsForBottomOfDialog')
	
	return {}

end