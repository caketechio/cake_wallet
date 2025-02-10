#!/bin/sh

if [ -z "$APP_ANDROID_TYPE" ]; then
	echo "Please set APP_ANDROID_TYPE"
	exit 1
fi

DIR=$(dirname "$0")

case $APP_ANDROID_TYPE in
	"monero.com") $DIR/build_monero_all.sh ;;
	"cakewallet") $DIR/build_monero_all.sh
				  $DIR/build_haven_all.sh
					$DIR/build_mwebd.sh
						$DIR/build_decred.sh ;;
	"haven")      $DIR/build_haven_all.sh ;;
esac
