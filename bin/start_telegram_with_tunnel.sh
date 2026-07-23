#!/bin/bash
# Start TLS tunnel alongside Telegram (CLI fallback).
# Tunnel starts when Telegram launches, stops when Telegram quits.

set -euo pipefail

TUNNEL_SCRIPT="${TELEGRAM_TLS_TUNNEL_BIN:-$HOME/.local/bin/telegram_tls_tunnel.py}"
CONFIG="${TELEGRAM_TLS_TUNNEL_CONFIG:-$HOME/.config/telegram-tls-tunnel/config.json}"
TUNNEL_PID=""

cleanup() {
    if [ -n "${TUNNEL_PID}" ] && kill -0 "$TUNNEL_PID" 2>/dev/null; then
        kill "$TUNNEL_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# Build tg://socks deep link from config (never hard-code credentials here).
socks_deep_link() {
    /usr/bin/python3 - "$CONFIG" <<'PY'
import json, sys, urllib.parse
from pathlib import Path

path = Path(sys.argv[1]).expanduser()
if not path.is_file():
    sys.exit(0)
data = json.loads(path.read_text())
local = data.get("local") or {}
socks = data.get("socks") or {}
server = socks.get("server") or local.get("host") or "127.0.0.1"
port = int(socks.get("port") or local.get("port") or 1080)
user = socks.get("user") or ""
password = socks.get("pass") or ""
if not user or not password:
    sys.exit(0)
qs = urllib.parse.urlencode(
    {"server": server, "port": port, "user": user, "pass": password}
)
print(f"tg://socks?{qs}")
PY
}

/usr/bin/python3 "$TUNNEL_SCRIPT" -c "$CONFIG" &
TUNNEL_PID=$!
sleep 0.5

open -a "Telegram"

SOCKS_URL="$(socks_deep_link || true)"
if [ -n "${SOCKS_URL:-}" ]; then
    sleep 3
    open "$SOCKS_URL"
fi

while pgrep -x "Telegram" > /dev/null 2>&1; do
    sleep 2
done
