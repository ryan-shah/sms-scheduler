#!/usr/bin/env bash
#
# Single source of truth for the app's version, shared by every build workflow.
#
#   versionName = <MAJOR.MINOR from pubspec.yaml>.<git commit count>
#   versionCode = <git commit count>
#
# So commit 19 on main ships as v0.1.19 / build 19: the version changes on
# every merge with no manual step, and `v0.1.N` and `build N` read as the same
# number. To start a new series, bump `version:` in pubspec.yaml (only the
# MAJOR.MINOR part is read; the patch and `+build` suffix are ignored).
#
# Usage:
#   bash tool/ci_version.sh          # prints "name=..." / "code=..."
#   In GitHub Actions it also appends name=/code= to $GITHUB_OUTPUT.
#
# NOTE: requires full git history — `actions/checkout` must use
# `fetch-depth: 0`, or the commit count collapses to 1 on a shallow clone.

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PUBSPEC="$REPO_ROOT/pubspec.yaml"

if [ ! -f "$PUBSPEC" ]; then
  echo "ci_version.sh: pubspec.yaml not found at $PUBSPEC" >&2
  exit 1
fi

# `version: 0.1.0+1` -> `0.1.0`
BASE=$(grep -m1 '^version:' "$PUBSPEC" | sed 's/^version:[[:space:]]*//' | cut -d'+' -f1 | tr -d '[:space:]')
if [ -z "$BASE" ]; then
  echo "ci_version.sh: no 'version:' line found in pubspec.yaml" >&2
  exit 1
fi

# `0.1.0` -> `0.1`
MAJOR_MINOR=$(printf '%s' "$BASE" | cut -d. -f1,2)
case "$MAJOR_MINOR" in
  [0-9]*.[0-9]*) ;;
  *)
    echo "ci_version.sh: cannot parse MAJOR.MINOR from pubspec version '$BASE'" >&2
    exit 1
    ;;
esac

CODE=$(git -C "$REPO_ROOT" rev-list --count HEAD)
case "$CODE" in
  ''|*[!0-9]*)
    echo "ci_version.sh: could not determine commit count (got '$CODE')" >&2
    exit 1
    ;;
esac

NAME="${MAJOR_MINOR}.${CODE}"

echo "name=${NAME}"
echo "code=${CODE}"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "name=${NAME}"
    echo "code=${CODE}"
  } >> "$GITHUB_OUTPUT"
fi
