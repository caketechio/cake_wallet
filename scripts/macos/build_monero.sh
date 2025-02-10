#!/bin/sh

. ./config.sh

MONERO_URL="https://github.com/cake-tech/monero.git"
MONERO_DIR_PATH="${EXTERNAL_MACOS_SOURCE_DIR}/monero"
MONERO_VERSION=release-v0.18.3.2
BUILD_TYPE=release
PREFIX=${EXTERNAL_MACOS_DIR}
DEST_LIB_DIR=${EXTERNAL_MACOS_LIB_DIR}/monero
DEST_INCLUDE_DIR=${EXTERNAL_MACOS_INCLUDE_DIR}/monero
ARCH=`uname -m`

echo "
============================ MONERO ============================
"

echo "Cloning monero from - $MONERO_URL to - $MONERO_DIR_PATH"		
git clone $MONERO_URL $MONERO_DIR_PATH
cd $MONERO_DIR_PATH
git checkout $MONERO_VERSION
git submodule update --init --force
mkdir -p build
cd ..

mkdir -p $DEST_LIB_DIR
mkdir -p $DEST_INCLUDE_DIR

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ -z $INSTALL_PREFIX ]; then
    INSTALL_PREFIX=${ROOT_DIR}/monero
fi

echo "Building MACOS ${ARCH}"
export CMAKE_INCLUDE_PATH="${PREFIX}/include"
export CMAKE_LIBRARY_PATH="${PREFIX}/lib"
rm -r monero/build > /dev/null

if [ "${ARCH}" == "x86_64" ]; then
	ARCH="x86-64"
fi

mkdir -p monero/build/${BUILD_TYPE}
pushd monero/build/${BUILD_TYPE}
cmake -DARCH=${ARCH} \
	-DBUILD_64=ON \
	-DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
	-DSTATIC=ON \
	-DBUILD_GUI_DEPS=ON \
	-DUNBOUND_INCLUDE_DIR=${EXTERNAL_MACOS_INCLUDE_DIR} \
	-DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX}  \
    -DUSE_DEVICE_TREZOR=OFF \
    -DMANUAL_SUBMODULES=1 \
	../..
make wallet_api -j4
find . -path ./lib -prune -o -name '*.a' -exec cp '{}' lib \;
cp -r ./lib/* $DEST_LIB_DIR
cp ../../src/wallet/api/wallet2_api.h  $DEST_INCLUDE_DIR
popd
