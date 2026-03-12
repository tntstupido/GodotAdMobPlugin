#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="${ROOT_DIR}/src"
BUILD_DIR="${ROOT_DIR}/build"
OUTPUT_DIR="${ROOT_DIR}/../../plugins/admob_plugin"

: "${GODOT_HEADERS_DIR:?Set GODOT_HEADERS_DIR to the local Godot iOS headers directory}"
: "${GOOGLE_MOBILE_ADS_XCFRAMEWORK:?Set GOOGLE_MOBILE_ADS_XCFRAMEWORK to GoogleMobileAds.xcframework}"
: "${USER_MESSAGING_PLATFORM_XCFRAMEWORK:?Set USER_MESSAGING_PLATFORM_XCFRAMEWORK to UserMessagingPlatform.xcframework}"

IOS_SDK_PATH="$(xcrun --sdk iphoneos --show-sdk-path)"
SIM_SDK_PATH="$(xcrun --sdk iphonesimulator --show-sdk-path)"
IOS_FRAMEWORK_SLICE="${GOOGLE_MOBILE_ADS_XCFRAMEWORK}/ios-arm64/GoogleMobileAds.framework"
SIM_FRAMEWORK_SLICE="${GOOGLE_MOBILE_ADS_XCFRAMEWORK}/ios-arm64_x86_64-simulator/GoogleMobileAds.framework"
IOS_UMP_FRAMEWORK_SLICE="${USER_MESSAGING_PLATFORM_XCFRAMEWORK}/ios-arm64/UserMessagingPlatform.framework"
SIM_UMP_FRAMEWORK_SLICE="${USER_MESSAGING_PLATFORM_XCFRAMEWORK}/ios-arm64_x86_64-simulator/UserMessagingPlatform.framework"
COMMON_GODOT_INCLUDES=(
	-I"${GODOT_HEADERS_DIR}"
	-I"${GODOT_HEADERS_DIR}/platform/ios"
	-I"${GODOT_HEADERS_DIR}/drivers/apple_embedded"
)

rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}/iphoneos" "${BUILD_DIR}/iphonesimulator" "${OUTPUT_DIR}"
rm -rf "${OUTPUT_DIR}/AdMobPlugin.debug.xcframework" "${OUTPUT_DIR}/AdMobPlugin.release.xcframework"

build_static_lib() {
	local sdk_path="$1"
	local arch="$2"
	local slice_dir="$3"
	local framework_slice="$4"
	local ump_framework_slice="$5"
	local min_flag="$6"

	xcrun clang++ \
		-std=c++17 \
		-fobjc-arc \
		-fobjc-weak \
		-DDEBUG_ENABLED \
		-arch "${arch}" \
		-isysroot "${sdk_path}" \
		"${min_flag}" \
		"${COMMON_GODOT_INCLUDES[@]}" \
		-F"$(dirname "${framework_slice}")" \
		-F"$(dirname "${ump_framework_slice}")" \
		-framework Foundation \
		-framework UIKit \
		-framework AdSupport \
		-framework AppTrackingTransparency \
		-framework GoogleMobileAds \
		-framework UserMessagingPlatform \
		-c "${SRC_DIR}/admob_plugin.mm" \
		-o "${slice_dir}/admob_plugin.o"

	xcrun clang++ \
		-std=c++17 \
		-fobjc-arc \
		-fobjc-weak \
		-DDEBUG_ENABLED \
		-arch "${arch}" \
		-isysroot "${sdk_path}" \
		"${min_flag}" \
		"${COMMON_GODOT_INCLUDES[@]}" \
		-F"$(dirname "${framework_slice}")" \
		-F"$(dirname "${ump_framework_slice}")" \
		-framework Foundation \
		-framework UIKit \
		-framework AdSupport \
		-framework AppTrackingTransparency \
		-framework GoogleMobileAds \
		-framework UserMessagingPlatform \
		-c "${SRC_DIR}/admob_plugin_bootstrap.mm" \
		-o "${slice_dir}/admob_plugin_bootstrap.o"

	libtool -static \
		-o "${slice_dir}/libAdMobPlugin.a" \
		"${slice_dir}/admob_plugin.o" \
		"${slice_dir}/admob_plugin_bootstrap.o"
}

build_static_lib "${IOS_SDK_PATH}" "arm64" "${BUILD_DIR}/iphoneos" "${IOS_FRAMEWORK_SLICE}" "${IOS_UMP_FRAMEWORK_SLICE}" "-miphoneos-version-min=13.0"
build_static_lib "${SIM_SDK_PATH}" "arm64" "${BUILD_DIR}/iphonesimulator" "${SIM_FRAMEWORK_SLICE}" "${SIM_UMP_FRAMEWORK_SLICE}" "-mios-simulator-version-min=13.0"

xcodebuild -create-xcframework \
	-library "${BUILD_DIR}/iphoneos/libAdMobPlugin.a" \
	-headers "${SRC_DIR}" \
	-library "${BUILD_DIR}/iphonesimulator/libAdMobPlugin.a" \
	-headers "${SRC_DIR}" \
	-output "${OUTPUT_DIR}/AdMobPlugin.debug.xcframework"

cp -R "${OUTPUT_DIR}/AdMobPlugin.debug.xcframework" "${OUTPUT_DIR}/AdMobPlugin.release.xcframework"

echo "Built xcframeworks in ${OUTPUT_DIR}"
