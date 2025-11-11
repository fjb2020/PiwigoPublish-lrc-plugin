-- Info.lua

return {
    LrSdkVersion = 10.0,
    LrSdkMinimumVersion = 6.0, -- Adjust depending on your Lightroom version
    LrPluginName = "Piwigo Publisher",
    LrToolkitIdentifier = "fiona.boston.PwigoPublish",
    --LrMetadataProvider  = "CustomMetadata.lua",
    --LrMetadataTagsetFactory = 'Tagset.lua',
    LrInitPlugin = "Init.lua",

	LrExportServiceProvider = {
		title = "Piwigo Publisher",
		file = "PublishServiceProvider.lua",
	},

    VERSION = { major=0, minor=9, revision=4 },
}
