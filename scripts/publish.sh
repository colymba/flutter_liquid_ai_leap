#!/bin/bash
# =============================================================================
# Liquid AI LEAP Flutter Plugin - Publishing Script
# =============================================================================
#
# This script automates the release workflow for the Flutter plugin:
#   1. Sync dependencies
#   2. Run Flutter package health checks
#   3. Checkout/create release branch
#   4. Bump version (fix/minor/major)
#   5. Update CHANGELOG.md
#   6. Create git tag
#   7. Commit and push
#   8. Run pub.dev dry-run
#   9. Publish to pub.dev
#
# Usage:
#   ./publish.sh fix     # Bump patch version (0.1.0 -> 0.1.1)
#   ./publish.sh minor   # Bump minor version (0.1.0 -> 0.2.0)
#   ./publish.sh major   # Bump major version (0.1.0 -> 1.0.0)
#
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

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

print_step() {
    echo ""
    echo -e "${CYAN}━━━ Step $1: $2 ━━━${NC}"
    echo ""
}

# Print header
print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Liquid AI LEAP - Publishing Workflow${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Check current git branch and prompt user
check_git_branch() {
    if ! git -C "$PROJECT_ROOT" rev-parse --git-dir > /dev/null 2>&1; then
        print_error "Not a git repository!"
        exit 1
    fi
    
    local current_branch
    current_branch=$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    
    # Check for uncommitted changes
    if ! git -C "$PROJECT_ROOT" diff --quiet HEAD 2>/dev/null; then
        print_warning "You have uncommitted changes!"
        git -C "$PROJECT_ROOT" status --short
        echo ""
    fi
    
    echo ""
    print_info "Current git branch: ${YELLOW}${current_branch}${NC}"
    echo ""
    
    read -p "Do you want to publish from this branch? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Operation cancelled."
        exit 0
    fi
    
    CURRENT_BRANCH="$current_branch"
}

# Get current version from pubspec.yaml
get_current_version() {
    local pubspec="$PROJECT_ROOT/pubspec.yaml"
    if [ ! -f "$pubspec" ]; then
        print_error "pubspec.yaml not found!"
        exit 1
    fi
    
    grep -E '^version:' "$pubspec" | sed 's/version: //' | tr -d ' '
}

# Parse version into components
parse_version() {
    local version="$1"
    
    # Remove any build metadata
    version="${version%%+*}"
    
    # Split into major.minor.patch
    IFS='.' read -r MAJOR MINOR PATCH <<< "$version"
}

# Bump version based on type
bump_version() {
    local type="$1"
    local current_version
    current_version=$(get_current_version)
    
    parse_version "$current_version"
    
    case "$type" in
        fix|patch)
            NEW_VERSION="$MAJOR.$MINOR.$((PATCH + 1))"
            ;;
        minor)
            NEW_VERSION="$MAJOR.$((MINOR + 1)).0"
            ;;
        major)
            NEW_VERSION="$((MAJOR + 1)).0.0"
            ;;
        *)
            print_error "Unknown version type: $type"
            exit 1
            ;;
    esac
    
    print_info "Version bump: ${current_version} → ${NEW_VERSION}"
}

# Update version in pubspec.yaml
update_pubspec_version() {
    local pubspec="$PROJECT_ROOT/pubspec.yaml"
    local current_version
    current_version=$(get_current_version)
    
    sed -i.bak "s/^version: ${current_version}/version: ${NEW_VERSION}/" "$pubspec"
    rm -f "${pubspec}.bak"
    
    print_success "Updated pubspec.yaml to version ${NEW_VERSION}"
}

# Update CHANGELOG.md
update_changelog() {
    local changelog="$PROJECT_ROOT/CHANGELOG.md"
    local date
    date=$(date +%Y-%m-%d)
    
    if [ ! -f "$changelog" ]; then
        # Create new changelog
        cat > "$changelog" << EOF
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [${NEW_VERSION}] - ${date}

### Added
- Initial release

EOF
        print_success "Created CHANGELOG.md"
    else
        # Prepend new version entry
        local temp_file
        temp_file=$(mktemp)
        
        # Read first lines until we hit the first version entry
        {
            head -n 6 "$changelog"
            echo ""
            echo "## [${NEW_VERSION}] - ${date}"
            echo ""
            echo "### Changed"
            echo "- Version bump"
            echo ""
            tail -n +7 "$changelog"
        } > "$temp_file"
        
        mv "$temp_file" "$changelog"
        print_success "Updated CHANGELOG.md with version ${NEW_VERSION}"
    fi
    
    print_warning "Please review and update CHANGELOG.md before continuing!"
    echo ""
    read -p "Press Enter when CHANGELOG.md is ready, or Ctrl+C to abort..."
}

# Sync dependencies
sync_dependencies() {
    print_step "1" "Sync Dependencies"
    
    local deps_script="$SCRIPT_DIR/dependencies.sh"
    
    if [ -x "$deps_script" ]; then
        # Run sync without git check (we already did that)
        print_info "Running dependencies sync..."
        cd "$PROJECT_ROOT"
        
        # Run flutter pub get
        flutter pub get
        print_success "Flutter dependencies synced"
    else
        print_warning "dependencies.sh not found or not executable"
        print_info "Running flutter pub get..."
        cd "$PROJECT_ROOT"
        flutter pub get
    fi
}

