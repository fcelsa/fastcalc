#!/usr/bin/env bash
set -euo pipefail

APP_NAME="FastCalc"
EXECUTABLE_NAME="fastcalc"
BUNDLE_NAME="${APP_NAME}.app"
ZIP_NAME="${APP_NAME}-macOS-universal.zip"
ICON_FILE_NAME="fastcalc.icns"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
BUILD_ARM_DIR="${ROOT_DIR}/.build-arm64"
BUILD_X86_DIR="${ROOT_DIR}/.build-x86_64"
APP_DIR="${DIST_DIR}/${BUNDLE_NAME}"
BINARY_PATH="${APP_DIR}/Contents/MacOS/${EXECUTABLE_NAME}"
PLIST_PATH="${APP_DIR}/Contents/Info.plist"
ZIP_PATH="${DIST_DIR}/${ZIP_NAME}"
ICON_SOURCE_PATH="${ROOT_DIR}/resources/${ICON_FILE_NAME}"
ICON_BUNDLE_PATH="${APP_DIR}/Contents/Resources/${ICON_FILE_NAME}"

printf "\n==> Pulizia output precedenti\n"
rm -rf "${DIST_DIR}" "${BUILD_ARM_DIR}" "${BUILD_X86_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"

printf "\n==> Build release arm64\n"
swift build -c release --arch arm64 --scratch-path "${BUILD_ARM_DIR}"

printf "\n==> Build release x86_64\n"
swift build -c release --arch x86_64 --scratch-path "${BUILD_X86_DIR}"

printf "\n==> Creazione binario universal\n"
lipo -create \
  "${BUILD_ARM_DIR}/release/${EXECUTABLE_NAME}" \
  "${BUILD_X86_DIR}/release/${EXECUTABLE_NAME}" \
  -output "${BINARY_PATH}"
chmod +x "${BINARY_PATH}"

printf "\n==> Calcolo versione e build\n"
# Versione app: dal tag piu recente vX.Y.Z, fallback statico.
if VERSION_TAG="$(git -C "${ROOT_DIR}" describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null)"; then
  APP_VERSION="${VERSION_TAG#v}"
else
  APP_VERSION="1.0.0"
fi

# Build incrementale: conteggio commit, fallback timestamp se git non disponibile.
if BUILD_NUMBER="$(git -C "${ROOT_DIR}" rev-list --count HEAD 2>/dev/null)"; then
  :
else
  BUILD_NUMBER="$(date +%Y%m%d%H%M%S)"
fi

printf "Versione: %s\nBuild: %s\n" "${APP_VERSION}" "${BUILD_NUMBER}"

# DMG name depends on APP_VERSION; define it after APP_VERSION is known
DMG_NAME="${APP_NAME}-${APP_VERSION}-macOS-universal.dmg"
DMG_PATH="${DIST_DIR}/${DMG_NAME}"

printf "\n==> Scrittura Info.plist\n"
cat > "${PLIST_PATH}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key><string>com.fastcalc.app</string>
  <key>CFBundleIconFile</key><string>${ICON_FILE_NAME}</string>
  <key>CFBundleExecutable</key><string>${EXECUTABLE_NAME}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${APP_VERSION}</string>
  <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
</dict>
</plist>
EOF

printf "\n==> Copia icona app\n"
if [[ ! -f "${ICON_SOURCE_PATH}" ]]; then
  printf "Errore: icona non trovata in %s\n" "${ICON_SOURCE_PATH}" >&2
  exit 1
fi
cp "${ICON_SOURCE_PATH}" "${ICON_BUNDLE_PATH}"

printf "\n==> Firma ad-hoc bundle\n"
codesign --force --deep --sign - "${APP_DIR}"

printf "\n==> Packaging zip\n"
ditto -c -k --sequesterRsrc --keepParent "${APP_DIR}" "${ZIP_PATH}"

printf "\n==> Creazione DMG\n"
# Create a temporary staging folder containing the .app and an Applications symlink
STAGING_DIR="$(mktemp -d "${ROOT_DIR}/dist/${APP_NAME}.staging.XXXX")"
cp -R "${APP_DIR}" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

# Create compressed DMG (UDZO)
hdiutil create -volname "${APP_NAME}" -srcfolder "${STAGING_DIR}" -ov -format UDZO "${DMG_PATH}"
rm -rf "${STAGING_DIR}"

printf "\n==> Verifica architetture binario\n"
lipo -info "${BINARY_PATH}"

printf "\nBuild completata.\n- App bundle: %s\n- Zip distribuzione: %s\n\n" "${APP_DIR}" "${ZIP_PATH}"
