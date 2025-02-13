# Building Cake Wallet for Android

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
pushd scripts/android
    source ./app_env.sh cakewallet
    # source ./app_env.sh monero.com # Uncomment this line to build monero.com
    ./app_config.sh
    ./build_monero_all.sh
    ./build_mwebd.sh --dont-install
popd
pushd android/app
    [[ -f key.jks ]] || keytool -genkey -v -keystore key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias testKey -noprompt -dname "CN=CakeWallet, OU=CakeWallet, O=CakeWallet, L=Florida, S=America, C=USA" -storepass hunter1 -keypass hunter1
popd
flutter clean
./model_generator.sh
dart run tool/generate_android_key_properties.dart keyAlias=testKey storeFile=key.jks storePassword=hunter1 keyPassword=hunter1
dart run tool/generate_localization.dart
dart run tool/generate_new_secrets.dart
flutter build apk --release --split-per-abi
EOF
```

You should see the command complete with similar output:

```bash
Running Gradle task 'assembleRelease'...                          519.1s
✓ Built build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk (56.3MB)
✓ Built build/app/outputs/flutter-apk/app-arm64-v8a-release.apk (55.8MB)
✓ Built build/app/outputs/flutter-apk/app-x86_64-release.apk (56.4MB)
```

Final builds can be found in `build/app/outputs/flutter-apk/` as seen above.

## Signing builds

While properly signing builds is outside of the scope of this guide (very few users want or need to run their own built APKs), to learn more about how to sign APKs you can check out the Zeus team's fantastic guide:

- <https://github.com/ZeusLN/zeus/blob/master/docs/ReproducibleBuilds.md#signing-apks>
