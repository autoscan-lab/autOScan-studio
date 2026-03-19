#!/bin/sh

set -eu

script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
default_engine_repo="$repo_root/../autOScan-engine"
default_bridge_path="$default_engine_repo/dist/autoscan-bridge"
destination_path="${TARGET_BUILD_DIR}/${EXECUTABLE_FOLDER_PATH}/autoscan-bridge"

log() {
  printf '%s\n' "$1"
}

resolve_bridge_path() {
  if [ -n "${AUTOSCAN_BRIDGE_SOURCE_PATH:-}" ] && [ -x "${AUTOSCAN_BRIDGE_SOURCE_PATH}" ]; then
    printf '%s\n' "${AUTOSCAN_BRIDGE_SOURCE_PATH}"
    return 0
  fi

  if [ -x "$default_bridge_path" ]; then
    printf '%s\n' "$default_bridge_path"
    return 0
  fi

  if [ -x "$default_engine_repo/autoscan-bridge" ]; then
    printf '%s\n' "$default_engine_repo/autoscan-bridge"
    return 0
  fi

  return 1
}

build_default_bridge() {
  if [ ! -d "$default_engine_repo" ]; then
    return 1
  fi

  log "Building autoscan-bridge from $default_engine_repo"

  if command -v make >/dev/null 2>&1; then
    (
      cd "$default_engine_repo"
      make build-bridge
    )
    return 0
  fi

  if command -v go >/dev/null 2>&1; then
    (
      cd "$default_engine_repo"
      mkdir -p dist
      go build -o dist/autoscan-bridge ./cmd/autoscan-bridge
    )
    return 0
  fi

  return 1
}

bridge_path=""
if resolved_path="$(resolve_bridge_path)"; then
  bridge_path="$resolved_path"
elif build_default_bridge && resolved_path="$(resolve_bridge_path)"; then
  bridge_path="$resolved_path"
else
  log "error: autoscan-bridge was not found."
  log "error: Set AUTOSCAN_BRIDGE_SOURCE_PATH or build ../autOScan-engine/dist/autoscan-bridge before building Studio."
  exit 1
fi

mkdir -p "$(dirname "$destination_path")"
rm -f "$destination_path"
ditto "$bridge_path" "$destination_path"
chmod 755 "$destination_path"

if [ "${CODE_SIGNING_ALLOWED:-NO}" = "YES" ] && [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
  /usr/bin/codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" --timestamp=none --generate-entitlement-der "$destination_path"
fi

log "Embedded autoscan-bridge from $bridge_path"
