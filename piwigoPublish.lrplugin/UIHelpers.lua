--[[

	UIHelpers.lua

	UI Helper Functions for Piwigo Publisher plugin

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

UIHelpers = {}

-- *************************************************
-- Create plugin header with icon and version information
-- Returns a row containing icon + plugin name + version
-- *************************************************
function UIHelpers.createPluginHeader(f, share, iconPath, pluginVersion)
	local INDENT_PIXELS = 14
	
	return f:row {
		f:picture {
			alignment = 'left',
			value = iconPath,
		},
		f:column {
			spacing = f:control_spacing(),
			f:spacer { height = 1 },
			f:row {
				f:spacer { width = INDENT_PIXELS },
				f:static_text {
					title = "Piwigo Publisher Plugin",
					font = "<system/bold>",
					alignment = 'left',
					width = share 'labelWidth',
				},
			},
			f:row {
				f:spacer { width = INDENT_PIXELS },
				f:static_text {
					title = "Plugin Version",
					alignment = 'left',
				},
				f:static_text {
					title = pluginVersion,
					alignment = 'left',
					width = share 'labelWidth',
				},
			},
		},
	}
end

return UIHelpers