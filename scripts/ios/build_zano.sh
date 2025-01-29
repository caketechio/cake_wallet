#!/bin/sh

. ./config.sh

ZANO_URL="https://github.com/hyle-team/zano.git"
ZANO_DIR_PATH="${EXTERNAL_IOS_SOURCE_DIR}/zano"
ZANO_VERSION=fde28efdc5d7efe8741dcb0e62ea0aebc805a373


IOS_TOOLCHAIN_DIR_PATH="${EXTERNAL_IOS_SOURCE_DIR}/ios_toolchain"
IOS_TOOLCHAIN_URL="https://github.com/leetal/ios-cmake.git"
IOS_TOOLCHAIN_VERSION=06465b27698424cf4a04a5ca4904d50a3c966c45

export NO_DEFAULT_PATH

BUILD_TYPE=release
PREFIX=${EXTERNAL_IOS_DIR}
DEST_LIB_DIR=${EXTERNAL_IOS_LIB_DIR}/zano
DEST_INCLUDE_DIR=${EXTERNAL_IOS_INCLUDE_DIR}/zano

ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64="${ZANO_DIR_PATH}/build"
ZANO_MOBILE_IOS_INSTALL_FOLDER_ARM64="${ZANO_DIR_PATH}/install"

echo "ZANO_URL: $ZANO_URL"		
echo "IOS_TOOLCHAIN_DIR_PATH: $IOS_TOOLCHAIN_DIR_PATH"		
echo "ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64: $ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64"		
echo "ZANO_MOBILE_IOS_INSTALL_FOLDER_ARM64: $ZANO_MOBILE_IOS_INSTALL_FOLDER_ARM64"		
echo "PREFIX: $PREFIX"		
echo "DEST_LIB_DIR: $DEST_LIB_DIR"		
echo "DEST_INCLUDE_DIR: $DEST_INCLUDE_DIR"		
echo "ZANO_DIR_PATH: $ZANO_DIR_PATH"		

echo "Cloning ios_toolchain from - $IOS_TOOLCHAIN_URL to - $IOS_TOOLCHAIN_DIR_PATH"		
git clone $IOS_TOOLCHAIN_URL $IOS_TOOLCHAIN_DIR_PATH
cd $IOS_TOOLCHAIN_DIR_PATH
git checkout $IOS_TOOLCHAIN_VERSION
git submodule update --init --force
cd ..

echo "Cloning zano from - $ZANO_URL to - $ZANO_DIR_PATH"		
git clone $ZANO_URL $ZANO_DIR_PATH
cd $ZANO_DIR_PATH
git fetch origin
if [ $? -ne 0 ]; then
    echo "Failed to perform command"
    exit 1
fi
git checkout $ZANO_VERSION
if [ $? -ne 0 ]; then
    echo "Failed to perform command"
    exit 1
fi
git submodule update --init --force
if [ $? -ne 0 ]; then
    echo "Failed to perform command"
    exit 1
fi
mkdir -p build
cd ..


export CMAKE_INCLUDE_PATH="${PREFIX}/include"
export CMAKE_LIBRARY_PATH="${PREFIX}/lib"


rm -rf ${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64} > /dev/null
rm -rf ${ZANO_MOBILE_IOS_INSTALL_FOLDER_ARM64} > /dev/null

echo "CMAKE_INCLUDE_PATH: $CMAKE_INCLUDE_PATH"		
echo "CMAKE_LIBRARY_PATH: $CMAKE_LIBRARY_PATH"		
echo "ROOT_DIR: $ROOT_DIR"
	

cmake -DCMAKE_BUILD_TYPE=$BUILD_TYPE \
      -DCMAKE_TOOLCHAIN_FILE="${IOS_TOOLCHAIN_DIR_PATH}/ios.toolchain.cmake" \
      -DPLATFORM=OS64 \
      -S"${ZANO_DIR_PATH}" \
      -B"${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64}" \
      -GXcode \
			-DCAKEWALLET=TRUE \
			-DSKIP_BOOST_FATLIB_LIB=TRUE \
      -DCMAKE_SYSTEM_NAME=iOS \
      -DCMAKE_INSTALL_PREFIX="${ZANO_MOBILE_IOS_INSTALL_FOLDER_ARM64}" \
      -DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO \
			-DCMAKE_CXX_FLAGS="-Wno-enum-constexpr-conversion" \
      -DDISABLE_TOR=TRUE

#      -DCMAKE_OSX_ARCHITECTURES="arm64" 
#      -DCMAKE_IOS_INSTALL_COMBINED=YES 

if [ $? -ne 0 ]; then
    echo "Failed to perform command"
    exit 1
fi

cmake --build "${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64}" --config $BUILD_TYPE  --target install -- -j 4
if [ $? -ne 0 ]; then
    echo "Failed to perform command"
    exit 1
fi

mkdir -p $DEST_LIB_DIR
mkdir -p $DEST_INCLUDE_DIR

cp ${ZANO_MOBILE_IOS_INSTALL_FOLDER_ARM64}/lib/* $DEST_LIB_DIR
cp ${ZANO_DIR_PATH}/src/wallet/plain_wallet_api.h $DEST_INCLUDE_DIR
