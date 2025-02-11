#!/bin/sh
set -e

IOS_DIR="$(pwd)/../../ios"
DYLIB_PATH="$(pwd)/../../scripts/monero_c/release"
TMP_DIR="${IOS_DIR}/tmp"

rm -rf "${IOS_DIR:?}/MoneroWallet.xcframework" "${IOS_DIR:?}/WowneroWallet.xcframework" "${IOS_DIR:?}/ZanoWallet.xcframework"
rm -rf "${IOS_DIR:?}/MoneroWallet.framework" "${IOS_DIR:?}/WowneroWallet.framework" "${IOS_DIR:?}/ZanoWallet.framework"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

write_info_plist() {
    framework_bundle="$1"
    framework_name="$2"
    target="$3"
    plist_path="${framework_bundle}/Info.plist"

    if [[ "x$target" = "xiossimulator" ]]; then
        platform="iPhoneSimulator"
        dtplatformname="iphonesimulator"
        dtsdkname="iphonesimulator17.4"
    else
        platform="iPhoneOS"
        dtplatformname="iphoneos"
        dtsdkname="iphoneos17.4"
    fi

    cat > "$plist_path" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>BuildMachineOSBuild</key>
  <string>23E224</string>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${framework_name}</string>
  <key>CFBundleIdentifier</key>
  <string>com.fotolockr.${framework_name}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${framework_name}</string>
  <key>CFBundlePackageType</key>
  <string>FMWK</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleSignature</key>
  <string>???</string>
  <key>CFBundleSupportedPlatforms</key>
  <array>
    <string>${platform}</string>
  </array>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>DTCompiler</key>
  <string>com.apple.compilers.llvm.clang.1_0</string>
  <key>DTPlatformBuild</key>
  <string>21E210</string>
  <key>DTPlatformName</key>
  <string>${dtplatformname}</string>
  <key>DTPlatformVersion</key>
  <string>17.4</string>
  <key>DTSDKBuild</key>
  <string>21E210</string>
  <key>DTSDKName</key>
  <string>${dtsdkname}</string>
  <key>DTXcode</key>
  <string>1530</string>
  <key>DTXcodeBuild</key>
  <string>15E204a</string>
  <key>MinimumOSVersion</key>
  <string>16.0</string>
  <key>UIDeviceFamily</key>
  <array>
    <integer>1</integer>
    <integer>2</integer>
  </array>
  <key>UIRequiredDeviceCapabilities</key>
  <array>
    <string>arm64</string>
  </array>
</dict>
</plist>
EOF
    plutil -convert binary1 "$plist_path"
}

create_framework() {
    wallet="$1"
    framework_name="$2"
    target="$3"
    out_dir="$4"

    echo "Creating ${framework_name}.framework for target ${target} in ${out_dir}..."

    framework_bundle="${out_dir}/${framework_name}.framework"
    
    rm -rf "$framework_bundle"
    mkdir -p "$framework_bundle"

    input_dylib="${DYLIB_PATH}/${wallet}/aarch64-apple-${target}_libwallet2_api_c.dylib"
    if [[ ! -f "$input_dylib" ]]; then
        echo "Error: Input dylib not found: $input_dylib"
        exit 1
    fi

    lipo -create "$input_dylib" -output "${framework_bundle}/${framework_name}"
    echo "Created binary: ${framework_bundle}/${framework_name}"

    write_info_plist "$framework_bundle" "$framework_name" "$target"
}

create_xcframework() {
    framework_name="$1"
    device_framework="$2"
    simulator_framework="$3"
    xcframework_output="$4"

    echo "Creating ${xcframework_output} by bundling:"
    echo "  Device framework: ${device_framework}"
    echo "  Simulator framework: ${simulator_framework}"

    xcodebuild -create-xcframework \
      -framework "$device_framework" \
      -framework "$simulator_framework" \
      -output "$xcframework_output"

    echo "Created XCFramework: ${xcframework_output}"
}

wallets=("monero" "wownero" "zano")
framework_names=("MoneroWallet" "WowneroWallet" "ZanoWallet")

for i in "${!wallets[@]}"; do
    wallet="${wallets[$i]}"
    framework_name="${framework_names[$i]}"

    device_out="${TMP_DIR}/${framework_name}_device"
    simulator_out="${TMP_DIR}/${framework_name}_simulator"
    rm -rf "$device_out" "$simulator_out"
    mkdir -p "$device_out" "$simulator_out"

    create_framework "$wallet" "$framework_name" "ios" "$device_out"
    create_framework "$wallet" "$framework_name" "iossimulator" "$simulator_out"

    device_framework="${device_out}/${framework_name}.framework"
    simulator_framework="${simulator_out}/${framework_name}.framework"
    xcframework_output="${IOS_DIR}/${framework_name}.xcframework"
    rm -rf "$xcframework_output"

    create_xcframework "$framework_name" "$device_framework" "$simulator_framework" "$xcframework_output"
done

echo "All XCFrameworks created successfully."

rm -rf "$TMP_DIR"
