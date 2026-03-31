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
BINARY_PATH="${APP_DIR}/Contents/MacOS/${APP_NAME}"
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

printf "\n==> Scrittura Info.plist\n"
cat > "${PLIST_PATH}" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>FastCalc</string>
  <key>CFBundleDisplayName</key><string>FastCalc</string>
  <key>CFBundleIdentifier</key><string>com.fastcalc.app</string>
  <key>CFBundleIconFile</key><string>fastcalc.icns</string>
  <key>CFBundleExecutable</key><string>FastCalc</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
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

printf "\n==> Verifica architetture binario\n"
lipo -info "${BINARY_PATH}"

printf "\nBuild completata.\n- App bundle: %s\n- Zip distribuzione: %s\n\n" "${APP_DIR}" "${ZIP_PATH}"
