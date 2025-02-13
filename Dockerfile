# Usage:
# docker build . -f Dockerfile -t ghcr.io/cake-tech/cake_wallet:main-linux
# docker push ghcr.io/cake-tech/cake_wallet:main-linux

# Heavily inspired by cirrusci images
# https://github.com/cirruslabs/docker-images-android/blob/master/sdk/tools/Dockerfile
# https://github.com/cirruslabs/docker-images-android/blob/master/sdk/34/Dockerfile
# https://github.com/cirruslabs/docker-images-android/blob/master/sdk/34-ndk/Dockerfile
# https://github.com/cirruslabs/docker-images-flutter/blob/master/sdk/Dockerfile

FROM --platform=linux/amd64 docker.io/debian:12

LABEL org.opencontainers.image.source=https://github.com/cake-tech/cake_wallet

# Set necessary environment variables
# Set Go version to latest known-working version
ENV GOLANG_VERSION=1.23.4

# Pin Flutter version to latest known-working version
ENV FLUTTER_VERSION=3.24.4

# Pin Android Studio, platform, and build tools versions to latest known-working version
# Comes from https://developer.android.com/studio/#command-tools
ENV ANDROID_SDK_TOOLS_VERSION=11076708
# Comes from https://developer.android.com/studio/releases/build-tools
ENV ANDROID_PLATFORM_VERSION=34
ENV ANDROID_BUILD_TOOLS_VERSION=34.0.0

# If we ever need to migrate the home directory...
RUN sed -i 's|^root:[^:]*:[^:]*:[^:]*:[^:]*:/root:|root:x:0:0:root:/root:|' /etc/passwd
# mkdir -p /root && rm -rf /root && cp -a /root /root
ENV HOME=/root
ENV ANDROID_HOME=/opt/android-sdk-linux \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    LANGUAGE=en_US:en

# Set Android SDK paths
ENV ANDROID_SDK_ROOT=$ANDROID_HOME \
    PATH=${PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/emulator

# Upgrade base image
RUN apt-get update \
    && apt-get upgrade -y

# Install all build dependencies
RUN set -o xtrace \
    && cd /opt \
    && apt-get install -y --no-install-recommends --no-install-suggests \
    # Core dependencies
    bc build-essential curl default-jdk git jq lcov libglu1-mesa libpulse0 libsqlite3-dev libstdc++6 locales openssh-client ruby-bundler ruby-full software-properties-common sudo unzip wget zip \
    # for x86 emulators
    libatk-bridge2.0-0 libgdk-pixbuf2.0-0 libgtk-3-0 libnspr4 libnss3-dev libsqlite3-dev libxtst6 libxss1 lftp sqlite3 xxd \
    # Linux desktop dependencies
    clang cmake libgtk-3-dev ninja-build pkg-config \
    # monero_c dependencies
    autoconf automake build-essential ccache gperf libtool llvm \
    # extra stuff for KVM
    bridge-utils libvirt-clients libvirt-daemon-system qemu-kvm udev \
    # Linux test dependencies
    ffmpeg network-manager x11-utils xvfb psmisc \
    # aarch64-linux-gnu dependencies
    g++-aarch64-linux-gnu gcc-aarch64-linux-gnu \
    && apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && sh -c 'echo "en_US.UTF-8 UTF-8" > /etc/locale.gen' \
    && locale-gen \
    && update-locale LANG=en_US.UTF-8

# Install nodejs for Github Actions
RUN curl -fsSL https://deb.nodesource.com/setup_23.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install Go
ENV PATH=${PATH}:/usr/local/go/bin:${HOME}/go/bin
ENV GOROOT=/usr/local/go
ENV GOPATH=${HOME}/go
RUN wget https://go.dev/dl/go${GOLANG_VERSION}.linux-amd64.tar.gz &&\
    rm -rf /usr/local/go &&\
    tar -C /usr/local -xzf go${GOLANG_VERSION}.linux-amd64.tar.gz && \
    go install golang.org/x/mobile/cmd/gomobile@latest && \
    gomobile init

# Install Android SDK commandline tools and emulator
RUN wget -q https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_SDK_TOOLS_VERSION}_latest.zip -O android-sdk-tools.zip \
    && mkdir -p ${ANDROID_HOME}/cmdline-tools/ \
    && unzip -q android-sdk-tools.zip -d ${ANDROID_HOME}/cmdline-tools/ \
    && mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest \
    && chown -R root:root $ANDROID_HOME \
    && rm android-sdk-tools.zip \
    && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
    && yes | sdkmanager --licenses \
    && wget -O /usr/bin/android-wait-for-emulator https://raw.githubusercontent.com/travis-ci/travis-cookbooks/master/community-cookbooks/android-sdk/files/default/android-wait-for-emulator \
    && chmod +x /usr/bin/android-wait-for-emulator \
    && sdkmanager platform-tools \
    && mkdir -p ${HOME}/.android \
    && touch ${HOME}/.android/repositories.cfg \
    && git config --global user.email "czarek@cakewallet.com" \
    && git config --global user.name "CakeWallet CI"

# Handle emulator not being available on linux/arm64 (https://issuetracker.google.com/issues/227219818)
RUN if [ $(uname -m) == "x86_64" ]; then sdkmanager emulator ; fi

# Pre-install extra Android SDK dependencies in order to not have to download them for each build
RUN yes | sdkmanager \
    "platforms;android-$ANDROID_PLATFORM_VERSION" \
    "build-tools;$ANDROID_BUILD_TOOLS_VERSION" \
    "platforms;android-33" \
    "build-tools;33.0.2" \
    "build-tools;33.0.1" \
    "build-tools;33.0.0" \
    "build-tools;35.0.0"

# Install extra NDK dependency for sp_scanner
ENV ANDROID_NDK_VERSION=27.2.12479018
RUN yes | sdkmanager "ndk;$ANDROID_NDK_VERSION" \
    "ndk;27.0.12077973"

# Install dependencies for tests
# Comes from https://github.com/ReactiveCircus/android-emulator-runner
RUN yes | sdkmanager "system-images;android-29;default;x86" \
    "system-images;android-29;default;x86_64" \
    "system-images;android-31;default;x86_64" \
    "platforms;android-29"

# Fake the KVM status so the Android emulator doesn't complain (that much)
RUN (addgroup kvm || true) && \
    adduser root kvm && \
    mkdir -p /etc/udev/rules.d/ && \
    echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' | tee /etc/udev/rules.d/99-kvm4all.rules

# Install rustup, rust toolchains, and cargo-ndk
ENV PATH=${HOME}/.cargo/bin:${PATH}
RUN curl https://sh.rustup.rs -sSf | bash -s -- -y && \
    cargo install cargo-ndk && \
    for target in aarch64-linux-android armv7-linux-androideabi i686-linux-android x86_64-linux-android x86_64-unknown-linux-gnu; \
    do \
        rustup target add --toolchain stable $target; \
    done

# Download and install Flutter
ENV HOME=${HOME}
ENV FLUTTER_HOME=${HOME}/sdks/flutter/${FLUTTER_VERSION}
ENV FLUTTER_ROOT=$FLUTTER_HOME
ENV PATH=${PATH}:${FLUTTER_HOME}/bin:${FLUTTER_HOME}/bin/cache/dart-sdk/bin

RUN git clone --depth 1 --branch ${FLUTTER_VERSION} https://github.com/flutter/flutter.git ${FLUTTER_HOME} \
    && yes | flutter doctor --android-licenses \
    && flutter doctor \
    && chown -R root:root ${FLUTTER_HOME}

# Download and pre-cache necessary Flutter artifacts to speed up builds
RUN flutter precache
