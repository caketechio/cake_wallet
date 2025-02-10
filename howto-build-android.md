# Building Cake Wallet for Android

## Requirements and Setup

The following are the system requirements to build Cake Wallet for your Android device.

```
Ubuntu >= 20.04 
Android SDK 29 or higher (better to have the latest one 33)
Android NDK 17c
Flutter 3.24.4
```

### 1. Installing Package Dependencies

CakeWallet cannot be built without the following packages installed on your system.

- curl

- unzip

- automake

- build-essential

- file

- pkg-config

- git

- python

- libtool

- libtinfo5

- cmake

- openjdk-8-jre-headless

- clang

You may easily install them on your build system with the following command:

`$ sudo apt-get install -y curl unzip automake build-essential file pkg-config git python libtool libtinfo5 cmake openjdk-8-jre-headless clang`

### 2. Installing Android Studio and Android toolchain

You may download and install the latest version of Android Studio [here](https://developer.android.com/studio#downloads). After installing, start Android Studio, and go through the "Setup Wizard." This installs the latest Android SDK, Android SDK Command-line Tools, and Android SDK Build-Tools, which are required by Cake Wallet. **Be sure you are installing SDK version 28 or later when stepping through the wizard**

### 3. Installing Flutter

Install Flutter with version `3.24.4`. For this please check section [Install Flutter manually](https://docs.flutter.dev/get-started/install/linux#install-flutter-manually).

### 4. Installing rustup

Install rustup from the [rustup.rs](https://rustup.rs/) website.

### 5. Verify Installations

Verify that the Android toolchain, Flutter, and Android Studio have been correctly installed on your system with the following command:

`$ flutter doctor`

The output of this command will appear like this, indicating successful installations. If there are problems with your installation, they **must** be corrected before proceeding.
```
Doctor summary (to see all details, run flutter doctor -v):
[✓] Flutter (Channel stable, 3.24.4, on Linux, locale en_US.UTF-8)
[✓] Android toolchain - develop for Android devices (Android SDK version 29 or higher)
[✓] Android Studio (version 4.0 or higher)
```

### 6. Generate a secure keystore for Android

`$ keytool -genkey -v -keystore $HOME/key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias key`

You will be prompted to create two passwords. First you will be prompted for the "store password", followed by a "key password" towards the end of the creation process. **TAKE NOTE OF THESE PASSWORDS!** You will need them in later steps. 

### 7. Acquiring the Cake Wallet Source Code

Create the directory that will be use to store the Cake Wallet source...

```
$ sudo mkdir -p /opt/android
$ sudo chown $USER /opt/android
$ cd /opt/android
```

..and download the source code into that directory.

`$ git clone https://github.com/cake-tech/cake_wallet.git --branch main`

Proceed into the source code before proceeding with the next steps:

`$ cd cake_wallet/scripts/android/`

### 8. Installing Android NDK

`$ ./install_ndk.sh`

### 9. Execute Build & Setup Commands for Cak eWallet

We need to generate project settings like app name, app icon, package name, etc. For this need to setup environment variables and configure project files. 

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

Next, we must generate key properties based on the secure keystore you generated for Android (in step 5). **MODIFY THE FOLLOWING COMMAND** with the "store password" and "key password" you assigned when creating your keystore (in step 5).

`$ dart run tool/generate_android_key_properties.dart keyAlias=key storeFile=$HOME/key.jks storePassword=<store password> keyPassword=<key password>`

**REMINDER:** The *above* command will **not** succeed unless you replaced the `storePassword` and `keyPassword` variables with the correct passwords for your keystore.

Then we need to generate localization files. If this command fails, add `--force` flag and run it again.

`$ dart run tool/generate_localization.dart`

Finally build mobx models for the app:

`$ ./model_generator.sh`

### 10. Build!

`$ flutter build apk --release`

Copyright (c) 2024 Cake Labs LLC
