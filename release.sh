#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT_DIR}"

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 vX.Y.Z" >&2
  exit 1
fi

TAG="$1"

if git rev-parse "${TAG}" >/dev/null 2>&1; then
  echo "Tag ${TAG} already exists locally." >&2
  exit 1
fi

echo "Creating annotated tag ${TAG}"
git tag -a "${TAG}" -m "Release ${TAG}"
git push origin "${TAG}"

echo "Building artifacts"
swift build -c release --arch arm64
swift build -c release --arch x86_64

echo "Running packaging script"
./buildapp.sh

ZIP="dist/$(ls dist | grep -E '\.zip$' | tail -n1)"
DMG="dist/$(ls dist | grep -E '\.dmg$' | tail -n1)"

if command -v gh >/dev/null 2>&1; then
  echo "Creating GitHub release ${TAG} and uploading assets"
  gh release create "${TAG}" "${ZIP}" "${DMG}" --title "${TAG}" --notes "Release ${TAG}"
else
  echo "gh CLI not found — release created locally, artifacts in dist/:" 
  echo "  ${ZIP}"
  echo "  ${DMG}"
  echo "Install GitHub CLI and run: gh release create ${TAG} ${ZIP} ${DMG} --title ${TAG} --notes 'Release ${TAG}'"
fi

echo "Release script finished."
