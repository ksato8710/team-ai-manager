#!/bin/bash
set -e

APP_NAME="TeamAIManager"
APP_DIR=".build/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

# Build
swift build

# Create .app bundle
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"

# Copy executable
cp ".build/debug/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"

# Copy Info.plist
cp Info.plist "${CONTENTS_DIR}/Info.plist"

echo "Built: ${APP_DIR}"
echo "Run:   open ${APP_DIR}"
