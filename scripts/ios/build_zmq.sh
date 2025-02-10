#!/bin/sh

. ./config.sh

ZMQ_PATH="${EXTERNAL_IOS_SOURCE_DIR}/libzmq"
ZMQ_URL="https://github.com/zeromq/libzmq.git"

echo "============================ ZMQ ============================"

echo "Cloning ZMQ from - $ZMQ_URL"
git clone $ZMQ_URL $ZMQ_PATH
cd $ZMQ_PATH
mkdir cmake-build
cd cmake-build
cmake ..
make


cp ${ZMQ_PATH}/include/* $EXTERNAL_IOS_INCLUDE_DIR
cp ${ZMQ_PATH}/cmake-build/lib/libzmq.a $EXTERNAL_IOS_LIB_DIR
