# Symptom Tracker App

A Flutter application for tracking symptoms and health conditions with customizable tags and statistics visualization.

## Features

- Track daily symptoms with customizable tags
- View statistics and trends over different time periods (week/month/year)
- Multi-language support (English, Spanish, Catalan)
- Data visualization with charts
- User profiles support

## Prerequisites

Before running this application, make sure you have the following installed:

- [Flutter](https://flutter.dev/docs/get-started/install) (2.0.0 or higher)
- [Dart](https://dart.dev/get-dart) (2.12.0 or higher)
- [Android Studio](https://developer.android.com/studio) or [Xcode](https://developer.apple.com/xcode/) (for mobile development)
- [Git](https://git-scm.com/) for version control

## Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/alba-lamas/health-tracker.git
   ```

2. Navigate to the project directory:
   ```bash
   cd health-tracker
   ```

3. Install dependencies:
   ```bash
   flutter pub get
   ```

4. Run the app:
   ```bash
   flutter run
   ```

## Project Structure

The project follows a standard Flutter application structure:

- `lib/`: Contains the main Dart code
  - `main.dart`: Entry point of the application
  - `screens/`: UI screens
    - `user_selection_screen.dart`: User selection screen
    - `symptom_tracking_screen.dart`: Symptom tracking screen
    - `statistics_screen.dart`: Statistics screen
    - `settings_screen.dart`: Settings screen
  - `models/`: Data models
    - `symptom.dart`: Symptom model
    - `tag.dart`: Tag model
  - `utils/`: Utility functions
    - `date_utils.dart`: Date handling utilities
  - `l10n/`: Localization files
    - `app_localizations.dart`: App localization
  - `main_app.dart`: Main application file
  - `theme.dart`: Application theme
  - `app.dart`: Entry point of the application
  - `pubspec.yaml`: Dependency configuration
  - `README.md`: This file

## Localization

The application supports multiple languages:

- English
- Spanish
- Catalan

To add a new language, follow these steps:

1. Create a new JSON file in the `l10n` directory with the language code (e.g., `en.json`, `es.json`, `ca.json`)
2. Add the translations for the new language
3. Update the `pubspec.yaml` file to include the new language
4. Restart the Flutter application to see the new language in action

## Data Storage

The application uses a JSON file to store the data. The data is stored in the `data.json` file.

## Building for Android and iOS

### Android

1. Ensure you have the Android SDK installed and configured
2. Connect an Android device or start an emulator
3. Build the APK:
   ```bash
   flutter build apk
   ```
4. The APK will be created at `build/app/outputs/flutter-apk/app-release.apk`

To install directly to a connected device:
   ```bash
   flutter install
   ```

### iOS

1. Ensure you have Xcode installed and configured   
2. Connect an iOS device or start an iOS simulator
3. Build the IPA:
   ```bash
   flutter build ipa
   ```
4. The IPA will be created at `build/ios/archive/Runner.xcarchive`

To install directly to a connected device:
   ```bash
   flutter install
   ```

## Versioning

This project follows Semantic Versioning (MAJOR.MINOR.PATCH):
- MAJOR version for incompatible API changes
- MINOR version for backwards-compatible functionality additions
- PATCH version for backwards-compatible bug fixes

Current version: 1.0.0

## Contributing

Contributions are welcome! Please feel free to submit a pull request or open an issue.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.



