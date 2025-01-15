#!/bin/bash

# Usage: env USE_DOCKER= ./build_all.sh 

set -x -e

cd "$(dirname "$0")"

NPROC="-j$(nproc)"

../prepare_moneroc.sh

for COIN in monero wownero;
do
    pushd ../monero_c
        for target in {x86_64,aarch64}-linux-android armv7a-linux-androideabi
        do
            if [[ -f "release/${COIN}/${target}_libwallet2_api_c.so" ]];
            then
                echo "file exist, not building monero_c for ${COIN}/$target.";
            else
                env -i ./build_single.sh ${COIN} $target $NPROC
                unxz -f ../monero_c/release/${COIN}/${target}_libwallet2_api_c.so.xz
            fi
        done
    popd
done