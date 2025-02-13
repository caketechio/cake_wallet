#!/bin/sh

set -e
cd "$(dirname "$0")"
# . ./config.sh

CW_DECRED_DIR=$(realpath ../..)/cw_decred
LIBWALLET_PATH="${PWD}/decred/libwallet"
LIBWALLET_URL="https://github.com/decred/libwallet.git"
LIBWALLET_VERSION="e02273ad75a029a4f020f11c4575025f4e4eb132"

if [ -e $LIBWALLET_PATH ]; then
       rm -fr $LIBWALLET_PATH/{*,.*} || true
fi
mkdir -p $LIBWALLET_PATH || true

git clone $LIBWALLET_URL $LIBWALLET_PATH
cd $LIBWALLET_PATH
git checkout $LIBWALLET_VERSION

if [[ "x$ANDROID_HOME" == "x" ]];
then
    echo "ANDROID_HOME is missing, please declare it before building (on macos it is usually $HOME/Library/Android/sdk)"
    echo "echo > ~/.zprofile"
    echo "echo 'export ANDROID_HOME=\"\$HOME/Library/Android/sdk\" > ~/.zprofile"
    exit 1
fi

if [[ "x$ANDROID_NDK_VERSION" == "x" ]];
then
    echo "ANDROID_NDK_VERSION is missing, please declare it before building"
    echo "You have these versions installed on your system currently:"
    ls ${ANDROID_HOME}/ndk/ | cat | awk '{ print "- " $1 }'
    echo "echo > ~/.zprofile"
    echo "echo 'export ANDROID_NDK_CERSION=..... > ~/.zprofile"
    exit 1
fi

export NDK_BIN_PATH="${ANDROID_HOME}/ndk/${ANDROID_NDK_VERSION}/toolchains/llvm/prebuilt/$(uname | tr '[:upper:]' '[:lower:]')-x86_64/bin"
export ANDROID_API_VERSION=21
# export CPATH="$(clang -v 2>&1 | grep "Selected GCC installation" | rev | cut -d' ' -f1 | rev)/include"

for arch in "aarch" "aarch64" "x86_64"
do
    TRIPLET=""
    TARGET=""
    ARCH_ABI=""

    case $arch in
        "aarch")
		    TRIPLET="armv7a-linux-androideabi"
            TARGET="arm"
            ARCH_ABI="armeabi-v7a";;
        "aarch64")
		    TRIPLET="aarch64-linux-android"
            TARGET="arm64"
            ARCH_ABI="arm64-v8a";;
        "x86_64")
		    TRIPLET="x86_64-linux-android"
            TARGET="amd64"
            ARCH_ABI="x86_64";;
		*)
			echo "Unknown arch: $arch"
			exit 1;;
    esac

    # PATH="${TOOLCHAIN_BASE_DIR}_${arch}/bin:${ORIGINAL_PATH}"
    if [ -e ./build ]; then
        rm -fr ./build
    fi

	CLANG_PATH="${NDK_BIN_PATH}/${TRIPLET}${ANDROID_API_VERSION}-clang"
    CGO_ENABLED=1 GOOS=android GOARCH=${TARGET} CC=${CLANG_PATH} CXX=${CLANG_PATH}++ \
        go build -v -buildmode=c-shared -o ./build/${TRIPLET}-libdcrwallet.so ./cgo

    DEST_LIB_DIR=${CW_DECRED_DIR}/android/libs/${ARCH_ABI}
    mkdir -p $DEST_LIB_DIR
    cp ${LIBWALLET_PATH}/build/${TRIPLET}-libdcrwallet.so $DEST_LIB_DIR/libdcrwallet.so
done

HEADER_DIR=$CW_DECRED_DIR/lib/api
cp ${LIBWALLET_PATH}/build/${TRIPLET}-libdcrwallet.h $HEADER_DIR/libdcrwallet.h
cd $CW_DECRED_DIR
dart run ffigen
