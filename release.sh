#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT_DIR}"

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 vX.Y.Z" >&2
  exit 1
fi

TAG="$1"

PUBLISH_ONLY=0
TAG_EXISTS_REMOTE=0

if git rev-parse "${TAG}" >/dev/null 2>&1; then
  echo "Tag ${TAG} already exists locally."
  read -r -p "Proceed in publish-only mode (skip git tag/git push)? [y/N] " CONTINUE_PUBLISH_ONLY
  if [ "${CONTINUE_PUBLISH_ONLY}" != "y" ] && [ "${CONTINUE_PUBLISH_ONLY}" != "Y" ]; then
    echo "Aborting release."
    exit 1
  fi
  PUBLISH_ONLY=1
fi

if git ls-remote --exit-code --tags origin "refs/tags/${TAG}" >/dev/null 2>&1; then
  TAG_EXISTS_REMOTE=1
fi

# Preflight checks
echo "Running preflight checks..."

# 1) Run tests
if command -v swift >/dev/null 2>&1; then
  echo "Running tests (swift test)"
  if ! swift test; then
    echo "Tests failed — aborting release." >&2
    exit 1
  fi
else
  echo "swift not found in PATH — skipping tests (proceed with caution)"
fi

# 2) Ensure branch is in sync with origin
BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "Current branch: ${BRANCH}"
git fetch origin --quiet
LOCAL=$(git rev-parse HEAD)
if git rev-parse "origin/${BRANCH}" >/dev/null 2>&1; then
  REMOTE=$(git rev-parse "origin/${BRANCH}")
  if [ "${LOCAL}" != "${REMOTE}" ]; then
    echo "Local branch ${BRANCH} is not up-to-date with origin/${BRANCH}." >&2
    echo "Please pull/rebase and push any pending commits before creating a release." >&2
    exit 1
  fi
else
  echo "No remote branch origin/${BRANCH} found — ensure the branch is pushed before releasing." >&2
  exit 1
fi

# 3) Confirm with user
if [ "${PUBLISH_ONLY}" -eq 1 ]; then
  read -r -p "Proceed with build and remote publication for existing tag ${TAG}? [y/N] " CONFIRM
else
  read -r -p "Proceed to create and push tag ${TAG} on branch ${BRANCH}? [y/N] " CONFIRM
fi
if [ "${CONFIRM}" != "y" ] && [ "${CONFIRM}" != "Y" ]; then
  echo "Aborting release." 
  exit 1
fi

if [ "${PUBLISH_ONLY}" -eq 0 ]; then
  echo "Creating annotated tag ${TAG}"
  git tag -a "${TAG}" -m "Release ${TAG}"
  git push origin "${TAG}"
else
  echo "Skipping git tag and git push (publish-only mode)"
fi

echo "Building artifacts"
swift build -c release --arch arm64
swift build -c release --arch x86_64

echo "Running packaging script"
./buildapp.sh

ZIP="dist/$(ls dist | grep -E '\.zip$' | tail -n1)"
DMG="dist/$(ls dist | grep -E '\.dmg$' | tail -n1)"

# Calculate SHA-256 checksums and write a checksums file
echo "Calcolo checksum SHA-256 degli artefatti"
ZIP_SHA=$(shasum -a 256 "${ZIP}" | awk '{print $1}')
DMG_SHA=$(shasum -a 256 "${DMG}" | awk '{print $1}')
echo "${ZIP_SHA}  $(basename "${ZIP}")" > "${ROOT_DIR}/dist/SHA256SUMS"
echo "${DMG_SHA}  $(basename "${DMG}")" >> "${ROOT_DIR}/dist/SHA256SUMS"

# Prepare release notes including checksums
NOTES_FILE="$(mktemp)"
cat > "${NOTES_FILE}" <<EOF
Release ${TAG}

Artifacts:
- ${ZIP}  SHA256: ${ZIP_SHA}
- ${DMG}  SHA256: ${DMG_SHA}

See dist/SHA256SUMS for the same checksums.
EOF

if command -v gh >/dev/null 2>&1; then
  if gh release view "${TAG}" >/dev/null 2>&1; then
    echo "GitHub release ${TAG} already exists — uploading/replacing assets"
    gh release upload "${TAG}" "${ZIP}" "${DMG}" "${ROOT_DIR}/dist/SHA256SUMS" --clobber
    gh release edit "${TAG}" --notes-file "${NOTES_FILE}"
  else
    echo "Creating GitHub release ${TAG} and uploading assets (with checksums)"
    if [ "${PUBLISH_ONLY}" -eq 1 ] && [ "${TAG_EXISTS_REMOTE}" -eq 0 ]; then
      echo "Remote tag ${TAG} not found — creating release tag from current commit ${LOCAL}"
      gh release create "${TAG}" "${ZIP}" "${DMG}" "${ROOT_DIR}/dist/SHA256SUMS" --title "${TAG}" --notes-file "${NOTES_FILE}" --target "${LOCAL}"
    else
      gh release create "${TAG}" "${ZIP}" "${DMG}" "${ROOT_DIR}/dist/SHA256SUMS" --title "${TAG}" --notes-file "${NOTES_FILE}"
    fi
  fi
  rm -f "${NOTES_FILE}"
else
  echo "gh CLI not found — remote publication skipped, artifacts available in dist/:"
  echo "  ${ZIP}"
  echo "  ${DMG}"
  echo "Checksums written to dist/SHA256SUMS:" 
  cat "${ROOT_DIR}/dist/SHA256SUMS"
  echo "Install GitHub CLI and run: gh release create ${TAG} ${ZIP} ${DMG} dist/SHA256SUMS --title ${TAG} --notes-file <file-with-checksums>"
fi

echo "Release script finished."
