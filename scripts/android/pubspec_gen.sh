#!/bin/bash

MONERO_COM=monero.com
CAKEWALLET=cakewallet
HAVEN=haven
CONFIG_ARGS=""

case $APP_ANDROID_TYPE in
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

cd ../..
cp -rf pubspec_description.yaml pubspec.yaml
flutter pub get
dart run tool/generate_pubspec.dart
flutter pub get
dart run tool/configure.dart $CONFIG_ARGS
cd scripts/android
