#!/bin/sh

ARCH=`uname -m`

. ./config.sh

case $ARCH in
	arm64)
		./build_openssl_arm64.sh
		./build_boost_arm64.sh;;
	x86_64)
		./build_openssl_x86_64.sh
		./build_boost_x86_64.sh;;
esac

./build_sodium.sh
./build_zmq.sh
./build_expat.sh
./build_unbound.sh
./build_monero.sh