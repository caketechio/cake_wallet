# Building CakeWallet for MacOS

## Requirements and Setup

The following are the system requirements to build CakeWallet for your Mac.

```
MacOS 12.6.3 Monterey. (Other versions untested)
Flutter 3.10.6. (Other versions untested)
```

## Build Steps

These steps will help you configure and execute a build of CakeWallet from its source code.

### 1. Installing Package Dependencies

The following packages must be installed on your build system.
Skip this step if they are already installed.

`$ brew install python autoconf automake libtool doxygen graphviz`

### 2. Acquiring the CakeWallet Source Code

Create the directory that will be use to store the CakeWallet source and download the source code into that directory.

`$ git clone https://github.com/cake-tech/cake_wallet.git --branch main`

Proceed into the source code before proceeding with the next steps:

`$ cd {cake_wallet_repo_directory}`

### 3. Execute Build & Setup Commands for CakeWallet

Execute the `build_macos.sh` script.

`$ ./build_macos.sh`

The `build_macos.sh` script will generate and update relevant project files, including cryptographic salts that the CakeWallet binary will be built with, which are used for secure encryption of your data.

It will also build the Monero libraries and their dependencies.

### 4. Run!

Open the `macos/Runner.xcworkspace` file in Xcode and edit the Team and Bundle Identifier.
Then you can run the app.

`$ flutter run -d macos`

### 5. Troubleshooting

If you experience encryption or data corruption issues, possibly because of overridding previously used secrets with newly generated secrets, delete the app data dir and clear the app's NSDefaults storage. You might need to replace `com.fotolockr.cakewallet` with the bundle ID you set in step 4 above.

`$ rm -rf $HOME/Library/Containers/com.fotolockr.cakewallet/`
`$ defaults delete com.fotolockr.cakewallet`

Copyright (c) 2023 Cake Technologies LLC.
