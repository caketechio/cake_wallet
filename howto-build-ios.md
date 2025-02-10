# Building Cake Wallet for iOS

## Requirements and Setup

The following are the system requirements to build Cake Wallet for your iOS device.

```
macOS >= 14.0 
Xcode 15.3
Flutter 3.24.4
```

### 1. Installing Package Dependencies

Cake Wallet cannot be built without the following packages installed on your build system.

For installing dependency tools you can use brew [Install brew](https://brew.sh).

You may easily install them on your build system with the following command:

`$ brew install cmake xz cocoapods`

### 2. Installing Xcode

You may download and install the latest version of [Xcode](https://developer.apple.com/xcode/) from macOS App Store. 

### 3. Installing Flutter

Need to install flutter with version `3.24.4`. For this please check section [Install Flutter](https://docs.flutter.dev/get-started/install/macos/mobile-ios?tab=download).

### 4. Installing rustup

Install rustup from the [rustup.rs](https://rustup.rs/) website.

### 5. Verify Installations

Verify that the Flutter and Xcode have been correctly installed on your system with the following command:

`$ flutter doctor`

The output of this command will appear like this, indicating successful installations. If there are problems with your installation, they **must** be corrected before proceeding.
```
Doctor summary (to see all details, run flutter doctor -v):
[✓] Flutter (Channel stable, 3.24.4, on macOS 14.x.x)
[✓] Xcode - develop for iOS and macOS (Xcode 15.3)
```

### 6. Acquiring the CakeWallet source code

Download the source code.

`$ git clone https://github.com/cake-tech/cake_wallet.git --branch main`

Proceed into the source code before proceeding with the next steps:

`$ cd cake_wallet/scripts/ios/`

### 7. Execute Build & Setup Commands for Cake Wallet

We need to generate project settings like app name, app icon, package name, etc. For this, we need to setup environment variables and configure project files. 

Please pick what app you want to build: cakewallet or monero.com.

`$ source ./app_env.sh <cakewallet OR monero.com>`
(it should be like `$ source ./app_env.sh cakewallet` or `$ source ./app_env.sh monero.com`)

Then run configuration script for setup app name, app icon and etc:

`$ ./app_config.sh`

Build the required libraries and their dependencies:

`$ ./build_all.sh`

It is now time to change back to the base directory of the Cake Wallet source code:

`$ cd ../../`

Install Flutter package dependencies with this command:

`$ flutter pub get`

Your Cake Wallet binary will be built with cryptographic salts, which are used for secure encryption of your data. You may generate these secret salts with the following command:

`$ dart run tool/generate_new_secrets.dart`

If the command above fails, add `--force` flag and run it again.

Then we need to generate localization files. If this command fails, add `--force` flag and run it again.

`$ flutter packages pub run tool/generate_localization.dart`

Finally build mobx models for the app:

`$ ./model_generator.sh`

### 8. Build!

`$ flutter build ios --release`

Then you can open `ios/Runner.xcworkspace` with Xcode and you can archive the application.

Or if you want to run to connected device:

`$ flutter run --release`

Copyright (c) 2024 Cake Labs LLC
