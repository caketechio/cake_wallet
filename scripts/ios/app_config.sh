#!/bin/bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/functions.sh"
set -x -e
MONERO_COM="monero.com"
CAKEWALLET="cakewallet"
HAVEN="haven"
DIR=`pwd`

if [ -z "$APP_IOS_TYPE" ]; then
        echo "Please set APP_IOS_TYPE"
        exit 1
fi
./gen_framework.sh
cd .. # go to scipts
./gen_android_manifest.sh
cd .. # go to root
cp -rf ./ios/Runner/InfoBase.plist ./ios/Runner/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName ${APP_IOS_NAME}" ./ios/Runner/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${APP_IOS_BUNDLE_ID}" ./ios/Runner/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${APP_IOS_VERSION}" ./ios/Runner/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${APP_IOS_BUILD_NUMBER}" ./ios/Runner/Info.plist

/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:1:CFBundleURLName string ${APP_IOS_TYPE}" ./ios/Runner/Info.plist
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:1:CFBundleURLSchemes array" ./ios/Runner/Info.plist
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:1:CFBundleURLSchemes: string ${APP_IOS_TYPE}" ./ios/Runner/Info.plist
universal_sed "s/PRODUCT_BUNDLE_IDENTIFIER = .*;/PRODUCT_BUNDLE_IDENTIFIER = $APP_IOS_BUNDLE_ID;/g" ./ios/Runner.xcodeproj/project.pbxproj

CONFIG_ARGS=""

case $APP_IOS_TYPE in
    $MONERO_COM)
		CONFIG_ARGS="--monero"
		;;

        $CAKEWALLET)
		CONFIG_ARGS="--monero --bitcoin --ethereum --polygon --nano --bitcoinCash --solana --tron --wownero --zano --decred"
		if [ "$CW_WITH_HAVEN" = true ];then
		    CONFIG_ARGS="$CONFIG_ARGS --haven"
		fi
		;;

	$HAVEN)
		CONFIG_ARGS="--haven"
		;;
esac

cp -rf pubspec_description.yaml pubspec.yaml
flutter pub get
dart run tool/generate_pubspec.dart
flutter pub get
dart run tool/configure.dart $CONFIG_ARGS
cd $DIR
$DIR/app_icon.sh
