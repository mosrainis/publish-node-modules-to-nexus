#!/usr/bin/env bash
set -Eeuo pipefail

#######################################
# Configuration (via environment vars)
#######################################

: "${NEXUS_REGISTRY:?NEXUS_REGISTRY is required}"
: "${NEXUS_AUTH_TOKEN:?NEXUS_AUTH_TOKEN is required}"

NODE_MODULES_DIR="${NODE_MODULES_DIR:-node_modules}"
DRY_RUN="${DRY_RUN:-false}"

#######################################
# Counters
#######################################

SUCCESS_COUNT=0
SKIP_COUNT=0
ERROR_COUNT=0

#######################################
# Logging helpers
#######################################

log()  { echo -e "$1"; }
info() { log "ℹ️  $1"; }
ok()   { log "✅ $1"; }
warn() { log "⚠️  $1"; }
err()  { log "❌ $1"; }

#######################################
# Read package.json safely
#######################################

read_pkg_field() {
  local dir="$1"
  local field="$2"

  node -e "
    const fs = require('fs');
    const path = require('path');
    const pkgPath = path.resolve('$dir/package.json');

    if (!fs.existsSync(pkgPath)) process.exit(1);

    const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
    console.log(pkg['$field'] ?? '');
  " 2>/dev/null || true
}

#######################################
# Publish a single package
#######################################

publish_package() {
  local pkg_dir="$1"

  [[ -f "$pkg_dir/package.json" ]] || return 0

  local name version is_private
  name="$(read_pkg_field "$pkg_dir" name)"
  version="$(read_pkg_field "$pkg_dir" version)"
  is_private="$(read_pkg_field "$pkg_dir" private)"

  if [[ -z "$name" || -z "$version" ]]; then
    warn "Skipping invalid package in $pkg_dir"
    ((SKIP_COUNT++))
    return 0
  fi

  if [[ "$is_private" == "true" ]]; then
    info "Skipping private package: $name"
    ((SKIP_COUNT++))
    return 0
  fi

  info "Processing $name@$version"

  pushd "$pkg_dir" >/dev/null || {
    err "Failed to enter $pkg_dir"
    ((ERROR_COUNT++))
    return 0
  }

  local tarball
  if ! tarball="$(npm pack --ignore-scripts | tail -n 1)"; then
    err "npm pack failed for $name"
    popd >/dev/null
    ((ERROR_COUNT++))
    return 0
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    info "[DRY RUN] Would publish $tarball"
    rm -f "$tarball"
    popd >/dev/null
    ((SKIP_COUNT++))
    return 0
  fi

  if npm publish "$tarball" \
    --registry="$NEXUS_REGISTRY" \
    --ignore-scripts \
    --//${NEXUS_REGISTRY#http://}:_authToken="$NEXUS_AUTH_TOKEN" \
    >/dev/null 2>&1; then

    ok "Published $name@$version"
    ((SUCCESS_COUNT++))
  else
    warn "Skipped $name@$version (already exists or forbidden)"
    ((SKIP_COUNT++))
  fi

  rm -f "$tarball"
  popd >/dev/null
}

#######################################
# Main
#######################################

log "🚀 Publishing node_modules packages to Nexus"
info "Registry: $NEXUS_REGISTRY"
info "Dry run: $DRY_RUN"
echo ""

for dir in "$NODE_MODULES_DIR"/*; do
  if [[ "$dir" == "$NODE_MODULES_DIR"/@* ]]; then
    for scoped in "$dir"/*; do
      publish_package "$scoped"
    done
  else
    publish_package "$dir"
  fi
done

echo ""
ok "Done"
log "📊 Summary:"
log "   ✅ Published: $SUCCESS_COUNT"
log "   ⚠️  Skipped:   $SKIP_COUNT"
log "   ❌ Errors:    $ERROR_COUNT"
