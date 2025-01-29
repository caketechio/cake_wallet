#!/bin/sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/functions.sh"

. ./config.sh
# ./install_missing_headers.sh
# ./build_openssl.sh
# ./build_boost.sh
# ./build_sodium.sh
# ./build_zmq.sh
# ./build_unbound.sh

set -x -e

cd "$(dirname "$0")"

../prepare_moneroc.sh

for COIN in monero wownero zano;
do
    pushd ../monero_c
        rm -rf external/ios/build
        ./build_single.sh ${COIN} aarch64-apple-ios -j$MAKE_JOB_COUNT
    popd
done

unxz -f ../monero_c/release/monero/aarch64-apple-ios_libwallet2_api_c.dylib.xz
unxz -f ../monero_c/release/wownero/aarch64-apple-ios_libwallet2_api_c.dylib.xz
unxz -f ../monero_c/release/zano/aarch64-apple-ios_libwallet2_api_c.dylib.xz
