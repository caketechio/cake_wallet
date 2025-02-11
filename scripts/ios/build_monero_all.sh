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
        for platform in aarch64-apple-ios{,simulator};
        do
            if [[ -f "release/${COIN}/${platform}_libwallet2_api_c.dylib" ]];
            then
                echo "file exist, not building monero_c for ${COIN}/${platform}";
            else
                ./build_single.sh ${COIN} ${platform} -j$MAKE_JOB_COUNT
            fi
        done
    popd
done

unxz -fk ../monero_c/release/monero/aarch64-apple-ios_libwallet2_api_c.dylib.xz
unxz -fk ../monero_c/release/wownero/aarch64-apple-ios_libwallet2_api_c.dylib.xz
unxz -fk ../monero_c/release/zano/aarch64-apple-ios_libwallet2_api_c.dylib.xz

unxz -fk ../monero_c/release/monero/aarch64-apple-iossimulator_libwallet2_api_c.dylib.xz
unxz -fk ../monero_c/release/wownero/aarch64-apple-iossimulator_libwallet2_api_c.dylib.xz
unxz -fk ../monero_c/release/zano/aarch64-apple-iossimulator_libwallet2_api_c.dylib.xz
