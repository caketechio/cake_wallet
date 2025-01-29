#!/bin/bash
set -x -e
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/functions.sh"

cd "$(dirname "$0")"

if [[ ! "x$(uname)" == "xLinux" ]];
then
    echo "Only Linux hosts can build windows (yes, i know)";
    exit 1
fi

../prepare_moneroc.sh

# export USE_DOCKER="ON"

pushd ../monero_c
    set +e
    command -v sudo && export SUDO=sudo
    set -e
    if [[ ! "x$USE_DOCKER" == "x" ]];
    then
        for COIN in monero wownero;
        do
            $SUDO docker run --platform linux/amd64 -v$HOME/.cache/ccache:/root/.ccache -v$PWD:$PWD -w $PWD --rm -it git.mrcyjanek.net/mrcyjanek/debian:buster bash -c "git config --global --add safe.directory '*'; apt update; apt install -y ccache gcc-mingw-w64-x86-64 g++-mingw-w64-x86-64 gperf libtinfo5; ./build_single.sh ${COIN} x86_64-w64-mingw32 -j$MAKE_JOB_COUNT"
            # $SUDO docker run --platform linux/amd64 -v$HOME/.cache/ccache:/root/.ccache -v$PWD:$PWD -w $PWD --rm -it git.mrcyjanek.net/mrcyjanek/debian:buster bash -c "git config --global --add safe.directory '*'; apt update; apt install -y ccache gcc-mingw-w64-i686 g++-mingw-w64-i686 gperf libtinfo5; ./build_single.sh ${COIN} i686-w64-mingw32 -j$MAKE_JOB_COUNT"
        done
    else
        for COIN in monero wownero;
        do
            $SUDO ./build_single.sh ${COIN} x86_64-w64-mingw32 -j$MAKE_JOB_COUNT
            # $SUDO ./build_single.sh ${COIN} i686-w64-mingw32 -j$MAKE_JOB_COUNT
        done
    fi
popd

$SUDO unxz -f ../monero_c/release/monero/*.dll.xz
$SUDO unxz -f ../monero_c/release/wownero/*.dll.xz
