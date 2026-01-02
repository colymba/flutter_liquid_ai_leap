# LeapSDK Frameworks

This directory contains pre-built XCFrameworks for the Liquid AI LEAP SDK.

## Download Frameworks

Run the download script from the project root:

```bash
./scripts/download_frameworks.sh v0.8.0
```

This will download:
- `LeapSDK.xcframework` (~9.2 MB)
- `LeapModelDownloader.xcframework` (~4.6 MB)

## Automatic Download

Frameworks are automatically downloaded during `pod install` if they don't exist.

## Manual Download

You can also download directly from GitHub releases:
- https://github.com/Liquid4All/leap-ios/releases

## Gitignore

The `.xcframework` files are excluded from git to keep the repository size small.
Users and CI systems will download them automatically.