# Run Flutter package health checks
run_health_checks() {
    print_step "2" "Package Health Checks"
    
    cd "$PROJECT_ROOT"
    
    # Run dart analyze
    print_info "Running dart analyze..."
    if dart analyze --fatal-infos; then
        print_success "Code analysis passed"
    else
        print_error "Code analysis found issues!"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Run dart format check
    print_info "Checking code formatting..."
    if dart format --output=none --set-exit-if-changed lib/; then
        print_success "Code formatting is correct"
    else
        print_warning "Code formatting issues found. Fixing..."
        dart format lib/
        print_success "Code formatted"
    fi
    
    # Run tests if they exist
    if [ -d "$PROJECT_ROOT/test" ] && [ "$(ls -A $PROJECT_ROOT/test 2>/dev/null)" ]; then
        print_info "Running tests..."
        if flutter test; then
            print_success "Tests passed"
        else
            print_error "Tests failed!"
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    else
        print_warning "No tests found. Skipping..."
    fi
}

# Bump version and update changelog
bump_and_changelog() {
    print_step "3" "Version Bump & Changelog"
    
    bump_version "$VERSION_TYPE"
    update_pubspec_version
    update_changelog
}

# Create git tag
create_git_tag() {
    print_step "4" "Git Operations"
    
    cd "$PROJECT_ROOT"
    
    # Stage changes
    git add pubspec.yaml CHANGELOG.md
    
    # Check if there are changes to commit
    if git diff --cached --quiet; then
        print_warning "No changes to commit. Version may already be bumped."
    else
        # Commit
        git commit -m "chore: bump version to ${NEW_VERSION}"
        print_success "Created commit for version ${NEW_VERSION}"
    fi
    
    # Create tag
    local tag="v${NEW_VERSION}"
    
    if git rev-parse "$tag" >/dev/null 2>&1; then
        print_warning "Tag ${tag} already exists!"
        read -p "Delete and recreate? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git tag -d "$tag"
        else
            print_error "Cannot continue without tag"
            exit 1
        fi
    fi
    
    git tag -a "$tag" -m "Release ${NEW_VERSION}"
    print_success "Created tag ${tag}"
    
    # Push
    echo ""
    read -p "Push commit and tag to origin? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git push origin "$CURRENT_BRANCH"
        git push origin "$tag"
        print_success "Pushed to origin"
    else
        print_info "Skipped push. Run manually:"
        echo "  git push origin $CURRENT_BRANCH"
        echo "  git push origin $tag"
    fi
}

# Run dry-run publish
run_dry_run() {
    print_step "5" "Pub.dev Dry Run"
    
    cd "$PROJECT_ROOT"
    
    print_info "Running flutter pub publish --dry-run..."
    echo ""
    
    if flutter pub publish --dry-run; then
        print_success "Dry run passed!"
    else
        print_error "Dry run failed!"
        read -p "Continue to publish anyway? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Publish to pub.dev
publish_to_pub() {
    print_step "6" "Publish to pub.dev"
    
    cd "$PROJECT_ROOT"
    
    echo ""
    print_warning "This will publish version ${NEW_VERSION} to pub.dev!"
    print_warning "This action CANNOT be undone!"
    echo ""
    
    read -p "Are you sure you want to publish? (type 'yes' to confirm): " -r
    echo ""
    
    if [ "$REPLY" != "yes" ]; then
        print_info "Publish cancelled."
        echo ""
        print_info "To publish manually, run:"
        echo "  flutter pub publish"
        exit 0
    fi
    
    # Publish
    flutter pub publish --force
    
    echo ""
    print_success "🎉 Version ${NEW_VERSION} published to pub.dev!"
}

# Show summary
show_summary() {
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  Publishing Complete!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  Version: ${NEW_VERSION}"
    echo "  Tag:     v${NEW_VERSION}"
    echo "  Branch:  ${CURRENT_BRANCH}"
    echo ""
    echo "  Package URL: https://pub.dev/packages/liquid_ai_leap"
    echo ""
}

# Show usage
show_usage() {
    echo "Usage: $0 <version-type>"
    echo ""
    echo "Version types:"
    echo "  fix, patch   Bump patch version (0.1.0 -> 0.1.1)"
    echo "  minor        Bump minor version (0.1.0 -> 0.2.0)"
    echo "  major        Bump major version (0.1.0 -> 1.0.0)"
    echo ""
    echo "Examples:"
    echo "  $0 fix       # Bug fix release"
    echo "  $0 minor     # New feature release"
    echo "  $0 major     # Breaking change release"
    echo ""
    echo "Options:"
    echo "  --dry-run    Only run dry-run, don't actually publish"
    echo "  --help       Show this help message"
}

# Main entry point
main() {
    local version_type="${1:-help}"
    
    case "$version_type" in
        fix|patch|minor|major)
            VERSION_TYPE="$version_type"
            
            print_header
            check_git_branch
            
            sync_dependencies
            run_health_checks
            bump_and_changelog
            create_git_tag
            run_dry_run
            publish_to_pub
            show_summary
            ;;
        --dry-run)
            print_header
            check_git_branch
            
            VERSION_TYPE="${2:-fix}"
            bump_version "$VERSION_TYPE"
            
            sync_dependencies
            run_health_checks
            run_dry_run
            
            print_info "Dry run complete. No changes were made."
            ;;
        help|--help|-h)
            print_header
            show_usage
            ;;
        *)
            print_error "Unknown version type: $version_type"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
