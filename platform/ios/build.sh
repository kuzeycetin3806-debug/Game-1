#!/usr/bin/env bash
# Builds the iOS notifications GDExtension as static xcframeworks (macOS + Xcode).
# Output: platform/ios/out/{libsehir_notifications,libgodot-cpp}.ios.xcframework
set -euo pipefail
cd "$(dirname "$0")"
GODOT_CPP_REF="${GODOT_CPP_REF:-godot-4.4-stable}"
if [ ! -d godot-cpp ]; then
	git clone --depth 1 --branch "$GODOT_CPP_REF" https://github.com/godotengine/godot-cpp.git godot-cpp
fi
(cd godot-cpp && scons platform=ios arch=arm64 target=template_release -j"$(sysctl -n hw.ncpu)")
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
mkdir -p out build
xcrun clang++ -std=c++17 -arch arm64 -isysroot "$SDK" -miphoneos-version-min=15.0 -fobjc-arc -O2 \
	-DIOS_ENABLED -Igodot-cpp/include -Igodot-cpp/gen/include -Igodot-cpp/gdextension \
	-c src/register_types.mm -o build/register_types.o
xcrun libtool -static -o build/libsehir_notifications.a build/register_types.o
rm -rf out/*.xcframework
xcodebuild -create-xcframework -library build/libsehir_notifications.a -output out/libsehir_notifications.ios.xcframework
GCPP_LIB="$(ls godot-cpp/bin/libgodot-cpp.ios.template_release.arm64*.a | head -1)"
xcodebuild -create-xcframework -library "$GCPP_LIB" -output out/libgodot-cpp.ios.xcframework
echo "built:"; ls out
