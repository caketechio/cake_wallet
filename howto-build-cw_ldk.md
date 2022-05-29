# Build CW_LDK #

This document is for showing you how to set up your environment, so that you can compile the plugin cw_ldk.

The cw_ldk plugin uses the [LDK](https://lightningdevkit.org/) for communicating on the Lightning Network.  The [LDK](https://lightningdevkit.org/) is written in Rust.  In order to use this plugin you must have a Rust environment set up to compile the LDK code into a library that the flutter ffi can communicate with.

We consulted the following links to get the idea on how to set up a Rust and Flutter to work together  through the ffi.

[^1.] [Building and Deploying a Rust library on iOS](https://mozilla.github.io/firefox-browser-architecture/experiments/2017-09-06-rust-on-ios.html)

[^2.] [Building and Deploying a Rust library on Android](https://mozilla.github.io/firefox-browser-architecture/experiments/2017-09-21-rust-on-android.html)

[^3.] [Dart Meets Rust: a match made in heaven](https://dev.to/sunshine-chain/dart-meets-rust-a-match-made-in-heaven-9f5)

[^4.] [Dart and Rust: the async story](https://dev.to/sunshine-chain/rust-and-dart-the-async-story-3adk)

## Requirements and setup

In order to compile the LDK you need to have Rust and the correct version of the Android NDK setup and configured.

The following are the system requirements for your machine.

```
Machine for building LDK
rustc 1.58.1 or above
ndk v18.1.5063045 or below
make 
cmake
```


### 1. Install Rust.

In order to compile the [LDK](https://lightningdevkit.org/) you need to have Rust installed.

Open the following link [rustup](https://rustup.rs/).  

You should find instructions to run the following command.
```
$ curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

You should now have Rust installed.  
Run the following command to check.
```
$ rustc --version
```

### 2. Add compiling targets to Rust.

In order to compile Rust code for iOS and Android you need to add the following compiling targets
to your rust environment.

Run the following commands.
```
rustup target add aarch64-apple-ios
rustup target add aarch64-linux-android
rustup target add armv7-linux-androideabi
```

Run the following command to see if targets were successfully setup.
```
$ rustup show
```


### 3. Get Android NDK 18.1.5023045.

In order for Rust to compile for Android it needs to work with the NDK.

[^1]: I was only able to get it work with version 18.1.5023045
      There might be a way to use the latest NDK with [cargo-apk](https://crates.io/crates/cargo-apk)
      but I didn't have time to look into it some more.

Open Android Studio > SDK Manager > SDK TOOLS > Check "Show Package Details" > Select "NDK 18.1.5023045"

setup the following environment variable in you .bashrc or .zshrc.
```
export ANDROID_HOME="path/to/Android/sdk"
export NDK_HOME="$ANDROID_HOME/ndk/18.1.5063045"
```


### 3. Setup toolchains for compiling for Android ARM and ARM64

Then you need to create toolchains from the ndk for rust to use to compile for arm and arm64 android devices.

create a folder in your home directory .ndk
```
$ mkdir ~/.ndk
```

now create the toolchains
```
${NDK_HOME}/build/tools/make_standalone_toolchain.py --api 26 --arch arm64 --install-dir ~/.ndk/arm64
${NDK_HOME}/build/tools/make_standalone_toolchain.py --api 26 --arch arm --install-dir ~/.ndk/arm
```

you should see the following folders in ~/.ndk
```
$ ls ~/.ndk
arm    arm64
```

Set the toolchains in the PATH environment variable.
Open .zshrc or .bashrc and add the following line.
```
export PATH=/path/to/.ndk/arm/bin:/path/to/.ndk/arm64/bin:$PATH
```

### 4.  Configure Rust to use the toolchains that was just created.

Rust will use the toolchains that were just created to compile rust code for Android.
You must tell rust where to find those toolchains.

find folder .cargo
```
cd ~/.cargo
```

create a file named 'config'
```
touch config
```

inside the file setup your targets to use the toolchains you just created.
```
[target.aarch64-linux-android]
ar = ".ndk/arm64/bin/aarch64-linux-android-ar"
linker = ".ndk/arm64/bin/aarch64-linux-android-clang"

[target.armv7-linux-androideabi]
ar = ".ndk/arm/bin/arm-linux-androideabi-ar"
linker = ".ndk/arm/bin/arm-linux-androideabi-clang"
```

Rust should now be able to use the toolchains you just created.

### 5.  Compile cw_ldk

Now you are ready to compile the cw_ldk.

cd inside cw_ldk and run the make file inside it.
```
$ cd cw_ldk
$ make build
```

the rust code should be compiled and packaged as libraries that the plugin can reference through ffi.

Just add this plugin to your project and you should now be good to go.  