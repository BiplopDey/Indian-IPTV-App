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
```

## Android TV Emulator (CLI)

Install emulator + Android TV system image:

```
sdkmanager --licenses
sdkmanager "platform-tools" "emulator" "system-images;android-33;android-tv;x86"
```

Note: use `android-tv` to avoid Google TV login prompts. Google TV images are
`google-tv` and will ask you to sign in.

Create an AVD:

```
echo no | avdmanager create avd -n tv33 -k "system-images;android-33;android-tv;x86" -d tv_1080p
```

Start the emulator with a window:

```
emulator -avd tv33 -gpu auto
```

Build and install a debug APK (faster for emulator):

```
/home/biplop/flutter/bin/flutter build apk --debug --flavor tv --dart-define=TARGET=tv
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-tv-debug.apk
```

Launch the app:

```
adb -s emulator-5554 shell am start -n com.nk.live_tv.tv/com.nk.live_tv.MainActivity
```

If you have multiple emulators running, use `adb devices` to get the right ID.

Open the app directly (skip launcher):

```
adb -s emulator-5554 shell am start -n com.nk.live_tv.tv/com.nk.live_tv.MainActivity
```

Verify the app is installed:

```
adb -s emulator-5554 shell pm list packages | rg com.nk.live_tv.tv
```

## NVIDIA GPU (Secure Boot / MOK signing)

If the NVIDIA driver fails to load with:
`modprobe: ERROR: could not insert 'nvidia': Key was rejected by service`,
Secure Boot is blocking the module. Use MOK signing:

```
sudo mkdir -p /root/mok
cd /root/mok
sudo openssl req -new -x509 -newkey rsa:2048 -keyout MOK.key -out MOK.crt -nodes -days 36500 -subj "/CN=Local NVIDIA/"
sudo openssl x509 -outform DER -in MOK.crt -out MOK.der
```

Enroll the key (you will set a one‑time password used on reboot):

```
sudo mokutil --import /root/mok/MOK.der
```

Sign NVIDIA modules:

```
sudo /usr/src/linux-headers-$(uname -r)/scripts/sign-file sha256 /root/mok/MOK.key /root/mok/MOK.crt $(modinfo -n nvidia)
sudo /usr/src/linux-headers-$(uname -r)/scripts/sign-file sha256 /root/mok/MOK.key /root/mok/MOK.crt $(modinfo -n nvidia_uvm)
sudo /usr/src/linux-headers-$(uname -r)/scripts/sign-file sha256 /root/mok/MOK.key /root/mok/MOK.crt $(modinfo -n nvidia_drm)
sudo /usr/src/linux-headers-$(uname -r)/scripts/sign-file sha256 /root/mok/MOK.key /root/mok/MOK.crt $(modinfo -n nvidia_modeset)
```

Update initramfs and reboot:

```
sudo update-initramfs -u
sudo reboot
```

On reboot, MOK Manager will appear:
- Enroll MOK → Continue → Yes
- Enter the password you set during `mokutil --import`

After reboot:

```
sudo modprobe nvidia
sudo modprobe nvidia_uvm
nvidia-smi
```

Then run the emulator (host GPU default when NVIDIA is configured; use SwiftShader if not):

```
emulator -avd tv33 -gpu host -memory 4096 -cores 4
```

## TV Emulator Helper Script

`run_tv_emulator.sh` starts the TV emulator, waits for boot, installs the APK,
and launches the app. It also stops any existing emulator using the same AVD
and then detaches (does not block the terminal).

```
./run_tv_emulator.sh
```

Optional arguments (GPU defaults to `host` in the script; use `swiftshader_indirect` if NVIDIA is not configured):

```
./run_tv_emulator.sh <avd_name> <gpu_mode> <memory_mb> <cores> <apk_path>
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

## Recent agent changes

- Introduced hexagonal structure with domain/application/adapters boundaries.
- Added unit tests for playlist parsing, normalization, and catalog merging.

## Change history

All significant changes should be recorded in `HISTORY.md`.
