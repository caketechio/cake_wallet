#!/bin/bash

. ./config.sh

EXPAT_VERSION=R_2_4_8
EXPAT_HASH="3bab6c09bbe8bf42d84b81563ddbcf4cca4be838"
EXPAT_SRC_DIR=${EXTERNAL_MACOS_SOURCE_DIR}/libexpat

echo "
============================ EXPAT ============================
"

git clone https://github.com/libexpat/libexpat.git -b ${EXPAT_VERSION} ${EXPAT_SRC_DIR}
cd $EXPAT_SRC_DIR
test `git rev-parse HEAD` = ${EXPAT_HASH} || exit 1
cd $EXPAT_SRC_DIR/expat

./buildconf.sh
./configure --enable-static --disable-shared --prefix=${EXTERNAL_MACOS_DIR}
make
make install