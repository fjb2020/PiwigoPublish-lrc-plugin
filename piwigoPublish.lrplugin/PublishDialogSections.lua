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

require "UIHelpers"

PublishDialogSections = {}

-- *************************************************
function PublishDialogSections.startDialog(propertyTable)
	log:info('PublishDialogSections.startDialog')
	if not propertyTable.LR_editingExistingPublishConnection then
		propertyTable.userName = nil
		propertyTable.userPW = nil
		propertyTable.host = nil
		propertyTable.Connected = false
		propertyTable.ConCheck = true
		propertyTable.ConStatus = "Not Connected"
	end

	propertyTable:addObserver('host', PiwigoAPI.ConnectionChange)
	propertyTable:addObserver('userName', PiwigoAPI.ConnectionChange)
	propertyTable:addObserver('userPW', PiwigoAPI.ConnectionChange)

	-- try to login
	LrTasks.startAsyncTask(function()
		local rv = PiwigoAPI.login(propertyTable)
	end)
end

-- *************************************************
function PublishDialogSections.endDialog(propertyTable, why)

end

-- *************************************************
local function connectionDialog(f, propertyTable, pwInstance)
	local bind = LrView.bind
	local share = LrView.share

	return {
		title = "Piwigo Host Settings",
		bind_to_object = propertyTable,

		-- TOP: icon + version block
		UIHelpers.createPluginHeader(f, share, iconPath, pluginVersion),

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
				validate = function(v, url)
					local sanitizedURL = PiwigoAPI.sanityCheckAndFixURL(url)
					if sanitizedURL == url then
						return true, url, ''
					elseif not (sanitizedURL == nil) then
						LrDialogs.message('Entered URL was autocorrected to ' .. sanitizedURL)
						return true, sanitizedURL, ''
					end
					return false, url, 'Entered URL not valid.'
				end,
			},
			f:push_button {
				title = "Check Connection",
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
local function prefsDialog(f, propertyTable)
	local bind = LrView.bind
	local share = LrView.share

	return {
		title = "Piwigo Publish Service Configuration and Settings",
		bind_to_object = propertyTable,
		f:group_box {
			title = "Publish Service Set Up",
			font = "<system/bold>",
			fill_horizontal = 1,
			f:spacer { height = 2 },
			f:row {
				f:push_button {
					title = 'Import Albums',
					font = "<system>",
					width = share 'buttonwidth',
					enabled = bind('Connected', propertyTable),
					tooltip = "Click to fetch the current album structure from the Piwigo Host above. Only albums the user has permission to see will be included",
					action = function(button)
						local result = LrDialogs.confirm("Import Piwigo Albums",
							"Are you sure you want to import the album structure from Piwigo?\nExisting collections will be unaffected.",
							"Import", "Cancel")
						if result == 'ok' then
							LrTasks.startAsyncTask(function()
								PiwigoAPI.importAlbums(propertyTable)
							end)
						end
					end,
				},
				f:static_text {
					title = "Import existing albums from Piwigo",
					font = "<system>",
					alignment = 'left',
					-- width = share 'labelWidth',
					width_in_chars = 50,
					tooltip = "Click to fetch the current album structure from the Piwigo Host above. Only albums the user has permission to see will be included",
				},
			},



			f:spacer { height = 1 },
			f:row {
				f:push_button {
					title = 'Check and Link Piwigo Structure',
					font = "<system>",
					width = share 'buttonwidth',
					enabled = bind('Connected', propertyTable),
					--enabled = false, -- temporary disabled
					tooltip = "Check Piwigo album structure against local collection / set structure",
					action = function(button)
						local result = LrDialogs.confirm("Check / link Piwigo Structure",
							"Are you sure you want to check / link Piwigo Structure?\nExisting collections will be unaffected.",
							"Check", "Cancel")
						if result == 'ok' then
							LrTasks.startAsyncTask(function()
								PiwigoAPI.validatePiwigoStructure(propertyTable)
							end)
						end
					end,
				},
				f:static_text {
					title = "Piwigo structure will be checked against local collection / set structure. Missing Piwigo albums will be created and links checked / updated",
					font = "<system>",
					alignment = 'left',
					-- width = share 'labelWidth',
					-- width_in_chars = 50,
					tooltip = "Piwigo structure will be checked against local collection / set structure. Missing Piwigo albums will be created and links checked / updated"
				},
			},

			f:spacer { height = 1 },
			f:row {
				f:push_button {
					title = 'Clone Existing Publish Service',
					font = "<system>",
					width = share 'buttonwidth',
					enabled = bind('Connected', propertyTable),
					--enabled = false, -- temporary disabled
					tooltip = "Clone existing publish service (collections/sets and links to Piwigo)",
					action = function(button)
						LrTasks.startAsyncTask(function()
							PWImportService.selectService(propertyTable)
						end)
					end,
				},
				f:static_text {
					title = "Collection/Set structure and images of selected Publish Service will be cloned to this one.",
					font = "<system>",
					alignment = 'left',
					-- width = share 'labelWidth',
					-- width_in_chars = 50,
					tooltip = "Selected Collection/Set structure and images of selected Publish Service will be cloned to this one."
				},
			},

			f:spacer { height = 1 },

			f:row {
				f:push_button {
					title = 'Create Special Collections',
					font = "<system>",
					width = share 'buttonwidth',
					enabled = bind('Connected', propertyTable),
					--enabled = false, -- temporary disabled
					tooltip = "Create special publish collections for publish collection sets, allowing images to be published to Piwigo albums with sub-albums",
					action = function(button)
						local result = LrDialogs.confirm("Create Special Collections",
							"Are you sure you want to create Special Collections?\nExisting collections may be updated and missing Piwigo albums will be created.",
							"Create", "Cancel")
						if result == 'ok' then
							LrTasks.startAsyncTask(function()
								PiwigoAPI.specialCollections(propertyTable)
							end)
						end
					end,
				},
				f:static_text {
					title = "Create special publish collections to allow images to be published to albums with sub-albums on Piwigo",
					alignment = 'left',
					font = "<system>",
					-- width = share 'labelWidth',
					-- width_in_chars = 50,
					tooltip = "Create special collections to allow images to be published to Piwigo albums with sub-albums - which is not natively supported on LrC"
				},
			},
			f:spacer { height = 1 },

		},

		f:group_box {
			title = "Metadata Settings",
			font = "<system/bold>",
			fill_horizontal = 1,

			f:spacer { height = 2 },

			f:row {
				f:static_text {
					title = "Title: ",
					font = "<system>",
					alignment = 'right',
					width_in_chars = 8,
				},
				f:edit_field {
					value = bind 'mdTitle',
					font = "<system>",
					alignment = 'left',
					width_in_chars = 60,
					height_in_lines = 3,
				},
			},

			f:row {
				f:static_text {
					title = "Description: ",
					font = "<system>",
					alignment = 'right',
					width_in_chars = 8,
				},
				f:edit_field {
					value = bind 'mdDescription',
					font = "<system>",
					alignment = 'left',
					width_in_chars = 60,
					height_in_lines = 3,
				},
			},
		},

		f:spacer { height = 2 },

		f:group_box {
			title = "Keyword Settings",
			font = "<system/bold>",
			fill_horizontal = 1,
			f:spacer { height = 2 },
			f:row {
				fill_horizontal = 1,
				f:static_text {
					title = "",
					alignment = 'right',
					width_in_chars = 7,
				},
				f:checkbox {
					font = "<system>",
					title = "Include Full Keyword Hierarchy",
					tooltip = "If checked, all keywords in a keyword hierarchy will be sent to Piwigo",
					value = bind 'KwFullHierarchy',
				}
			},

			f:spacer { height = 2 },

			f:row {
				fill_horizontal = 1,
				f:static_text {
					title = "",
					alignment = 'right',
					width_in_chars = 7,
				},
				f:checkbox {
					font = "<system>",
					title = "Include Keyword Synonyms",
					tooltip = "If checked, keyword synonyms will be sent to Piwigo",
					value = bind 'KwSynonyms',
				}
			},
		},
		f:spacer { height = 2 },
		f:group_box {
			title = "Other Settings",
			font = "<system/bold>",
			fill_horizontal = 1,
			f:spacer { height = 1 },




			f:row {
				fill_horizontal = 1,
				f:static_text {
					title = "",
					alignment = 'right',
					width_in_chars = 7,
				},
				f:checkbox {
					title = "Synchronise Album Descriptions",
					font = "<system>",
					tooltip = "If checked, Album descriptions will be maintainable in Lightroom and sent to Piwigo",
					value = bind 'syncAlbumDescriptions',
				},
			},
			f:spacer { height = 1 },

			f:row {
				fill_horizontal = 1,
				f:static_text {
					title = "",
					alignment = 'right',
					width_in_chars = 7,
				},
				f:checkbox {
					title = "Synchronise comments as part of a Publish Process",
					font = "<system>",
					tooltip = "When checked, comments will be synchronised for all photos in a collection during a publish operation",
					value = bind 'syncCommentsPublish',
				},
			},
			f:row {
				fill_horizontal = 1,
				f:static_text {
					title = "",
					alignment = 'right',
					width_in_chars = 7,
				},
				f:checkbox {
					title = "Only include Published Photos",
					enabled = bind('syncCommentsPublish', propertyTable),
					font = "<system>",
					tooltip = "When checked, only photos being published will have comments synchronised",
					value = bind 'syncCommentsPubOnly',
				},
			},


		},
	}
end
--
-- *************************************************
function PublishDialogSections.sectionsForTopOfDialog(f, propertyTable)
	local conDlg = connectionDialog(f, propertyTable)
	local prefDlg = prefsDialog(f, propertyTable)
	if utils.nilOrEmpty(propertyTable.host) or utils.nilOrEmpty(propertyTable.userName) or utils.nilOrEmpty(propertyTable.userPW) then
		propertyTable.Connected = false
		propertyTable.ConCheck = true
		propertyTable.ConStatus = "Not Connected"
	else

	end

	return { conDlg, prefDlg }
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
