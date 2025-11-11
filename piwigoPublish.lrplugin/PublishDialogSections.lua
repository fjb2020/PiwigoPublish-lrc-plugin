-- PublishDialogSections.lua
-- Publish Dialog Sections for Piwigo Publisher plugin

PublishDialogSections = {}





-- *************************************************
function PublishDialogSections.startDialog(propertyTable)

  	log:trace('PublishDialogSections.startDialog')

	-- log:trace('propertyTable contents: ' .. utils.serialiseVar(propertyTable))
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
  	log:trace('PublishDialogSections.endDialog - ' .. why)
	-- 

end

-- *************************************************
local function connectionDialog (f, propertyTable, pwInstance)
	local bind = LrView.bind
	local share = LrView.share
	local debug = false
	return {

		title = "Piwigo Host Settings",
		bind_to_object = propertyTable,
		f:row {
			f:static_text {
				title = "Piwigo Host:",
				alignment = 'right',
				width = share 'labelWidth'

			},
			f:edit_field {
				value = bind 'host',
				truncation = 'middle',
				immediate = false,
				fill_horizontal = 1,
				validate = function (v, host)
					local sanitizedURL = pwInstance:sanityCheckAndFixURL(host)
					if sanitizedURL == host then
						return true, host, ''
					elseif not (sanitizedURL == nil) then
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
						if not(PiwigoAPI.login(propertyTable,debug)) then
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

	}
end

-- *************************************************
local function prefsDialog (f, propertyTable)
	local bind = LrView.bind
	local share = LrView.share
	local debug = false

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
		f:row {
			f:static_text {
				title = "Import existing albums from Piwigo",
				alignment = 'left',

			},
			f:push_button {
				title = 'Import Albums',
				enabled = bind('Connected', propertyTable),

				action = function(button)
					local result = LrDialogs.confirm("Import Piwigo Albums","Are you sure you want to import the album structure from Piwigo?\nThis may overwrite or recreate existing collections.","Import","Cancel")
					if result == 'ok' then
						LrTasks.startAsyncTask(function()
							PiwigoAPI.importAlbums(propertyTable, debug)
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

		f:row {
			f:static_text {
				title = "Root Keyword Tag for Published Photos:",
				alignment = 'left',
				width = share 'labelWidth',
			},	
			f:edit_field {
				value = bind 'tagRoot',
				width_in_chars = 30,
				truncation = 'middle',
				immediate = true,
				fill_horizontal = 1,
			},	
		},
	}
end
--
-- *************************************************
function PublishDialogSections.sectionsForTopOfDialog(f, propertyTable )

  	log:trace('PublishDialogSections.sectionsForTopOfDialog')


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
				log:trace('Token is ' .. propertyTable.token)

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

	log:trace('PublishDialogSections.sectionsForBottomOfDialog')
	
	return {}

end