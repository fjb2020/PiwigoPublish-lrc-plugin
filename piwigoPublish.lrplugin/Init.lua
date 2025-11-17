--[[

    Init.lua - Global Initialisation

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



---@diagnostic disable: undefined-global

-- Global imports
_G.LrHttp = import 'LrHttp'
_G.LrDate = import 'LrDate'
_G.LrPathUtils = import 'LrPathUtils'
_G.LrFileUtils = import 'LrFileUtils'
_G.LrStringUtils = import 'LrStringUtils'
_G.LrTasks = import 'LrTasks'
_G.LrErrors = import 'LrErrors'
_G.LrDialogs = import 'LrDialogs'
_G.LrView = import 'LrView'
_G.LrBinding = import 'LrBinding'
_G.LrColor = import 'LrColor'
_G.LrFunctionContext = import 'LrFunctionContext'
_G.LrApplication = import 'LrApplication'
_G.LrPrefs = import 'LrPrefs'
_G.LrShell = import 'LrShell'
_G.LrSystemInfo = import 'LrSystemInfo'
_G.LrProgressScope = import 'LrProgressScope'
_G.LrHttp = import 'LrHttp'
_G.LrMD5 = import 'LrMD5'
_G.LrExportSession = import 'LrExportSession'
_G.LrExportSettings = import "LrExportSettings"

-- Global requires
_G.JSON = require "JSON"
_G.utils = require "utils"
-- _G.defs = require "PWDefinitions"
_G.PWUtils = require "PiwigoAPI"
_G.PWSession = require "PWSession"
_G.PiwigoAPI = require "PiwigoAPI"
_G.log = require("logger")

-- Global initializations
_G.prefs = _G.LrPrefs.prefsForPlugin()
_G.debugEnabled = true

_G.iconPath = _PLUGIN:resourceId("icons/piwigoPublish_1_5-assets/piwigoPublish_1_5.png")

