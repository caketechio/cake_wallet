#!/bin/bash

WORKDIR=/opt/android
CW_DIR=${WORKDIR}/cake_wallet
CW_EXRTERNAL_DIR=${CW_DIR}/cw_shared_external/ios/External/android
CW_HAVEN_EXTERNAL_DIR=${CW_DIR}/cw_haven/ios/External/android
CW_MONERO_EXTERNAL_DIR=${CW_DIR}/cw_monero/ios/External/android
CW_ZANO_EXTERNAL_DIR=${CW_DIR}/cw_zano/ios/External/android
for arch in "aarch" "aarch64" "i686" "x86_64"
do

PREFIX=${WORKDIR}/prefix_${arch}
ABI=""

case $arch in
	"aarch"	)
		ABI="armeabi-v7a";;
	"aarch64"	)
		ABI="arm64-v8a";;
	"i686"		)
		ABI="x86";;
	"x86_64"	)
		ABI="x86_64";;
esac

LIB_DIR=${CW_EXRTERNAL_DIR}/${ABI}/lib
INCLUDE_DIR=${CW_EXRTERNAL_DIR}/${ABI}/include
LIBANBOUND_PATH=${PREFIX}/lib/libunbound.a

mkdir -p $LIB_DIR
mkdir -p $INCLUDE_DIR

cp -r ${PREFIX}/lib/* $LIB_DIR
cp -r ${PREFIX}/include/* $INCLUDE_DIR

if [ -f "$LIBANBOUND_PATH" ]; then
 cp $LIBANBOUND_PATH ${LIB_DIR}/monero
fi

done

mkdir -p ${CW_HAVEN_EXTERNAL_DIR}/include
mkdir -p ${CW_MONERO_EXTERNAL_DIR}/include
mkdir -p ${CW_ZANO_EXTERNAL_DIR}/include

cp $CW_EXRTERNAL_DIR/x86/include/haven/wallet2_api.h ${CW_HAVEN_EXTERNAL_DIR}/include
