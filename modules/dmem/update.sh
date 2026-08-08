#!/usr/bin/env nix-shell
#! nix-shell -i bash -p curl git jq nix nix-prefetch-git

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
CORE="${ICEDOS_CORE:-$REPO_ROOT/.icedos-core}"
[ -d "$CORE" ] || CORE="$REPO_ROOT/../core"
[ -f "$CORE/lib/update-lib.sh" ] || {
  echo "ERROR: core not found; set ICEDOS_CORE=/path/to/IceDOS/core" >&2
  exit 1
}
# shellcheck source=/dev/null
. "$CORE/lib/update-lib.sh"

PIN="$SCRIPT_DIR/source.json"
LOCK="$SCRIPT_DIR/Cargo.lock"
URL="https://gitlab.steamos.cloud/holo/dmemcg-booster.git"
BRANCH="main"

main() {
  banner "dmem updater"

  info "Finding latest dmemcg-booster $BRANCH commit..."
  local rev
  rev=$(git_head "$URL" "$BRANCH")
  [ -n "$rev" ] || error "could not read $BRANCH HEAD"
  info "  Latest: $rev"

  local current
  current=$(read_pin "$PIN" .rev)
  if [ "$rev" = "$current" ]; then
    info "  Already up to date ($rev)"
    return
  fi
  info "  Current: ${current:-none}"

  # One clone yields the hash, the commit date, and a store path to read Cargo.toml and
  # Cargo.lock out of — no second checkout, and no API on a self-hosted GitLab.
  info "  Fetching source..."
  local report hash date path
  report=$(prefetch_git_json "$URL" "$rev" || echo "")
  hash=$(echo "$report" | jq -r '.hash // ""')
  date=$(echo "$report" | jq -r '.date // ""' | cut -d'T' -f1)
  path=$(echo "$report" | jq -r '.path // ""')
  require_nonempty dmem "$rev" "$hash" "$date" "$path"
  info "  Hash: $hash"

  # Upstream never tags, so the crate version is combined with the commit date in nixpkgs'
  # `<version>-unstable-<date>` form.
  local crate_version version
  crate_version=$(sed -n 's/^version = "\(.*\)"$/\1/p' "$path/Cargo.toml" | head -1)
  require_nonempty "dmem (Cargo.toml version)" "$crate_version"
  version="$crate_version-unstable-$date"

  # Vendored lockfile must move with the revision or build fails on stale deps.
  [ -f "$path/Cargo.lock" ] || error "upstream checkout has no Cargo.lock to vendor"
  install -m644 "$path/Cargo.lock" "$LOCK"
  info "  Vendored Cargo.lock refreshed"

  jq -n --arg version "$version" --arg rev "$rev" --arg hash "$hash" \
    '{version: $version, rev: $rev, hash: $hash}' | write_pin "$PIN"

  info "  Updated: $version"
}

main "$@"

echo ""
info "Done. Review changes with: git diff $SCRIPT_DIR"
