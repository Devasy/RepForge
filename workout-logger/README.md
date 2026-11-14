# RepForge

The Flutter application for RepForge, an offline-first workout logger with analytics, Health Connect integration, and optional AI coaching.

See the [project README](../README.md) for features, screenshots, store downloads, and contribution guidelines. Release history is in the [changelog](../CHANGELOG.md).

## Development

Use Flutter **3.50.0 stable** with its bundled Dart **3.14.0** SDK. Run these commands from this directory:

```sh
flutter pub get
flutter run
flutter analyze
flutter test
```

Build Android release APKs with `flutter build apk --release --split-per-abi`, or a Google Play bundle with `flutter build appbundle --release`. Production signing requires your own signing configuration.

The app version and SDK pin are defined in [pubspec.yaml](pubspec.yaml).

Licensed under [Apache 2.0](../LICENSE).
