# Agent Run Guide

This project is a Flutter app. Use the steps below to run it locally.

## Web

Run a local web server:

```
/home/biplop/flutter/bin/flutter run -d web-server --web-port=8000 --web-hostname=0.0.0.0
```

Open in browser:

```
http://localhost:8000
```

## Android (mobile or TV)

Set Android SDK environment:

```
export ANDROID_SDK_ROOT=/home/biplop/Android/Sdk
export ANDROID_HOME=/home/biplop/Android/Sdk
export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/emulator:$PATH"
```

Run on a device (USB or network ADB):

```
/home/biplop/flutter/bin/flutter devices
/home/biplop/flutter/bin/flutter run -d <device-id> --flavor mobile
```

Build APKs:

```
/home/biplop/flutter/bin/flutter build apk --release --dart-define=TARGET=mobile
/home/biplop/flutter/bin/flutter build apk --release --dart-define=TARGET=tv

With flavors enabled, add the flavor flag:

```
/home/biplop/flutter/bin/flutter build apk --release --flavor mobile --dart-define=TARGET=mobile
/home/biplop/flutter/bin/flutter build apk --release --flavor tv --dart-define=TARGET=tv
```

## Architecture (Hexagonal)

This project follows a hexagonal (ports & adapters) structure:

```
lib/domain/
  entities/           # Pure domain models (no Flutter imports)
  services/           # Pure domain logic (parsing, normalization, etc.)
  ports/              # Interfaces for external I/O
lib/application/
  channel_catalog_service.dart  # Use cases / orchestration
lib/adapters/
  outbound/           # Implement ports (HTTP, assets, shared prefs)
lib/provider/
  channels_provider.dart        # UI adapter (depends on application)
lib/screens/                     # Flutter UI
```

Rules of thumb:
- **Domain** must stay pure Dart (no Flutter, no I/O).
- **Application** depends on domain + ports only.
- **Adapters** implement ports and can depend on Flutter/HTTP/SharedPreferences.
- UI uses **ChannelsProvider**, which wires adapters into the application service.

Adding new functionality:
1) Define/extend a port in `lib/domain/ports/`.
2) Implement it in `lib/adapters/outbound/`.
3) Inject it into `ChannelCatalogService` (application).
4) Use it from `ChannelsProvider` or other UI adapters.
5) Add unit tests with **fake ports** (no network/FS).

Testing expectations:
- Domain + application logic should be unit-tested with fakes.
- Integration tests may use real HTTP, but keep unit tests offline.
- All new code must be covered by tests and follow SOLID principles.

## Pre-finish commands

Run before marking a task complete:

```
/home/biplop/flutter/bin/flutter pub get
dart format .
dart analyze
/home/biplop/flutter/bin/flutter test
```

## Build APK (debug)

```
/home/biplop/flutter/bin/flutter build apk --debug --flavor mobile --dart-define=TARGET=mobile
/home/biplop/flutter/bin/flutter build apk --debug --flavor tv --dart-define=TARGET=tv
```

Before generating an APK:
- bump the version in `pubspec.yaml`
- copy the generated APK into the `artifacts/` folder

## Commit message format

All commits must include a title and body. Use the body to elaborate the change.

## Change history

All significant changes should be recorded in `HISTORY.md`.
