#!/bin/sh
# Assume we are in scripts/ios
IOS_DIR="$(pwd)/../../ios"
DYLIB_NAME="monero_libwallet2_api_c.dylib"
DYLIB_LINK_PATH="${IOS_DIR}/${DYLIB_NAME}"
FRWK_DIR="${IOS_DIR}/MoneroWallet.framework"

if [ ! -f $DYLIB_LINK_PATH ]; then
    echo "Dylib is not found by the link: ${DYLIB_LINK_PATH}"
    exit 0
fi

cd $FRWK_DIR # go to iOS framework dir
lipo -create $DYLIB_LINK_PATH -output MoneroWallet

echo "Generated ${FRWK_DIR}"
# also generate for wownero
IOS_DIR="$(pwd)/../../ios"
DYLIB_NAME="wownero_libwallet2_api_c.dylib"
DYLIB_LINK_PATH="${IOS_DIR}/${DYLIB_NAME}"
FRWK_DIR="${IOS_DIR}/WowneroWallet.framework"

if [ ! -f $DYLIB_LINK_PATH ]; then
    echo "Dylib is not found by the link: ${DYLIB_LINK_PATH}"
    exit 0
fi

cd $FRWK_DIR # go to iOS framework dir
lipo -create $DYLIB_LINK_PATH -output WowneroWallet

echo "Generated ${FRWK_DIR}"

# also generate for zano
IOS_DIR="$(pwd)/../../ios"
DYLIB_NAME="zano_libwallet2_api_c.dylib"
DYLIB_LINK_PATH="${IOS_DIR}/${DYLIB_NAME}"
FRWK_DIR="${IOS_DIR}/ZanoWallet.framework"

if [ ! -f $DYLIB_LINK_PATH ]; then
    echo "Dylib is not found by the link: ${DYLIB_LINK_PATH}"
    exit 0
fi

cd $FRWK_DIR # go to iOS framework dir
lipo -create $DYLIB_LINK_PATH -output ZanoWallet

echo "Generated ${FRWK_DIR}"
