# Changelog

## [20251117.5] - 2025-11-17
### Added
- Check image presence on Piwigo during publish operation to prevent 404 error if previously published image is missing
- New versioning system based on date+release number


### Fixed
- Crashes due to concurrent Piwigo activities clashing. Attempting to carry out one of these operations whilst a publish operation active will result in a warning and the reversion of the changes:
    - reparent collection
    - rename collection
    - create Piwigo album
    - create collection set
