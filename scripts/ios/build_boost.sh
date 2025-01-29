#!/bin/bash

set -e

. ./config.sh

MIN_IOS_VERSION=10.0
BOOST_URL="https://github.com/cake-tech/Apple-Boost-BuildScript.git"
BOOST_DIR_PATH="${EXTERNAL_IOS_SOURCE_DIR}/Apple-Boost-BuildScript"
BOOST_VERSION=1.84.0
BOOST_LIBS="random regex graph random chrono thread filesystem system date_time locale serialization program_options"

echo "============================ Boost ============================"

echo "Cloning Apple-Boost-BuildScript from - $BOOST_URL"

# Check if the directory already exists.
if [ -d "$BOOST_DIR_PATH" ]; then
    echo "Boost directory already exists."
else
    echo "Cloning Boost from $BOOST_URL"
    git clone -b build $BOOST_URL $BOOST_DIR_PATH
fi

# Verify if the repository was cloned successfully.
if [ -d "$BOOST_DIR_PATH/.git" ]; then
    echo "Boost repository cloned successfully."
	cd $BOOST_DIR_PATH
    git checkout build
else
    echo "Failed to clone Boost repository. Exiting."
    exit 1
fi

./boost.sh -ios \
	--min-ios-version ${MIN_IOS_VERSION} \
	--boost-libs "${BOOST_LIBS}" \
	--boost-version ${BOOST_VERSION} \
	--no-framework

mv -f ${BOOST_DIR_PATH}/build/boost/${BOOST_VERSION}/ios/release/prefix/include/*  $EXTERNAL_IOS_INCLUDE_DIR
mv -f ${BOOST_DIR_PATH}/build/boost/${BOOST_VERSION}/ios/release/prefix/lib/*  $EXTERNAL_IOS_LIB_DIR