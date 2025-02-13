# Building Cake Wallet for Linux

## Requirements and Setup

As we use Docker with a custom Dockerfile to build Cake Wallet, the only dependency for building Cake on your local host is the Docker Engine.

You can find the latest instructions for installing Docker on your given OS on the official website:

- <https://docs.docker.com/engine/install/>

NOTE: If building on a Mac with an M-series CPU (arm64), you may encounter segmentation faults when building. If you do, simply retry the build.

## Building Cake Wallet or Monero.com

### Using the pre-built builder image

In order to build the latest version of Cake Wallet, simply run the following:

```bash
git clone --branch main https://github.com/cake-tech/cake_wallet.git
# NOTE: Replace `main` with the latest release tag available at https://github.com/cake-tech/cake_wallet/releases/latest.
cd cake_wallet
# docker build -t ghcr.io/cake-tech/cake_wallet:main-linux . # Uncomment to build the docker image yourself instead of pulling it from the registry
docker run -v$(pwd):$(pwd) -w $(pwd) -i --rm ghcr.io/cake-tech/cake_wallet:main-linux bash -x << EOF
set -x -e
pushd scripts
    ./gen_android_manifest.sh
popd
pushd scripts/linux
    source ./app_env.sh cakewallet
    # source ./app_env.sh monero.com # Uncomment this line to build monero.com
    ./app_config.sh
    ./build_monero_all.sh
popd
flutter clean
./model_generator.sh
dart run tool/generate_localization.dart
dart run tool/generate_new_secrets.dart
flutter build linux
EOF
```

You should see the command complete with similar output:

```bash
+ dart run tool/generate_localization.dart
+ dart run tool/generate_new_secrets.dart
+ flutter build linux

Building Linux application...                                   
✓ Built build/linux/x64/release/bundle/cake_wallet
```

Final builds can be found in `build/linux/x64/release/bundle/` as seen above.


## Flatpak (optional)

To package the built binaries as a flatpak, you need first to install `flatpak` and `flatpak-builder`:

```bash
sudo apt install flatpak flatpak-builder
```

Add the necessary Flathub:

```bash
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
```

Then need to install freedesktop runtime and sdk:

```bash
flatpak install flathub org.freedesktop.Platform//22.08 org.freedesktop.Sdk//22.08
```

Next, build the flatpak bundle:

```bash
flatpak-builder --force-clean flatpak-build com.cakewallet.CakeWallet.yml
```

And then export bundle:

```bash
flatpak build-export export flatpak-build
flatpak build-bundle export cake_wallet.flatpak com.cakewallet.CakeWallet
```

The Flatpak file, `cake_wallet.flatpak`, should be generated in the current directory.

To install the newly built Flatpak, run:

```bash
flatpak --user install cake_wallet.flatpak
```
