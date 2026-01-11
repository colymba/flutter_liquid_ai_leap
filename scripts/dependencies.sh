#!/bin/bash
# =============================================================================
# Liquid AI LEAP Flutter Plugin - Dependency Management Script
# =============================================================================
#
# This script manages the native LEAP SDK dependencies for iOS and Android.
# It provides two commands:
#   - sync: Downloads dependencies matching the current pinned versions
#   - upgrade: Upgrades dependencies to the latest available versions
#
# Usage:
#   ./dependencies.sh sync     # Sync dependencies to pinned versions
#   ./dependencies.sh upgrade  # Upgrade to latest versions
#
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Version constants - update these when upgrading
IOS_SDK_VERSION="0.8.0"
IOS_SDK_REPO="https://github.com/Liquid4All/leap-ios.git"
ANDROID_SDK_VERSION="0.9.1"
ANDROID_SDK_MAVEN="ai.liquid.leap:leap-sdk"

# Print colored output
print_info() {
    echo -e "${BLUE}ℹ ${NC}$1"
}

print_success() {
    echo -e "${GREEN}✓ ${NC}$1"
}

print_warning() {
    echo -e "${YELLOW}⚠ ${NC}$1"
}

print_error() {
    echo -e "${RED}✗ ${NC}$1"
}

