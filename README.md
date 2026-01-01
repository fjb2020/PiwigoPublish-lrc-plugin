# PiwigoPublish-lrc-plugin

A Lightroom Classic plugin which publishes images to a Piwigo host via the Piwigo REST API.

## The following fuctionality is available:

* Connect to Piwigo Server and download existing album structure
    * Published Collection Sets and Published Collections are created in the LrC Publish Service corresponding to the albums and sub-albums in Piwigo (see features under development).
    * Images are not downloaded from Piwigo as part of this, nor are existing images in LrC automatically added to the newly created Published Collections.
* Images added to the Publish Service are published to the corresponding album on Piwigo. Metadata and keywords are transferred, respecting rules configured in the Publishing Manager for this service.
* Special collections can be created which allow images to be published to Piwigo albums that also have sub-albums. See details in the notes on the relationship between Piwigo Albums and LrC Publish Services below.
* The plugin allows a Publish Collection to be converted to a Publish Collection Set - a Special Collection is created for the new Publish Collection Set and any photos that were in the converted Publish Collection will be in this Special Collection. This enables sub albums to be created under an album that was initially created for photos only.
* Set Piwigo album cover from an image in the Published Collection
* Metadata and keywords are exported directly to Piwigo regardless of exif/iptc settings - as part of the publish process along with the photo, or separately via a menu on the Library -> Plug-in Extras menu - which sends the metadata without re-sending the photo.
  * the following fields are set : 
    * author from Lrc Creator,
    * date_creation from LrC Date Time Original
    * name (title) - default from LrC Title,
    * comment (description) - default from LrC Caption,
    * tokenised strings may be used instead for image name (title) and comment (description) - tokens idenfified by {{token}} will be substituted for image specific values on export. All metadata documented in photo:getFormattedMetadata (see https://archive.stecman.co.nz/files/docs/lightroom-sdk/API-Reference/modules/LrPhoto.html#photo:getFormattedMetadata) and photo:getRawMetadata (see https://archive.stecman.co.nz/files/docs/lightroom-sdk/API-Reference/modules/LrPhoto.html#photo:getRawMetadata) from the Lightroom Classic SDK are supported - for example: title, caption, headline, altTextAccessibility, extDescrAccessibility, copyName are supported.
  * Keywords are handled as follows: 
    * The Include on Export attribute set on individual keywords is respected.
    * Flags for Include Full Keyword Hierarchy and Include Keyword Synonyms can be set in the LrC Publishing Manager (the equivalent flags set in the LrC Keyword Tag editor are not visible to plugins so can't be used)
    * New keywords are created if not present in the Piwigo keywords list
    * Tag comparison between LrC and Piwigo is not case sensitive - so for example 'This Is A Keyword' and 'this is a keyword' are treated as the same when sending keywords to Piwigo.
  * GPS location data is only sent via exif so users of the OpenStreetMap plugin need to ensure that location info is included in the Metadata settings on the LrC Publishing Manager
* The plugin maintains a custom metadata set, Piwigo Publisher Metadata, with details of the most recent publishing activity for an image. NOTE - only images published using release 20251224.16 or later of this plugin will have this metadata.
* Changes to images which trigger a re-publish will overwrite the previously published Piwigo image.
* Images removed from the Publish Service are removed from corresponding album on Piwigo
* Moving a Published Collection under a different Published Collection Set is reflected in the associated Piwigo albums
* Adding new Published Collections will create a corresponding album on Piwigo, respecting the album structure
* When a Published Collection name is changed in LrC the associated Piwigo album is also renamed
* When Published Collection is deleted in LrC the associated Piwigo album is also deleted. Photos in the Piwigo album are also deleted if they would become orphans, but if they are associated with other albums they will be left.
* Multiple Publish Services connecting to different Piwigo hosts can be created.
* Deleting a Publish Service does not delete any images or albums on the Piwigo host it was associated with.
* Import Smart Collection Settings supported
* Consistency Check - Option to check local collection / set structure against existing Piwigo album structure - missing Piwigo albums will be created and incorrect links between collections / sets will be updated. This option means an existing collection structure could be copied using tools such as jb Collection Tools in to the Piwigo Publisher publish service and then be updated to create a consistent working structure within the Piwigo Publisher publish service. Whilst tools such as jb Collection Tools may populate the collections with images, the images are not linked to those that may already be in the Piwigo albums and will need to be published again, likely duplicating the existing Piwigo images unless they are deleted from Piwigo prior to running the publish.

## The following functionality is under development:

* Metadata customisation - select which LrC metedata fields are used for Piwigo photo Title and Description fields.
* Per album custom settings - allowing image sizes and other settings to be set at album level, overriding the global Publish Manager settings
* Localisation for different languages

## The following functionality is planned:

* Support for the X-PIWIGO-API header instead of Authorization when sending API keys - v16.1 and above
* Import collection/set/image structure from another publish service
    * if remoteIds / URLs are present these will be copied. Useful to copy another publish service where a Piwigo host is the target without having to clear the existing Piwigo albums prior to re-publishing.
* Metadata Check - check metadata on Piwigo matches Lrc (Title, Caption, GPS, Creator)

## The following functionality is not currently planned:
* Download images from Piwigo to local drive

## Notes on the relationship between Piwigo Albums and LrC Publish Services
The plugin provides a function to import an existing Piwigo album structure into LrC. It works with the following constraints:
- If a Piwigo album contains sub-albums, an equivalent Publish Collection Set is created in the LrC Publish Service.
- If a Piwigo album contains only photographs (i.e. no sub-albums) or is empty then a Publish Collection is created in the LrC Publish Service.
- Piwigo allows an album to contain both photographs and sub albums. LrC does not allow this - a Publish Collection Set can contain only further Publish Collection Sets, or Publish Collections, not both. Publish Collections can contain only photographs and not further Publish Collection Sets. 
  - The workround for this constraint is the the creation of specical collections (an option in the Piwigo Publish Service Configuration Extras section of the Publishing Manager). This creates a 'Special Collection', named "[Photos in *CollectionSetName* ]" for each collection set, linked to the parent album in Piwigo. Any photos in these collections are published to the Piwigo parent album. 
- Piwigo allows albums with the same name to exist under the same parent. LrC does not allow this - albums with the same name can only exist if they are sub albums of different parents within the publish service.
- The plugin allows the alteration of the Piwigo album structure:
  - New albums containing photographs can be created - right-click in Publish Service -> Create Piwigo Album... or Create Piwigo Album (Smart collection)...
  - New albums containing sub-albums can created - right-click in Publish Service -> Create Piwigo Album (Set for sub-albums)... 
  - Albums may be re-parented by click-dragging them to a new parent
  - Albums may be re-named - right-click -> Rename...
  - Albums may be deleted - right-click -> Delete...
  - All these changes are reflected in the corresponding Piwigo Albums - the Piwigo Album ID (Cat ID) is stored against the corresponding LrC Publish Collection / Set to maintain this relationship
- Piwigo has no knowledge of the LrC structure (or constraints), so if changes are made to the Piwigo album structure directly in Piwigo these changes are not reflected in LrC.
- The Import Albums routine can be re-run at any time. It will attempt to add albums added to Piwigo since the last run, noting the constraints above. 
  - If a sub-album has been added to an album that had no sub-albums at the time of first run then an error will be shown and the album won't be created.
  - If an album with a duplicate name has been created under the same parent it will be ignored.
  - It does not remove collections that no longer have corresponding Piwigo albums.
- The Create Special Collections routine can be re-run at any time. Existing special collections will be unchanged but any collection sets created since the last run will have special collections created.

## Installation and Configuration
* Install the plugin via the Lightroom Plugin Manager: 
    * File -> Plug-in Manager -> Add -> locate piwigoPublish.lrplugin
* Create a publish service:
    * Publish Services -> + -> Go to Publishing Manager -> Add -> Via Service: Piwigo Publisher -> Name: -> Create
* Complete the Piwigo Host Settings fields: Piwigo Host, User Name, Password and click 'Check Connection'
    * If details are correct you will see a message 'Connected to Piwigo Gallery at yourhostname as role - Piwigo Version nn.nn.nn' at the bottom of the Piwigo Host Settings box. NOTE - the webmaster role is needed to create/move albums on Piwigo.
    * macOS - If you are unable to connect to a Piwigo server running on your local network you should check that Adobe Lightroom Classic has Local Network Access enabled - Settings -> Privacy & Security -> Local Network
* Click SAVE at the bottom right of this screen. You will return to the Publish Service panel with this service now in the list.
* Right-Click on the service and then Edit Settings...
    * You can now click 'Import Albums' in the Piwigo Publish Service Configuration Extras panel to import the existing album structure from Piwigo
    * NOTE an error will occur if the SAVE process is not completed before the Import Albums option is run

## Imagick Graphics Library
The plugin was initially developed against a Piwigo instance using the GD image library. Switching to imagick revealed an issue in that imagick was unable to process as particlarly big image I was using during testing (it was a hugh panorama at approx 24000x4000 pixels, and no resizing was active in the Publishing Manager). With imagick active, and Admin->Configuration->Options->Photo Sizes->Resize after upload checked, the upload process crashed - fixing the crash revealed an error "piwigo External ImageMagick Corrupt imagearray ()". If the Resize after upload was unchecked the error didn't appear but the image was corrupt and not viewable in Piwigo even though a successful upload was reported back to the plugin.

Enabling Resize to Fit in the LrC Publish Manger (I set resize to max of 4k x 4k) stopped this error appearing. 

I am investigating whether there is something else causing this but I suspect some imagick memory limits were being exceed by the huge image.

If you see similar errors please check image sizes prior to raising an issue.

## Logging

Windows logs are UTF-16 and need to be opened with UTF-16 encoding

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

This plugin has been developed on an macOS platform with Apple silicon. 

The development/test environment is:
- Lightroom Classic 15.0.1 release
    - Apple macOS Tahoe 26.1 
- Lightroom Classic 14.1 release 
    - Windows 11 Pro via Parallels on Apple ARM-based processor         
- Piwigo 15.7.0 on Ubuntu 22.04.5 LTS
- Piwigo 16.0.0 on Ubuntu 22.04.5 LTS
- Piwigo 16.1.0 on Ubuntu 22.04.5 LTS

The plugin has now been tested with Piwigo 16.0.0, including the use of API keys. When using an API key, login credentials are as follows: instead of your username, enter the API key ID (starting with “pkid-…”), and instead of your password, enter the secret of the API key.

If others want to try it pending a more official plugin being avaiable again I suggest the following approach:

1. Backup Lrc Catalog and Piwigo gallery
2. Install and enable this plugin.
3. Add a publish service and connect it to your Piwigo host in the Lightroom Publishing Manager
4. Save the new publish service
5. Once a connection is established, the Import Albums button will activate. Click this button to import the album struction from Piwigo. You will see Collection Sets and Collections in the Publish Service corresponding to your albums in Piwigo.
6. If you have Piwigo albums that contain both photos and sub-albums you should also run the Create Special Collections option (see above Notes on the relationship between Piwigo Albums and LrC Publish Services for details)
7. Alternatively, if you have access to a plugin that lets you copy / paste from other publish services, such as jb Collection Tools, then you may use this to establish collection sets and collections in the new publish sevice and then run the option Check / Link Piwigo Structure on the Lightroom Publishing Manager screen. This links the publish service to Piwigo
6. You can then populate these collections and publish to the Piwigo host. 
7. If you already have a different Piwigo Publish service you can copy photos from those publish service collections to this one. Clicking the Publish button will send these photos to the correspoding Piwigo album, but be aware that it will create duplicate photos if a copy is already in the Piwigo album outside of this plugin, so you may wish to clear the album prior to running the export from LrC.