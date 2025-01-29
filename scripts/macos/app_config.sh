#!/bin/bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/functions.sh"

MONERO_COM="monero.com"
CAKEWALLET="cakewallet"
DIR=`pwd`

if [ -z "$APP_MACOS_TYPE" ]; then
        echo "Please set APP_MACOS_TYPE"
        exit 1
fi

cd .. # go to scipts
./gen_android_manifest.sh
cd .. # go to root
cp -rf ./macos/Runner/InfoBase.plist ./macos/Runner/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName ${APP_MACOS_NAME}" ./macos/Runner/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleName ${APP_MACOS_NAME}" ./macos/Runner/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${APP_MACOS_BUNDLE_ID}" ./macos/Runner/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${APP_MACOS_VERSION}" ./macos/Runner/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${APP_MACOS_BUILD_NUMBER}" ./macos/Runner/Info.plist

# Fill entitlements Bundle ID
cp -rf ./macos/Runner/DebugProfileBase.entitlements ./macos/Runner/DebugProfile.entitlements
cp -rf ./macos/Runner/ReleaseBase.entitlements ./macos/Runner/Release.entitlements
cp -rf ./macos/Runner/RunnerBase.entitlements ./macos/Runner/Runner.entitlements
cp -rf ./macos/Runner/Configs/AppInfoBase.xcconfig ./macos/Runner/Configs/AppInfo.xcconfig
universal_sed "s/\${BUNDLE_ID}/${APP_MACOS_BUNDLE_ID}/g" ./macos/Runner/DebugProfile.entitlements
universal_sed "s/\${BUNDLE_ID}/${APP_MACOS_BUNDLE_ID}/g" ./macos/Runner/Release.entitlements
universal_sed "s/\${BUNDLE_ID}/${APP_MACOS_BUNDLE_ID}/g" ./macos/Runner/Runner.entitlements
universal_sed "s/\${PRODUCT_NAME}/${APP_MACOS_NAME}/g" ./macos/Runner/Configs/AppInfo.xcconfig
universal_sed "s/PRODUCT_BUNDLE_IDENTIFIER = .*;/PRODUCT_BUNDLE_IDENTIFIER = $APP_MACOS_BUNDLE_ID;/g" ./macos/Runner/Configs/AppInfo.xcconfig
CONFIG_ARGS=""

case $APP_MACOS_TYPE in
        $MONERO_COM)
		CONFIG_ARGS="--monero";;
        $CAKEWALLET)
		CONFIG_ARGS="--monero --bitcoin --ethereum --polygon --nano --bitcoinCash --solana --tron --wownero";; #--haven
esac

cp -rf pubspec_description.yaml pubspec.yaml
flutter pub get
dart run tool/generate_pubspec.dart
flutter pub get
dart run tool/configure.dart $CONFIG_ARGS
cd $DIR
$DIR/app_icon.sh
