#!/bin/bash

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

error()   { echo -e "${RED}✗ $1${NC}" >&2; exit 1; }
success() { echo -e "${GREEN}✓ $1${NC}"; }
info()    { echo -e "${CYAN}ℹ $1${NC}"; }
usage() {
  cat <<'EOF'
Usage: ./scripts/update-changelog.sh [options] <package> <version>

Examples:
  ./scripts/update-changelog.sh qora 1.1.0
  ./scripts/update-changelog.sh qora_flutter 1.1.0
  ./scripts/update-changelog.sh --dry-run qora_hooks 1.1.0

Options:
  --dry-run    Simulate without modifying files
  --help       Show this message
EOF
  exit 0
}

DRY_RUN=false
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --help)    usage ;;
    *) POSITIONAL+=("$1"); shift ;;
  esac
done

[ ${#POSITIONAL[@]} -lt 2 ] && error "Missing arguments.\n$(usage)"

PACKAGE=${POSITIONAL[0]}
VERSION=${POSITIONAL[1]}
DATE=$(date +%Y-%m-%d)
REPO="https://github.com/meragix/qora/compare"

CHANGELOG="packages/$PACKAGE/CHANGELOG.md"
PUBSPEC="packages/$PACKAGE/pubspec.yaml"

[ ! -f "$CHANGELOG" ] && error "CHANGELOG not found: $CHANGELOG"
[ ! -f "$PUBSPEC" ]   && error "pubspec not found: $PUBSPEC"

# Get current version from pubspec
CURRENT_VERSION=$(grep "^version: " "$PUBSPEC" | sed "s/version: //")

echo -e "${CYAN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  $PACKAGE: $CURRENT_VERSION → $VERSION"
echo -e "${CYAN}╚════════════════════════════════════════════════╝${NC}\n"
$DRY_RUN && info "DRY RUN — no files modified\n"

# Insert version header under [Unreleased]
if ! $DRY_RUN; then
  perl -i -0pe "s/## \[Unreleased\]/## [Unreleased]\n\n## [$VERSION] - $DATE/" "$CHANGELOG"
  success "Added [$VERSION] header"
else
  info "Would add [$VERSION] header"
fi

# Add version link at bottom + update unreleased link
# Find the previous version tag (last non-unreleased link)
PREV_TAG=$(grep -oP '\[\K[^\]]+(?=\]: https://github.com/meragix/qora/compare)' "$CHANGELOG" \
  | grep -v '^unreleased$' | tail -1)

if [ -z "$PREV_TAG" ]; then
  # No existing links — use current version from pubspec
  PREV_TAG="$CURRENT_VERSION"
  PREV_SCOPE=""
else
  PREV_SCOPE="$PACKAGE-"
fi

if ! $DRY_RUN; then
  # Remove old unreleased link if present, then append fresh ones
  grep -v "^\\[unreleased\\]:" "$CHANGELOG" > "${CHANGELOG}.tmp"
  mv "${CHANGELOG}.tmp" "$CHANGELOG"

  printf "[unreleased]: $REPO/$PACKAGE-$VERSION...HEAD\n" >> "$CHANGELOG"
  printf "[$VERSION]: $REPO/${PREV_SCOPE}$PREV_TAG...$PACKAGE-$VERSION\n" >> "$CHANGELOG"
  success "Version links updated"
else
  info "Would add version links:"
  echo "  [unreleased]: $REPO/$PACKAGE-$VERSION...HEAD"
  echo "  [$VERSION]:   $REPO/${PREV_SCOPE}$PREV_TAG...$PACKAGE-$VERSION"
fi

echo ""
success "Done — review $CHANGELOG"
