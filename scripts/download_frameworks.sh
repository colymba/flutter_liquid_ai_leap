#!/bin/bash
#
# Downloads pre-built LeapSDK XCFrameworks from GitHub releases
# Usage: ./download_frameworks.sh [version]
# Example: ./download_frameworks.sh v0.8.0

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
FRAMEWORKS_DIR="$SCRIPT_DIR/../ios/Frameworks"
VERSION="${1:-v0.9.2}"  # Default to v0.9.2 if no version specified
REPO_URL="https://github.com/Liquid4All/leap-ios"

echo "📦 Downloading LeapSDK $VERSION..."
echo "Repository: $REPO_URL"
echo "Frameworks directory: $FRAMEWORKS_DIR"
echo ""

# Create frameworks directory if it doesn't exist
mkdir -p "$FRAMEWORKS_DIR"

# Clean existing frameworks
echo "🧹 Cleaning existing frameworks..."
rm -rf "$FRAMEWORKS_DIR/LeapSDK.xcframework"
rm -rf "$FRAMEWORKS_DIR/LeapModelDownloader.xcframework"

# Download LeapSDK.xcframework
echo "⬇️  Downloading LeapSDK.xcframework.zip..."
curl -L -o "/tmp/LeapSDK.xcframework.zip" \
  "$REPO_URL/releases/download/$VERSION/LeapSDK.xcframework.zip"

# Download LeapModelDownloader.xcframework
echo "⬇️  Downloading LeapModelDownloader.xcframework.zip..."
curl -L -o "/tmp/LeapModelDownloader.xcframework.zip" \
  "$REPO_URL/releases/download/$VERSION/LeapModelDownloader.xcframework.zip"

# Extract frameworks
echo "📂 Extracting frameworks..."
unzip -q "/tmp/LeapSDK.xcframework.zip" -d "$FRAMEWORKS_DIR"
unzip -q "/tmp/LeapModelDownloader.xcframework.zip" -d "$FRAMEWORKS_DIR"

# Clean up zip files
rm "/tmp/LeapSDK.xcframework.zip"
rm "/tmp/LeapModelDownloader.xcframework.zip"

# Verify frameworks
if [ -d "$FRAMEWORKS_DIR/LeapSDK.xcframework" ] && [ -d "$FRAMEWORKS_DIR/LeapModelDownloader.xcframework" ]; then
  echo "✅ Frameworks downloaded successfully!"
  echo ""
  echo "📋 Framework details:"
  echo "  - LeapSDK.xcframework"
  du -sh "$FRAMEWORKS_DIR/LeapSDK.xcframework"
  echo "  - LeapModelDownloader.xcframework"
  du -sh "$FRAMEWORKS_DIR/LeapModelDownloader.xcframework"
else
  echo "❌ Error: Frameworks not found after extraction"
  exit 1
fi

echo ""
echo "🎉 Done! Run 'flutter clean && flutter pub get' to use the updated frameworks."
