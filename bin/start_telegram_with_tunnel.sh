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

/usr/bin/python3 "$TUNNEL_SCRIPT" -c "$CONFIG" &
TUNNEL_PID=$!
sleep 0.5

open -a "Telegram"

while pgrep -x "Telegram" > /dev/null 2>&1; do
    sleep 2
done