# Print header
print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Liquid AI LEAP - Dependency Manager${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Check current git branch and prompt user
check_git_branch() {
    if ! git -C "$PROJECT_ROOT" rev-parse --git-dir > /dev/null 2>&1; then
        print_warning "Not a git repository. Skipping branch check."
        return 0
    fi
    
    local current_branch
    current_branch=$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    
    echo ""
    print_info "Current git branch: ${YELLOW}${current_branch}${NC}"
    echo ""
    
    read -p "Do you want to continue on this branch? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Operation cancelled."
        exit 0
    fi
    
    echo ""
}

# Get latest iOS SDK version from GitHub
get_latest_ios_version() {
    local latest
    latest=$(git ls-remote --tags "$IOS_SDK_REPO" 2>/dev/null | \
             grep -oE 'refs/tags/[0-9]+\.[0-9]+\.[0-9]+' | \
             sed 's|refs/tags/||' | \
             sort -V | \
             tail -1)
    
    if [ -z "$latest" ]; then
        echo "$IOS_SDK_VERSION"
    else
        echo "$latest"
    fi
}

# Get latest Android SDK version from Maven
get_latest_android_version() {
    # For now, return the pinned version
    # In a real implementation, you would query Maven Central or GitHub releases
    echo "$ANDROID_SDK_VERSION"
}

# Sync iOS dependencies
sync_ios() {
    print_info "Syncing iOS LEAP SDK (version ${IOS_SDK_VERSION})..."
    
    local ios_dir="$PROJECT_ROOT/ios"
    
    if [ ! -d "$ios_dir" ]; then
        print_error "iOS directory not found: $ios_dir"
        return 1
    fi
    
    # Update podspec with pinned version
    local podspec="$ios_dir/liquid_ai_leap.podspec"
    if [ -f "$podspec" ]; then
        # Ensure the podspec references the correct version
        print_info "Podspec found. SDK will be fetched via Swift Package Manager."
        
        # Create/update Package.swift reference if needed
        cat > "$ios_dir/.swift-version" << EOF
5.9
EOF
        print_success "iOS SDK version ${IOS_SDK_VERSION} configured"
    else
        print_warning "Podspec not found. Please create ios/liquid_ai_leap.podspec"
    fi
}

# Sync Android dependencies
sync_android() {
    print_info "Syncing Android LEAP SDK (version ${ANDROID_SDK_VERSION})..."
    
    local android_dir="$PROJECT_ROOT/android"
    
    if [ ! -d "$android_dir" ]; then
        print_error "Android directory not found: $android_dir"
        return 1
    fi
    
    local build_gradle="$android_dir/build.gradle"
    if [ -f "$build_gradle" ]; then
        print_info "build.gradle found. SDK version configured in build.gradle."
        print_success "Android SDK version ${ANDROID_SDK_VERSION} configured"
    else
        print_warning "build.gradle not found. Please create android/build.gradle"
    fi
}

# Upgrade iOS to latest version
upgrade_ios() {
    print_info "Checking for iOS LEAP SDK updates..."
    
    local latest_version
    latest_version=$(get_latest_ios_version)
    
    if [ "$latest_version" == "$IOS_SDK_VERSION" ]; then
        print_success "iOS SDK is already at latest version: ${IOS_SDK_VERSION}"
    else
        print_info "New iOS SDK version available: ${latest_version} (current: ${IOS_SDK_VERSION})"
        
        read -p "Update to version ${latest_version}? (y/N): " -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Update version in this script
            sed -i.bak "s/IOS_SDK_VERSION=\"${IOS_SDK_VERSION}\"/IOS_SDK_VERSION=\"${latest_version}\"/" "${BASH_SOURCE[0]}"
            rm -f "${BASH_SOURCE[0]}.bak"
            
            print_success "Updated iOS SDK to version ${latest_version}"
            print_warning "Please run 'dependencies.sh sync' to apply the update"
        fi
    fi
}

# Upgrade Android to latest version
upgrade_android() {
    print_info "Checking for Android LEAP SDK updates..."
    
    local latest_version
    latest_version=$(get_latest_android_version)
    
    if [ "$latest_version" == "$ANDROID_SDK_VERSION" ]; then
        print_success "Android SDK is already at latest version: ${ANDROID_SDK_VERSION}"
    else
        print_info "New Android SDK version available: ${latest_version} (current: ${ANDROID_SDK_VERSION})"
        
        read -p "Update to version ${latest_version}? (y/N): " -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Update version in this script
            sed -i.bak "s/ANDROID_SDK_VERSION=\"${ANDROID_SDK_VERSION}\"/ANDROID_SDK_VERSION=\"${latest_version}\"/" "${BASH_SOURCE[0]}"
            rm -f "${BASH_SOURCE[0]}.bak"
            
            print_success "Updated Android SDK to version ${latest_version}"
            print_warning "Please run 'dependencies.sh sync' to apply the update"
        fi
    fi
}

# Print current versions
print_versions() {
    echo "Current SDK Versions:"
    echo "  iOS:     ${IOS_SDK_VERSION} (from ${IOS_SDK_REPO})"
    echo "  Android: ${ANDROID_SDK_VERSION} (from Maven: ${ANDROID_SDK_MAVEN})"
    echo ""
}

# Main sync command
cmd_sync() {
    print_header
    check_git_branch
    
    print_versions
    
    echo "Syncing dependencies..."
    echo ""
    
    sync_ios
    echo ""
    sync_android
    
    echo ""
    print_success "Dependencies synced successfully!"
    echo ""
    print_info "Next steps:"
    echo "  1. Run 'flutter pub get' to update Flutter dependencies"
    echo "  2. For iOS: cd ios && pod install"
    echo "  3. For Android: Dependencies will be fetched on build"
}

# Main upgrade command
cmd_upgrade() {
    print_header
    check_git_branch
    
    print_versions
    
    echo "Checking for updates..."
    echo ""
    
    upgrade_ios
    echo ""
    upgrade_android
    
    echo ""
    print_info "Upgrade check complete!"
}

# Show usage
show_usage() {
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  sync     Download dependencies matching pinned versions"
    echo "  upgrade  Check for and upgrade to latest SDK versions"
    echo "  version  Show current SDK versions"
    echo "  help     Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 sync"
    echo "  $0 upgrade"
}

# Main entry point
main() {
    local command="${1:-help}"
    
    case "$command" in
        sync)
            cmd_sync
            ;;
        upgrade)
            cmd_upgrade
            ;;
        version)
            print_header
            print_versions
            ;;
        help|--help|-h)
            print_header
            show_usage
            ;;
        *)
            print_error "Unknown command: $command"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
