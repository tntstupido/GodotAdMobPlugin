#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGING_DIR="${ROOT_DIR}/build/release_staging"
OUTPUT_ZIP="${ROOT_DIR}/AdMobPlugin-v1.3.0-addons.zip"

rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}/addons" "${STAGING_DIR}/ios"

cp -R "${ROOT_DIR}/godot/addons/admob_plugin" "${STAGING_DIR}/addons/"
cp -R "${ROOT_DIR}/ios/plugins" "${STAGING_DIR}/ios/"

(
	cd "${STAGING_DIR}"
	zip -qry "${OUTPUT_ZIP}" addons ios
)

echo "Created ${OUTPUT_ZIP}"
