# Changelog

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
