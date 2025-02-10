#!/bin/sh

. ./config.sh

# Boost combined

BOOST_CXXFLAGS_COMBINED="-arch x86_64 -arch arm64"
BOOST_CFLAGS_COMBINED="-arch x86_64 -arch arm64"
BOOST_LINKFLAGS_COMBINED="-arch x86_64 -arch arm64"

# Boost arm64

BOOST_CXXFLAGS_ARM64="-arch arm64"
BOOST_CFLAGS_ARM64="-arch arm64"
BOOST_LINKFLAGS_ARM64="-arch arm64"

# Boost x86_64

BOOST_CXXFLAGS_X86_64="-arch x86_64"
BOOST_CFLAGS_X86_64="-arch x86_64"
BOOST_LINKFLAGS_X86_64="-arch x86_64"

# Boost B2 arm64

BOOST_B2_CXXFLAGS_ARM_64="-arch arm64"
BOOST_B2_CFLAGS_ARM_64="-arch arm64"
BOOST_B2_LINKFLAGS_ARM_64="-arch arm64"
BOOST_B2_BUILD_DIR_ARM_64=macos-arm64

# Boost B2 x86_64

BOOST_B2_CXXFLAGS_X86_64="-arch x86_64"
BOOST_B2_CFLAGS_X86_64="-arch x86_64"
BOOST_B2_LINKFLAGS_X86_64="-arch x86_64"
BOOST_B2_BUILD_DIR_X86_64=macos-x86_64

build_boost_init_common() {
	echo "
	============================ BOOST ============================
	"

	CXXFLAGS=$1
	CFLAGS=$2
	LINKFLAGS=$3
	BOOST_SRC_DIR=${EXTERNAL_MACOS_SOURCE_DIR}/boost_1_72_0
	BOOST_FILENAME=boost_1_72_0.tar.bz2
	BOOST_VERSION=1.72.0
	BOOST_FILE_PATH=${EXTERNAL_MACOS_SOURCE_DIR}/${BOOST_FILENAME}
	BOOST_SHA256="59c9b274bc451cf91a9ba1dd2c7fdcaf5d60b1b3aa83f2c9fa143417cc660722"

	if [ ! -e "$BOOST_FILE_PATH" ]; then
		curl -L http://downloads.sourceforge.net/project/boost/boost/${BOOST_VERSION}/${BOOST_FILENAME} > $BOOST_FILE_PATH
	fi

	echo $BOOST_SHA256 *$BOOST_FILE_PATH | shasum -a 256 -c - || exit 1

	cd $EXTERNAL_MACOS_SOURCE_DIR
	rm -rf $BOOST_SRC_DIR
	tar -xvf $BOOST_FILE_PATH -C $EXTERNAL_MACOS_SOURCE_DIR
	cd $BOOST_SRC_DIR
	./bootstrap.sh --with-toolset=clang-darwin  cxxflags="${CXXFLAGS}" cflags="${CFLAGS}" linkflags="${LINKFLAGS}"
}

build_boost_init_arm64() {
	CXXFLAGS="-arch arm64"
	CFLAGS="-arch arm64"
	LINKFLAGS="-arch arm64"
	build_boost_init_common "${CXXFLAGS}" "${CFLAGS}" "${LINKFLAGS}"
}

build_boost_init_x86_64() {
	CXXFLAGS="-arch x86_64"
	CFLAGS="-arch x86_64"
	LINKFLAGS="-arch x86_64"
	build_boost_init_common "${CXXFLAGS}" "${CFLAGS}" "${LINKFLAGS}"
}

build_boost_init_universal() {
	CXXFLAGS="-arch x86_64 -arch arm64"
	CFLAGS="-arch x86_64 -arch arm64"
	LINKFLAGS="-arch x86_64 -arch arm64"
	build_boost_init_common "${CXXFLAGS}" "${CFLAGS}" "${LINKFLAGS}"
}

build_boost_compile_common() {
	ARCH=$1
	ABI=$2
	CXXFLAGS=$3
	CFLAGS=$4
	LINKFLAGS=$5
	FLAGS=$6
	BUILD_DIR=$7
	./b2 toolset=clang-darwin target-os=darwin architecture="${ARCH}" cxxflags="${CXXFLAGS}" cflags="${CFLAGS}" linkflags="${LINKFLAGS}" abi="${ABI}" "${FLAGS}" -a \
		--with-chrono \
		--with-date_time \
		--with-filesystem \
		--with-program_options \
		--with-regex \
		--with-serialization \
		--with-system \
		--with-thread \
		--with-locale \
		--build-dir=$BUILD_DIR \
	    --stagedir=${BUILD_DIR}/stage \
	    link=static
}

