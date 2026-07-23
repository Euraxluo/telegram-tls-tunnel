#!/usr/bin/env bash
# Idempotent installer for telegram-tls-tunnel (macOS).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${TELEGRAM_TLS_TUNNEL_BIN_DIR:-$HOME/.local/bin}"
CFG_DIR="${TELEGRAM_TLS_TUNNEL_CONFIG_DIR:-$HOME/.config/telegram-tls-tunnel}"
APP_DIR="${TELEGRAM_TLS_TUNNEL_APP_DIR:-$HOME/Applications/TelegramProxy.app}"
mkdir -p "$BIN_DIR" "$CFG_DIR" "$(dirname "$APP_DIR")"

# Preserve legacy hard-coded script for one-shot config migration
if [[ -f "$BIN_DIR/telegram_tls_tunnel.py" ]] && grep -q '^REMOTE_HOST' "$BIN_DIR/telegram_tls_tunnel.py" 2>/dev/null; then
  cp "$BIN_DIR/telegram_tls_tunnel.py" /tmp/telegram_tls_tunnel.legacy.py
fi

install -m 755 "$ROOT/bin/telegram_tls_tunnel.py" "$BIN_DIR/telegram_tls_tunnel.py"
install -m 755 "$ROOT/bin/start_telegram_with_tunnel.sh" "$BIN_DIR/start_telegram_with_tunnel.sh"

# App bundle (without shipping Telegram's trademarked icon in git)
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
install -m 644 "$ROOT/app/TelegramProxy.app/Contents/Info.plist" "$APP_DIR/Contents/Info.plist"
install -m 755 "$ROOT/app/TelegramProxy.app/Contents/MacOS/launch" "$APP_DIR/Contents/MacOS/launch"

ICON_SRC="/Applications/Telegram.app/Contents/Resources/AppIcon.icns"
if [[ -f "$ICON_SRC" ]]; then
  cp "$ICON_SRC" "$APP_DIR/Contents/Resources/AppIcon.icns"
  echo "icon:    copied from Telegram.app"
elif [[ -f "$HOME/Applications/TelegramProxy.app/Contents/Resources/AppIcon.icns" ]]; then
  # already had one from a previous local install path — rare during rm -rf above
  true
else
  echo "icon:    skipped (Telegram.app not found — app still works)"
fi

# Config: never overwrite existing
CFG="$CFG_DIR/config.json"
if [[ -f "$CFG" ]]; then
  echo "config:  kept existing $CFG"
else
  python3 - "$ROOT/config.example.json" "$CFG" <<'PY'
import json, pathlib, re, sys
example, dest = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
data = json.loads(example.read_text())

# Migrate hard-coded REMOTE_* from a legacy tunnel script if present
legacy = pathlib.Path.home() / ".local/bin/telegram_tls_tunnel.py"
# Also check the source tree isn't the only copy — prefer home legacy before we overwrite it.
# install already copied new script; read from /tmp backup if we saved one.
for candidate in (
    pathlib.Path("/tmp/telegram_tls_tunnel.legacy.py"),
    pathlib.Path.home() / ".config/telegram-tls-tunnel/legacy_tunnel.py",
):
    if candidate.is_file():
        legacy = candidate
        break

text = legacy.read_text() if legacy.is_file() else ""
host = re.search(r'^REMOTE_HOST\s*=\s*"([^"]+)"', text, re.M)
port = re.search(r'^REMOTE_PORT\s*=\s*(\d+)', text, re.M)
if host:
    data["remote"]["host"] = host.group(1)
if port:
    data["remote"]["port"] = int(port.group(1))

dest.parent.mkdir(parents=True, exist_ok=True)
dest.write_text(json.dumps(data, indent=2) + "\n")
if host:
    print(f"config:  migrated remote {data['remote']['host']}:{data['remote']['port']} -> {dest}")
else:
    print(f"config:  wrote {dest} (edit remote.host)")
PY
fi

# Clear quarantine so double-click works
xattr -dr com.apple.quarantine "$APP_DIR" 2>/dev/null || true

echo "installed:"
echo "  $BIN_DIR/telegram_tls_tunnel.py"
echo "  $BIN_DIR/start_telegram_with_tunnel.sh"
echo "  $APP_DIR"
echo "  $CFG"
echo
echo "next:"
echo "  1) edit $CFG  (set remote.host / port)"
echo "  2) open $APP_DIR  (or: open -a TelegramProxy)"
echo "  3) Telegram → Settings → Advanced → Connection type →"
echo "     SOCKS5 127.0.0.1:1080 + your subscription user/pass"
echo
echo "re-run ./install.sh anytime (idempotent; config not overwritten)"
