# flutter_photo_library_example

Demonstrates how to use the `flutter_photo_library` plugin.

## Getting started

After cloning the repo, always resolve Flutter dependencies **before** opening the iOS project or running `pod install`. That regenerates machine-local files such as `ios/Flutter/Generated.xcconfig` (which must never be committed — it contains your local `FLUTTER_ROOT`).

```bash
cd flutter_photo_library/example
flutter pub get
flutter run
```

### iOS only

If you need CocoaPods explicitly:

```bash
cd flutter_photo_library/example
flutter pub get
cd ios
pod install
cd ..
flutter run
```

If `pod install` fails with a path like `C:\flutter_sdk\...` or another machine’s Flutter path, delete the stale generated files and run `flutter pub get` again:

```bash
rm -f ios/Flutter/Generated.xcconfig ios/Flutter/flutter_export_environment.sh
rm -rf ios/Flutter/ephemeral
flutter pub get
cd ios && pod install
```
