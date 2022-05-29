You need to have installed xcode and brew
- Install packages from brew
  - `brew install autoconf cmake pkg-config`
- Install flutter (skip if you have already install flutter v2.0.4)
  - `git clone https://github.com/flutter/flutter.git -b 2.0.4`
  - `export PATH="$PATH:`pwd`/flutter/bin"`
  - `flutter precache` 
- Download sources
  - `git clone https://github.com/cake-tech/cake_wallet.git --branch ln`
  - `cd cake_wallet`
- Build monero deps
  - `cd scripts/ios/`
  - `source ./app_env.sh cakewallet`
  - `./app_config.sh`
  - `./install_missing_headers.sh`
  - `./build_all.sh`
  - `./setup.sh`
  - `cd ../..`
- Get rid of `The plugin requires your app to be migrated to the Android embedding v2.` issue
  - `cd scripts/android/`
  - `source ./app_env.sh cakewallet`
  - `./app_config.sh`
  - `cd ../..`
- Get flutter dependencies and code generation
  - `flutter pub get`
  - `flutter packages pub run tool/generate_localization.dart`
  - `flutter packages pub run tool/generate_new_secrets.dart`
  - `cd cw_core && flutter pub get && flutter packages pub run build_runner build --delete-conflicting-outputs && cd .. &&  cd cw_monero && flutter pub get && flutter packages pub run build_runner build --delete-conflicting-outputs && cd .. && cd cw_bitcoin && flutter pub get && flutter packages pub run build_runner build --delete-conflicting-outputs  && cd .. && cd cw_haven && flutter pub get; flutter packages pub run build_runner build --delete-conflicting-outputs && cd .. && flutter packages pub run build_runner build --delete-conflicting-outputs`



=== === === === === === === === === === === === === === ===

Here you need to log in to the apple development account (i think Diego’s one), which supports cake wallet bundle id, or log in to your own and change the bundle id to one from your dev list.

=== === === === === === === === === === === === === === ===



Then you can run the app with `flutter run` or `flutter run --release` on your device.
