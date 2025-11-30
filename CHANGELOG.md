# Changelog

## [20251130.7] - 2025-11-30
### Fixed
- Bug when deleting Special Collections removed incorrect album in Piwigo


## [20251129.6] - 2025-11-29
### Added
- Special Collections can be created, allowing Piwigo albums with sub-albums to also have photos published in them

## [20251129.5] - 2025-11-29
### Fixed
- Error on startup when no Piwigo hosts defined

## [20251128.4] - 2025-11-28
### Fixed
- non-unique album names within Piwigo Album hierarchy were not properly created during import albums process. See updated readme for more details on this.

## [20251127.3] - 2025-11-27
### Added
- Checked compatibility with Piwigo v16.0.0 and API Keys
- Missing albums are recreated (with a new Piwigo Cat ID) during Publish process

### Fixed
- Crashes when Piwigo albums are removed from Piwigo directly, leaving the Plugin collections inconsistent. 
- Inconsistent connection messages when multiple publish services using this plugin are created.
- Regression bug causing images to be duplicated rather then refreshed
- Correct behaviour when additional new publish services are created 
- refactored calls to LrHttp.get function

## [20251117.1] - 2025-11-17
### Added
- Check image presence on Piwigo during publish operation to prevent 404 error if previously published image is missing
- New versioning system based on date+release number

### Fixed
- Crashes due to concurrent Piwigo activities clashing. Attempting to carry out one of these operations whilst a publish operation active will result in a warning and the reversion of the changes:
    - reparent collection
    - rename collection
    - create Piwigo album
    - create collection set
