#!/bin/bash

set -e

# ── Colors ──────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m'; NC='\033[0m'

# ── Helpers ─────────────────────────────────────────────────────────────
error()   { echo -e "${RED}✗ $1${NC}" >&2; exit 1; }
success() { echo -e "${GREEN}✓ $1${NC}"; }
info()    { echo -e "${BLUE}ℹ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠ $1${NC}"; }

usage() {
  cat <<'EOF'
Usage: ./scripts/release.sh [options] <version>

Bumps qora, qora_flutter, and qora_hooks together and creates a
tag matching the existing convention (x.y.z).

Examples:
  ./scripts/release.sh 1.1.0
  ./scripts/release.sh 1.2.0-dev.1
  ./scripts/release.sh --dry-run 1.1.0

Options:
  --dry-run    Simulate release without making changes
  --help       Show this message
EOF
  exit 0
}

# ── Parse args ──────────────────────────────────────────────────────────
DRY_RUN=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --help)    usage ;;
    -*)
      if [[ "$1" =~ ^-- ]]; then
        error "Unknown option: $1\n$(usage)"
      fi
      break ;;
    *) break ;;
  esac
done

TAG=${1:-}
[[ -z "$TAG" ]] && error "Missing version. Use --help for usage."

# Strip optional qora- prefix for convenience, then validate
# TAG="${TAG#qora-}"

VERSION_REGEX='^[0-9]+\.[0-9]+\.[0-9]+(-[a-z0-9.]+)?$'
[[ ! "$TAG" =~ $VERSION_REGEX ]] && error "Invalid version. Expected semver (e.g. 1.1.0 or 1.2.0-dev.1)"

VERSION="$TAG"

# All packages released together
PACKAGES=("dart" "flutter" "hooks")

echo -e "${CYAN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Workspace Release v$VERSION"
echo -e "${CYAN}╚════════════════════════════════════════════════╝${NC}\n"
$DRY_RUN && warning "DRY RUN — no files will be modified\n"

# ── 1. Check git status ─────────────────────────────────────────────────
info "Checking git status..."
[ -n "$(git status --porcelain)" ] && error "Working directory not clean. Commit or stash changes."
success "Working directory clean"

# ── 2. Validate & lint all packages ─────────────────────────────────────
info "Checking formatting..."
$DRY_RUN && melos run format:check 2>/dev/null || melos run format:check || error "Format check failed"
success "Format OK"

for PKG in "${PACKAGES[@]}"; do
  info "Analyzing $PKG..."
  PKG_DIR="packages/$PKG"
  if $DRY_RUN; then
    (cd "$PKG_DIR" && dart analyze --fatal-infos .) 2>/dev/null || true
  else
    (cd "$PKG_DIR" && dart analyze --fatal-infos .) || error "Analysis failed for $PKG"
  fi
  success "$PKG analysis passed"
done

# ── 3. Run tests ────────────────────────────────────────────────────────
info "Running tests..."
for PKG in dart; do
  PKG_DIR="packages/$PKG"
  if $DRY_RUN; then
    (cd "$PKG_DIR" && dart test) 2>/dev/null || true
  else
    (cd "$PKG_DIR" && dart test) || error "Tests failed for $PKG"
  fi
done
success "Tests passed"

# ── 4. Confirmation prompt ──────────────────────────────────────────────
echo ""
warning "This will release ALL packages to v$VERSION:"
for PKG in "${PACKAGES[@]}"; do
  CURRENT=$(grep "^version: " "packages/$PKG/pubspec.yaml" | sed "s/version: //")
  echo "   • $PKG: $CURRENT → $VERSION"
done
echo "   • Commit: chore(release): bump workspace to v$VERSION"
echo "   • Tag:    $TAG"
echo ""
read -p "$(echo -e ${YELLOW}"Continue? [y/N] "${NC})" -r CONFIRM
[[ ! "$CONFIRM" =~ ^[YyOo]$ ]] && error "Aborted by user"

# ── 5. Update pubspec.yaml + CHANGELOG for all packages ─────────────────
DATE=$(date +%Y-%m-%d)
REPO_URL="https://github.com/meragix/qora/compare"
STAGED=()

for PKG in "${PACKAGES[@]}"; do
  PKG_DIR="packages/$PKG"
  PUBSPEC="$PKG_DIR/pubspec.yaml"
  CHANGELOG="$PKG_DIR/CHANGELOG.md"

  # pubspec
  if ! $DRY_RUN; then
    perl -i -pe "s/^version: .*/version: $VERSION/" "$PUBSPEC"
    success "$PKG pubspec → $VERSION"
  else
    success "[DRY RUN] $PKG pubspec → $VERSION"
  fi

  # changelog header (stable only)
  if [[ ! "$VERSION" =~ -dev\. ]] && [[ ! "$VERSION" =~ -beta\. ]] && [[ ! "$VERSION" =~ -alpha\. ]]; then
    if ! $DRY_RUN; then
      perl -i -0pe "s/## \[Unreleased\]/## [Unreleased]\n\n## [$VERSION] - $DATE/" "$CHANGELOG"
      success "$PKG CHANGELOG header added"
    else
      success "[DRY RUN] $PKG CHANGELOG header added"
    fi
  fi

  STAGED+=("$PUBSPEC" "$CHANGELOG")
done

# ── 6. Update version links at bottom of qora CHANGELOG ─────────────────
CHANGELOG_CORE="packages/dart/CHANGELOG.md"
if ! $DRY_RUN && [[ ! "$VERSION" =~ -dev\. ]] && [[ ! "$VERSION" =~ -beta\. ]] && [[ ! "$VERSION" =~ -alpha\. ]]; then
  # Find the last stable version link
  PREV_TAG=$(grep -oP '\[\K[^\]]+(?=\]: https://github.com/meragix/qora/compare)' "$CHANGELOG_CORE" \
    | grep -v '^unreleased$' | tail -1)
  PREV_TAG="${PREV_TAG:-1.0.0}"

  grep -v "^\\[unreleased\\]:" "$CHANGELOG_CORE" > "${CHANGELOG_CORE}.tmp"
  mv "${CHANGELOG_CORE}.tmp" "$CHANGELOG_CORE"

  printf "[unreleased]: $REPO_URL/$TAG...HEAD\n" >> "$CHANGELOG_CORE"
  printf "[$VERSION]: $REPO_URL/$PREV_TAG...$TAG\n" >> "$CHANGELOG_CORE"
  success "Core CHANGELOG version links updated"
fi

# ── 7. Commit and tag ───────────────────────────────────────────────────
if ! $DRY_RUN; then
  git add "${STAGED[@]}"
  git commit -m "chore(release): bump workspace to v$VERSION" --no-verify
  git tag "$TAG" -m "Release workspace v$VERSION"
  success "Commit + tag created: $TAG"
else
  success "[DRY RUN] Would commit + tag: $TAG"
fi

# ── Done ────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Release Ready!                                ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════╝${NC}"
echo ""
for PKG in "${PACKAGES[@]}"; do
  echo -e "  ${GREEN}✔${NC} $PKG v$VERSION"
done

if ! $DRY_RUN; then
  echo ""
  warning "Next steps:"
  echo "  1. Push:     git push origin main"
  echo "  2. Push tag: git push origin $TAG"
  echo "  3. Publish:  dart pub publish (from each package dir)"
fi
