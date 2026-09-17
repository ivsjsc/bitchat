#!/usr/bin/env bash
set -euo pipefail

# Bitchat IVS - free Apple ID / Personal Team device installer.
#
# Usage:
#   TEAM_ID=XXXXXXXXXX DEVICE_UDID=00008110-... ./scripts/install-personal-team.sh
#
# Optional:
#   PERSONAL_BUNDLE_ID=com.example.bitchat.personal
#
# Requirements:
# - macOS + Xcode 15 or newer
# - Apple ID signed in to Xcode (Settings > Accounts)
# - iPhone connected/trusted and Developer Mode enabled
# - a Personal Team available to the signed-in Apple ID

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TEAM_ID="${TEAM_ID:-}"
DEVICE_UDID="${DEVICE_UDID:-}"

if [[ -z "$TEAM_ID" ]]; then
  echo "ERROR: TEAM_ID is required. Example: TEAM_ID=ABCDE12345" >&2
  exit 2
fi

if [[ -z "$DEVICE_UDID" ]]; then
  echo "ERROR: DEVICE_UDID is required. Connect the iPhone and copy its UDID from Finder/Xcode." >&2
  exit 2
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "ERROR: xcodebuild was not found. Install/open Xcode first." >&2
  exit 2
fi

SAFE_TEAM_ID="$(printf '%s' "$TEAM_ID" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')"
if [[ -z "$SAFE_TEAM_ID" ]]; then
  echo "ERROR: TEAM_ID contains no usable characters." >&2
  exit 2
fi

PERSONAL_BUNDLE_ID="${PERSONAL_BUNDLE_ID:-com.ivsjsc.bitchat.personal.${SAFE_TEAM_ID}}"
EXPECTED_EXTENSION_BUNDLE_ID="${PERSONAL_BUNDLE_ID}.ShareExtension"
LOCAL_CONFIG="Configs/Local.xcconfig"
BACKUP_CONFIG=""
DERIVED_DATA="$ROOT_DIR/build/PersonalTeamDerivedData"
EXPORT_DIR="$ROOT_DIR/build/PersonalTeamExport"
IPA_PATH="$EXPORT_DIR/Bitchat-IVS-Personal.ipa"
ENTITLEMENTS_FILE="$ROOT_DIR/Configs/PersonalTeam.entitlements"

cleanup() {
  if [[ -n "$BACKUP_CONFIG" && -f "$BACKUP_CONFIG" ]]; then
    mv -f "$BACKUP_CONFIG" "$LOCAL_CONFIG"
  else
    rm -f "$LOCAL_CONFIG"
  fi
}
trap cleanup EXIT INT TERM

if [[ -f "$LOCAL_CONFIG" ]]; then
  BACKUP_CONFIG="$(mktemp "$ROOT_DIR/Configs/Local.xcconfig.backup.XXXXXX")"
  cp "$LOCAL_CONFIG" "$BACKUP_CONFIG"
fi

cat > "$LOCAL_CONFIG" <<EOF
// Generated temporarily by scripts/install-personal-team.sh.
// This file is gitignored and is restored/removed when the script exits.
DEVELOPMENT_TEAM = ${TEAM_ID}
CODE_SIGN_STYLE = Automatic
PRODUCT_BUNDLE_IDENTIFIER = ${PERSONAL_BUNDLE_ID}
APP_GROUP_ID = personal.disabled.${SAFE_TEAM_ID}
APP_DISPLAY_NAME = Bitchat IVS Personal
EOF

if [[ ! -f "$ENTITLEMENTS_FILE" ]]; then
  echo "ERROR: Missing $ENTITLEMENTS_FILE" >&2
  exit 2
fi

rm -rf "$DERIVED_DATA" "$EXPORT_DIR"
mkdir -p "$EXPORT_DIR"

printf '\n== Personal Team build ==\n'
printf 'Team ID: %s\n' "$TEAM_ID"
printf 'Device UDID: %s\n' "$DEVICE_UDID"
printf 'Bundle ID: %s\n\n' "$PERSONAL_BUNDLE_ID"

xcodebuild \
  -project bitchat.xcodeproj \
  -scheme "bitchat (iOS)" \
  -configuration Debug \
  -destination "id=${DEVICE_UDID}" \
  -derivedDataPath "$DERIVED_DATA" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Automatic \
  CODE_SIGN_IDENTITY="Apple Development" \
  CODE_SIGN_ENTITLEMENTS="Configs/PersonalTeam.entitlements" \
  -allowProvisioningUpdates \
  clean build

APP_PATH="$(find "$DERIVED_DATA/Build/Products/Debug-iphoneos" -maxdepth 1 -type d -name '*.app' | head -n 1)"
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "ERROR: Built iPhone app was not found." >&2
  exit 1
fi

APP_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Info.plist")"
if [[ "$APP_BUNDLE_ID" != "$PERSONAL_BUNDLE_ID" ]]; then
  echo "ERROR: App bundle ID mismatch: $APP_BUNDLE_ID" >&2
  exit 1
fi

EXT_PATH="$(find "$APP_PATH/PlugIns" -maxdepth 1 -type d -name '*.appex' 2>/dev/null | head -n 1 || true)"
if [[ -n "$EXT_PATH" ]]; then
  EXT_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$EXT_PATH/Info.plist")"
  if [[ "$EXT_BUNDLE_ID" != "$EXPECTED_EXTENSION_BUNDLE_ID" ]]; then
    echo "ERROR: Share Extension bundle ID mismatch: $EXT_BUNDLE_ID" >&2
    exit 1
  fi
fi

codesign --verify --deep --strict --verbose=2 "$APP_PATH"

APP_ENTITLEMENTS="$(mktemp)"
codesign -d --entitlements :- "$APP_PATH" 2>/dev/null > "$APP_ENTITLEMENTS" || true
if grep -q 'com.apple.security.application-groups' "$APP_ENTITLEMENTS"; then
  echo "ERROR: App Group entitlement is still present in the Personal Team build." >&2
  rm -f "$APP_ENTITLEMENTS"
  exit 1
fi
rm -f "$APP_ENTITLEMENTS"

if [[ -n "$EXT_PATH" ]]; then
  EXT_ENTITLEMENTS="$(mktemp)"
  codesign -d --entitlements :- "$EXT_PATH" 2>/dev/null > "$EXT_ENTITLEMENTS" || true
  if grep -q 'com.apple.security.application-groups' "$EXT_ENTITLEMENTS"; then
    echo "ERROR: Share Extension App Group entitlement is still present." >&2
    rm -f "$EXT_ENTITLEMENTS"
    exit 1
  fi
  rm -f "$EXT_ENTITLEMENTS"
fi

mkdir -p "$EXPORT_DIR/Payload"
ditto "$APP_PATH" "$EXPORT_DIR/Payload/$(basename "$APP_PATH")"
(
  cd "$EXPORT_DIR"
  /usr/bin/zip -qry "$(basename "$IPA_PATH")" Payload
)
rm -rf "$EXPORT_DIR/Payload"

if [[ ! -s "$IPA_PATH" ]]; then
  echo "ERROR: IPA packaging failed." >&2
  exit 1
fi

printf '\n== Installing on iPhone ==\n'
xcrun devicectl device install app --device "$DEVICE_UDID" "$APP_PATH"

printf '\nSUCCESS\n'
printf 'Installed bundle: %s\n' "$APP_BUNDLE_ID"
printf 'Signed app: %s\n' "$APP_PATH"
printf 'IPA copy: %s\n' "$IPA_PATH"
printf '\nPersonal Team provisioning is temporary; reinstall/re-sign when the free provisioning expires.\n'
