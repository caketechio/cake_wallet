.PHONY: ios
ios:
	cargo build --target=aarch64-apple-ios
	cp target/aarch64-apple-ios/debug/libldk_ffi.a ios

.PHONY: android
android:
	cargo build --target=aarch64-linux-android
	cargo build --target=armv7-linux-androideabi
	cp target/aarch64-linux-android/debug/libldk_ffi.so android/src/main/jniLibs/arm64-v8a
	cp target/armv7-linux-androideabi/debug/libldk_ffi.so android/src/main/jniLibs/armeabi-v7a

.PHONY: build
build: android ios