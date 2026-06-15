#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="TidyDrop"
BUNDLE_ID="app.tidydrop.TidyDrop"
MIN_SYSTEM_VERSION="26.0"
DIST_DIR="$ROOT_DIR/dist"
RUNTIME_DIR="$HOME/.tidydrop/runtime"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

cd "$ROOT_DIR"

stop_app() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  pkill -x "TidyDropBackend" >/dev/null 2>&1 || true
  rm -f "$RUNTIME_DIR"/session-*.json
}

find_python() {
  local candidates=()
  if [[ -n "${PYTHON_BIN:-}" ]]; then
    candidates+=("$PYTHON_BIN")
  fi
  candidates+=(
    "python3.12"
    "python3.11"
    "/opt/homebrew/bin/python3.12"
    "/opt/homebrew/bin/python3.11"
    "/usr/local/bin/python3.12"
    "/usr/local/bin/python3.11"
    "python3"
  )

  for candidate in "${candidates[@]}"; do
    if command -v "$candidate" >/dev/null 2>&1; then
      local resolved
      resolved="$(command -v "$candidate")"
      if "$resolved" - <<'PY' >/dev/null 2>&1
import sys
raise SystemExit(0 if sys.version_info >= (3, 11) else 1)
PY
      then
        echo "$resolved"
        return 0
      fi
    elif [[ -x "$candidate" ]]; then
      if "$candidate" - <<'PY' >/dev/null 2>&1
import sys
raise SystemExit(0 if sys.version_info >= (3, 11) else 1)
PY
      then
        echo "$candidate"
        return 0
      fi
    fi
  done

  return 1
}

ensure_backend_env() {
  if [[ -x .venv/bin/python ]]; then
    if .venv/bin/python - <<'PY' >/dev/null 2>&1
import sys
raise SystemExit(0 if sys.version_info >= (3, 11) else 1)
PY
    then
      if ! .venv/bin/python -c "import uvicorn, fastapi" >/dev/null 2>&1; then
        .venv/bin/python -m pip install -e ".[dev]"
      fi
      return
    fi
    rm -rf .venv
  fi

  local python
  if ! python="$(find_python)"; then
    echo "Python 3.11+ is required to create the local backend environment." >&2
    exit 1
  fi
  "$python" -m venv .venv

  .venv/bin/python -m pip install --upgrade pip
  .venv/bin/python -m pip install -e ".[dev]"
}

build_app() {
  ensure_backend_env
  swift build
  local build_binary
  build_binary="$(swift build --show-bin-path)/$APP_NAME"

  rm -rf "$APP_BUNDLE"
  mkdir -p "$APP_MACOS" "$APP_RESOURCES"
  cp "$build_binary" "$APP_BINARY"
  cp "$ROOT_DIR/Assets/TidyDrop.icns" "$APP_RESOURCES/TidyDrop.icns"
  chmod +x "$APP_BINARY"

  cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key>
  <string>TidyDrop.icns</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
  </dict>
</dict>
</plist>
PLIST
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    stop_app
    build_app
    open_app
    ;;
  --debug|debug)
    stop_app
    build_app
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs|--telemetry|telemetry)
    stop_app
    build_app
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --verify|verify)
    stop_app
    build_app
    open_app
    for _ in {1..180}; do
      session_file="$(find "$RUNTIME_DIR" -name 'session-*.json' -type f -print 2>/dev/null | head -n 1 || true)"
      if [[ -n "$session_file" && -f "$session_file" ]]; then
        port="$(SESSION_FILE="$session_file" .venv/bin/python -c 'import json, os; print(json.load(open(os.environ["SESSION_FILE"]))["port"])' 2>/dev/null || true)"
        token="$(SESSION_FILE="$session_file" .venv/bin/python -c 'import json, os; print(json.load(open(os.environ["SESSION_FILE"]))["token"])' 2>/dev/null || true)"
        if [[ -n "$port" && -n "$token" ]] &&
          curl -fsS -H "Authorization: Bearer $token" "http://127.0.0.1:$port/api/health" >/dev/null 2>&1; then
          exit 0
        fi
      fi
      sleep 0.5
    done
    echo "$APP_NAME did not publish a healthy authenticated backend session." >&2
    exit 1
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
