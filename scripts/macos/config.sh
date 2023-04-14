#!/bin/sh

export MACOS_SCRIPTS_DIR=`pwd`
export CW_ROOT=${MACOS_SCRIPTS_DIR}/../..
export EXTERNAL_DIR=${CW_ROOT}/cw_shared_external/ios/External
export EXTERNAL_MACOS_DIR=${EXTERNAL_DIR}/macos
export EXTERNAL_MACOS_SOURCE_DIR=${EXTERNAL_MACOS_DIR}/sources
export EXTERNAL_MACOS_LIB_DIR=${EXTERNAL_MACOS_DIR}/lib
export EXTERNAL_MACOS_INCLUDE_DIR=${EXTERNAL_MACOS_DIR}/include

mkdir -p $EXTERNAL_MACOS_LIB_DIR
mkdir -p $EXTERNAL_MACOS_INCLUDE_DIR
mkdir -p $EXTERNAL_MACOS_SOURCE_DIR