build_boost_compile_arm64() {
	ARCH="arm"
	ABI="aapcs"
	CXXFLAGS="-arch arm64"
	CFLAGS="-arch arm64"
	LINKFLAGS="-arch arm64"
	FLAGS=""
	BUILD_DIR="macos-arm64"
	build_boost_compile_common "${ARCH}" "${ABI}" "${CXXFLAGS}" "${CFLAGS}" "${LINKFLAGS}" "${FLAGS}" "${BUILD_DIR}"
}

build_boost_compile_x86_64() {
	ARCH="x86"
	ABI="sysv"
	CXXFLAGS="-arch x86_64"
	CFLAGS="-arch x86_64"
	LINKFLAGS="-arch x86_64"
	FLAGS="binary-format=mach-o"
	BUILD_DIR="macos-x86_64"
	build_boost_compile_common "${ARCH}" "${ABI}" "${CXXFLAGS}" "${CFLAGS}" "${LINKFLAGS}" "${FLAGS}" "${BUILD_DIR}"
}

build_boost_compile_universal() {
	ARCHES=(arm x86)
	for ARCH in ${ARCHES[@]}; do
		ABI=""
		CXXFLAGS=""
		CFLAGS=""
		LINKFLAGS=""
		FLAGS=""
		BUILD_DIR=""

		case $ARCH in
			arm)
				ABI="aapcs"
				CXXFLAGS="-arch arm64"
				CFLAGS="-arch arm64"
				LINKFLAGS="-arch arm64"
				FLAGS=""
				BUILD_DIR="macos-arm64";;
			x86)
				ABI="sysv"
				CXXFLAGS="-arch x86_64"
				CFLAGS="-arch x86_64"
				LINKFLAGS="-arch x86_64"
				FLAGS="binary-format=mach-o"
				BUILD_DIR="macos-x86_64"
		esac

		build_boost_compile_common "${ARCH}" "${ABI}" "${CXXFLAGS}" "${CFLAGS}" "${LINKFLAGS}" "${FLAGS}" "${BUILD_DIR}"
	done
}

build_boost_install_common() {
	ARCH=$1
	LIB_DIR=""
	mkdir -p $EXTERNAL_MACOS_LIB_DIR
	mkdir -p $EXTERNAL_MACOS_INCLUDE_DIR

	case $ARCH in
		arm64) LIB_DIR="${BOOST_B2_BUILD_DIR_ARM_64}/stage/lib";;
		x86_64) LIB_DIR="${BOOST_B2_BUILD_DIR_X86_64}/stage/lib";;
		*) LIB_DIR="lib";;
	esac

	cp -r ${LIB_DIR}/*.a ${EXTERNAL_MACOS_LIB_DIR}
	cp -r boost ${EXTERNAL_MACOS_INCLUDE_DIR}
}

build_boost_install_arm64() {
	ARCH="arm64"
	build_boost_install_common $ARCH
}

build_boost_install_x86_64() {
	ARCH="x86_64"
	build_boost_install_common $ARCH
}

build_boost_install_universal() {
	mkdir lib

	for blib in ${BOOST_B2_BUILD_DIR_ARM_64}/stage/lib/*.a; do 
	  lipo -create -arch arm64 $blib -arch x86_64 ${BOOST_B2_BUILD_DIR_X86_64}/stage/lib/$(basename $blib) -output lib/$(basename $blib); 
	done

	cp -r lib/* ${EXTERNAL_MACOS_LIB_DIR}
	cp -r boost ${EXTERNAL_MACOS_INCLUDE_DIR}
}

build_boost_arm64() {
	build_boost_init_arm64
	build_boost_compile_arm64
	build_boost_install_arm64
}

build_boost_x86_64() {
	build_boost_init_x86_64
	build_boost_compile_x86_64
	build_boost_install_x86_64
}

build_boost_universal() {
	build_boost_init_universal
	build_boost_compile_universal
	build_boost_install_universal
}