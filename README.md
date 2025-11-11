# PiwigoPublish-lrc-plugin

A Lightroom Classic plugin which uploads images to a Piwigo hosts via the Piwigo API.

Currently at beta 0.9 version, 

## The following fuctionality is available:

* Connect to Piwigo Server and download existing album structure
    * Published Collection Sets and Published Collections are created in the LrC Publish Service corresponding to the albums and sub-albums in Piwigo (see features under development)
* images added to LrC Publish Service are publish to corresponding album on Piwigo
* images removed from LrC Publish Service are removed from correspoinding album on Piwigo
* change album structure
* create album on Piwigo
    * Adding new Published Collections will create a corresponding album on Piwigo
* Multiple Publish Services connecting to different Piwigo hosts.

## The following functionality is under development or planned:

* Set Album Cover
* Add images to a Piwigo album that has sub-albums. The complication is that in LrC, the publish service can have Published Collections - to which images can be added, and Published Collection Sets - to which images can't be added but child Published Collections can. In Piwigo, an album can both contain images and also have sub albums. The approach being worked on will create a published collection that is associated with it's parent published collection set such that images added to this collection will be published in the parent album on Piwigo, not a sub album.
* Support for Piwigo API Keys, due in Piwigo 16.0.0 (currently 16.0.0RC1) - https://piwigo.org/forum/viewtopic.php?id=34376
* Optional
    * hierarchical keywords added to photo on publish (Piwigo host and album)
* Consistency Check - check for images missing on Piwigo and update published status accordingly
* renamePublishedCollection - rename associated Piwigo album
* deletePublishedCollection - delete associated Piwigo album
* Metadata Check



## The following functionality is not currently planned:
* Download images from Piwigo to local drive


## CREDITS

[Jeffrey Friedl for JSON.lua](http://regex.info/blog/lua/json)

[Bastian Machek for giving me ideas on the structure with his Immich Plugin](https://github.com/bmachek/lrc-immich-plugin)