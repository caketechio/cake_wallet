#!/bin/sh

. ./config.sh

UNBOUND_VERSION=release-1.16.2
UNBOUND_HASH="cbed768b8ff9bfcf11089a5f1699b7e5707f1ea5"
UNBOUND_URL="https://www.nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VERSION}.tar.gz"
UNBOUND_DIR_PATH="${EXTERNAL_MACOS_SOURCE_DIR}/unbound-1.16.2"

echo "
============================ Unbound ============================
"

rm -rf ${UNBOUND_DIR_PATH}
git clone https://github.com/NLnetLabs/unbound.git -b ${UNBOUND_VERSION} ${UNBOUND_DIR_PATH}
cd $UNBOUND_DIR_PATH
test `git rev-parse HEAD` = ${UNBOUND_HASH} || exit 1

./configure --prefix="${EXTERNAL_MACOS_DIR}" \
			--with-ssl="${EXTERNAL_MACOS_DIR}" \
			--with-libexpat="${EXTERNAL_MACOS_DIR}" \
			--enable-static \
			--disable-shared \
			--disable-flto
make
make install