--[[
   
    Info.lua

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
return {
    LrSdkVersion = 14.3,
    LrSdkMinimumVersion = 6.0,
    LrPluginName = "Piwigo Publisher",
    LrToolkitIdentifier = "fiona.boston.PwigoPublish",

    LrInitPlugin = "Init.lua",

	LrExportServiceProvider = {
		title = "Piwigo Publisher",
		file = "PublishServiceProvider.lua",
	},

    
    LrLibraryMenuItems = {
        -- Menu items for Library -> Plug In Extras -> Piwigo Publisher
        {
            title = "Piwigo Publisher Extra Options",
            file = "PWExtraOptions.lua",
        },
    },
    
	LrPluginInfoProvider = 'PluginInfo.lua',

    VERSION = { major=20251130, minor=7, revision=0 },
}
