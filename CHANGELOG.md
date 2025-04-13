# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [1.0.0+4] - 2024-05-13

### Changed
- Reorganized time selection buttons in two rows for better mobile display

### Fixed
- Improved time selection button text visibility on mobile devices

## [1.0.0+3] - 2024-05-12

### Added
- Symptom intensity tracking (mild, moderate, strong)
- Night time option for symptoms

### Changed
- Existing symptoms default to moderate intensity
- Improved first-time user experience with centered "Create Profile" button
- No default time selection for new symptoms
- Intensity selection required before saving symptoms

### Fixed
- Black screen issue when adding/editing tags from symptoms dialog
- Improved navigation flow between dialogs
- Maintain form state when managing tags
- Reorganized time selection buttons for better responsiveness
- Improved visual feedback for selected time buttons
- Fixed calendar month localization and capitalization
- Added tag deletion protection when tag is in use
- Added date listing when attempting to delete used tags
- Made statistics screen header consistent with main screen
- Removed redundant tag management from statistics screen
- Save button now enables correctly when all required fields are filled, regardless of order
- Calendar now updates immediately after adding new symptoms


## [1.0.0+2]

### Added
- Tag management system with color selection
- Symptom tracking with time of day (morning, afternoon, all day)
- Multi-language support (English, Spanish, Catalan)
- Statistics view with symptom frequency by tag
- Multiple user profiles support
- Calendar view with symptom indicators
- Profile customization with colors and photos

### Fixed
- Tag editing now updates associated symptoms
- UI refresh issues when managing tags
- Proper state management in dialogs

## [1.0.0+1]

### Added
- Initial release
- Basic symptom tracking functionality
- User profile creation 