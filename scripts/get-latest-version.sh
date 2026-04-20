#!/bin/bash
# get-latest-version.sh
#
# Gets the latest release version from git tags.
# Cubyz tags follow the `MAJOR.MINOR.PATCH` pattern without a `v` prefix
# (see .github/workflows/release.yml). This script returns the highest such
# tag, falling back to "0.0.0" when no tags are present.
#
# Usage:
#   ./scripts/get-latest-version.sh
#
# Output:
#   Prints the latest version (e.g., "0.2.0") to stdout.

set -euo pipefail

# Make sure we have all tags locally; ignore failures (e.g. shallow clones
# without remote access) so the script still works in offline contexts.
git fetch origin --tags --force >/dev/null 2>&1 || true

LATEST_TAG=$(git tag --sort=-version:refname | head -n1 || true)

if [ -z "$LATEST_TAG" ]; then
  LATEST_TAG="0.0.0"
fi

echo "${LATEST_TAG#v}"
