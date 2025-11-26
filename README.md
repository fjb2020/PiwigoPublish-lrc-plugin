# PiwigoPublish-lrc-plugin

A Lightroom Classic plugin which uploads images to a Piwigo host via the Piwigo REST API.

Current Version: 20251124.1

## The following fuctionality is available:

* Connect to Piwigo Server and download existing album structure
    * Published Collection Sets and Published Collections are created in the LrC Publish Service corresponding to the albums and sub-albums in Piwigo (see features under development).
    * Images are not downloaded from Piwigo as part of this, nor are existing images in LrC automatically added to the newly created Published Collections.
* Images added to the Publish Service are published to the corresponding album on Piwigo. Metadata and keywords are transferred, respecting rules configured in the Publishing Manager for this service.
* Changes to images which trigger a re-publish will overwrite the previously published Piwigo image.
* Images removed from the Publish Service are removed from corresponding album on Piwigo
* Moving a Published Collection under a different Published Collection Set is reflected in the associated Piwigo albums
* Adding new Published Collections will create a corresponding album on Piwigo, respecting the album structure
* When a Published Collection name is changed in LrC the associated Piwigo album is also renamed
* When Published Collection is deleted in LrCD the associated Piwigo album is also deleted. Photos in the Piwigo album are also deleted if they would become orphans, but if they are associated with other albums they will be left.
* Multiple Publish Services connecting to different Piwigo hosts can be created.
* Deleting a Publish Service does not delete any images or albums on the Piwigo host it was associated with.

## The following functionality is under development:

* Set Piwigo album cover from an image in the Published Collection
* Add images to a Piwigo album that also has sub-albums. 
    * The complication is that in LrC, the publish service can have Published Collections - to which images can be added, and Published Collection Sets - to which images can't be added but child Published Collections can. In Piwigo, an album can both contain images and also have sub albums. The approach being worked on will create a published collection that is associated with it's parent published collection set such that images added to this collection will be published in the parent album on Piwigo, not a sub album.
* Consistency Check - check for images missing on Piwigo and update published status accordingly
* Metadata Check - check metadata on Piwigo matches Lrc (Title, Caption, GPS, Creator)

## The following functionality is planned:
* Import collection/set/image structure from another publish service
    * if remoteIds / URLs are present these will be copied. Useful to copy another publish service where a Piwigo host is the target without having to clear the existing Piwigo albums prior to re-publishing.
* Keyword Rules - customisation of how LrC keywords are exported to Piwigo
* Localisation

## The following functionality is not currently planned:
* Download images from Piwigo to local drive

## Installation and Configuration
* Install the plugin via the Lightroom Plugin Manager: 
    * File -> Plug-in Manager -> Add -> locate piwigoPublish.lrplugin
* Create a publish service:
    * Publish Services -> + -> Go to Publishing Manager -> Add -> Via Service: Piwigo Publisher -> Name: -> Create
* Complete the Piwigo Host Settings fields: Piwigo Host, User Name, Password and click 'Check Connection'
    * If details are correct you will see a message 'Connected to Piwigo Gallery at yourhostname as role' at the bottom of the Piwigo Host Settings box. NOTE - the webmaster role is needed to create/move albums on Piwigo
* Click SAVE at the bottom right of this screen. You will return to the Publish Service panel with this service now in the list.
* Right-Click on the service and then Edit Settings...
    * You can now click 'Import Albums' in the Piwigo Publish Service Configuration Extras panel to import the existing album structure from Piwigo
    * NOTE an error will occur if the SAVE process is not completed before the Import Albums option is run


## CREDITS

As a user of both Lightroom Classic and Piwigo, the ability use the powerful Publishing Service in LrC to keep my Piwigo galleries up to date is very appealing. I've been a long time user of a popular plugin that has been providing this functionality, but unfortunately since the version 15 release of LrC that has not been available. 

This plugin is my attempt to allow me to continue publishing to Piwigo from LrC, and I have looked at the work of others for help and ideas in developing this plugin. In particular, the following should be credited:

[All the contributers to Piwigo](https://piwigo.org/)

[Jeffrey Friedl for JSON.lua](http://regex.info/blog/lua/json)

[Bastian Machek with his Immich Plugin](https://github.com/bmachek/lrc-immich-plugin)

[Min Idzelis with his Immich Plugin](https://github.com/midzelis/mi.Immich.Publisher)


## Disclaimer

With the exception of JSON.lua, Copyright 2010-2017 Jeffrey Friedl, which is released under a Creative Commons CC-BY "Attribution" License: http://creativecommons.org/licenses/by/3.0/deed.en_US, this software is released under the GNU General Public License version 3 as published by the Free Software Foundation.
         
This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program.  If not, see <https://www.gnu.org/licenses/>.

## Development and Testing

This plugin has been developed on an macOS platform with Apple silicon. I don't have a windows platform capable of running Lightroom Classic available so no testing at all has been carried out on a windows platform.

The development environment is:
- Apple macOS Tahoe 26.1
- Lightroom Classic 15.0.1 release
- Piwigo 15.7.0 on Ubuntu 22.04.5 LTS
- Piwigo 16.0.0 on Ubuntu 22.04.5 LTS

The plugin has now been tested with Piwigo 16.0.0, including the use of API keys. When using an API key, login credentials are as follows: instead of your username, enter the API key ID (starting with “pkid-…”), and instead of your password, enter the secret of the API key.

The released version is currently at beta 0.9.4. As a beta release the code is still full of debugging messages as I've grappled with the complexities of accessing the Piwigo web service API via the LrHttp namespace with all it's idiosyncrasies. These will be tidied up, and a more consistent pattern for the various LrHttp calls is planned.

However, in the meantime this plugin does what I need and hasn't corrupted either my Lightroom catalog or my Piwigo installation. If others want to try it pending a more official plugin being avaiable again I suggest the following approach:

1. Backup Lrc Catalog and Piwigo gallery
2. Install and enable this plugin.
3. Add a publish service and connect it to your Piwigo host in the Lightroom Publishing Manager
4. Once a connection is established, the Import Albums button will activate. Click this button to import the album struction from Piwigo. An important note is that this plugin does not yet support Piwigo albums having both photos in them, and sub albums (see planned functionality above). You will see Collection Sets and Collections in the Publish Service corresponding to your albums in Piwigo.
5. You can then populate these collections and publish to the Piwigo host. 
6. If you already have a different Piwigo Publish service you can copy photos from those publish service collections to this one. Clicking the Publish button will send these photos to the correspoding Piwigo album, but be aware that it will create duplicate photos if a copy is already in the Piwigo album outside of this plugin, so you may wish to clear the album prior to running the export from LrC.
