#!/bin/sh

. ./config.sh

SODIUM_PATH="${EXTERNAL_MACOS_SOURCE_DIR}/libsodium"
SODIUM_URL="https://github.com/jedisct1/libsodium.git"

echo "
============================ SODIUM ============================
"

echo "Cloning SODIUM from - $SODIUM_URL"
git clone $SODIUM_URL $SODIUM_PATH --branch stable
cd $SODIUM_PATH
./dist-build/macos.sh

mv ${SODIUM_PATH}/libsodium-osx/include/* $EXTERNAL_MACOS_INCLUDE_DIR
mv ${SODIUM_PATH}/libsodium-osx/lib/* $EXTERNAL_MACOS_LIB_DIR