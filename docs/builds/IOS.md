# Building Cake Wallet for iOS

## Requirements and Setup

The following are the system requirements to build Cake Wallet for your iOS device.

```txt
macOS 15.3.1
Xcode 16.2
Flutter 3.24.4
```

NOTE: Newer versions of macOS and Xcode may also work, but have not been confirmed to work by the Cake team.

### 1. Installing dependencies

For installing dependency tools you can use brew [Install brew](https://brew.sh).

You may easily install them on your build system with the following command:

```zsh
brew install automake ccache cmake cocoapods go libtool pkgconfig xz
sudo softwareupdate --install-rosetta --agree-to-license
```

### 2. Installing Xcode

Download and install the latest version of [Xcode](https://developer.apple.com/xcode/) from macOS App Store.

Run the following to properly initialize Xcode:

```zsh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

To enable iOS build support for Xcode, perform the following:

1. Open Xcode
2. Navigate to settings
3. Open Components tab
4. Click "Get" next to iOS 18.2 (or any other version that is showing up as default)

### 3. Installing Flutter

Install Flutter, specifically version `3.24.4` by following the [official docs](https://docs.flutter.dev/get-started/install/macos/desktop?tab=download).

NOTE: as `3.24.4` is not the latest version, you'll need to download it from <https://docs.flutter.dev/release/archive> instead of the link in the docs above.

### 4. Installing Rust

Install Rust from the [rustup.rs](https://rustup.rs/) website.

```zsh
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

### 5. Verify Flutter and Xcode installation

Verify that Flutter and Xcode have been correctly installed on your system with the following command:

`flutter doctor`

The output of this command should appear like this, indicating successful installations. If there are problems with your installation, they **must** be corrected before proceeding.

```zsh
Doctor summary (to see all details, run flutter doctor -v):
[✓] Flutter (Channel stable, 3.24.4, on macOS 15.x.x)
[✓] Xcode - develop for iOS and macOS (Xcode 16.2)
```

### 6. Acquiring the Cake Wallet source code

Download the latest release tag of Cake Wallet and enter the source code directory:

```zsh
git clone https://github.com/cake-tech/cake_wallet.git --branch main
cd cake_wallet/scripts/ios/
```

NOTE: Replace `main` with the latest release tag available at <https://github.com/cake-tech/cake_wallet/releases/latest>.

### 7. Setup and build Cake Wallet from source

We need to generate project settings like app name, app icon, package name, etc, including what specific variant of the app we want to build.

To build Cake Wallet from source, run the following:

```zsh
source ./app_env.sh cakewallet
```

For Monero.com, instead do:

```zsh
source ./app_env.sh monero.com
```

Build the necessary libraries and their dependencies:

```zsh
./build_monero_all.sh
./build_mwebd.sh
```

NOTE: This step will take quite a while, so be sure you grab a cup of coffee or a good book!

Then run the configuration script to setup app name, app icon, etc:

```zsh
./app_config.sh
```

### 8. Prepare Flutter

Change back to the root directory of the Cake Wallet source code and install Flutter package dependencies:

```zsh
cd ../../
flutter pub get
```

Generate secrets as placeholders for official API keys etc. along with localization files and mobx models:

```zsh
dart run tool/generate_new_secrets.dart
dart run tool/generate_localization.dart
./model_generator.sh
```

### 9. Build

```zsh
flutter build ios --release --no-codesign
```

Then you can open `ios/Runner.xcworkspace` with Xcode to archive the application.

If you want to run on a connected device, simply run:

```zsh
flutter run
```
