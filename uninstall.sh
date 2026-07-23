#!/usr/bin/env bash
# Idempotent uninstaller for telegram-tls-tunnel.
# default: remove binaries + app, keep config
# --purge: also delete ~/.config/telegram-tls-tunnel/
set -euo pipefail

BIN_DIR="${TELEGRAM_TLS_TUNNEL_BIN_DIR:-$HOME/.local/bin}"
CFG_DIR="${TELEGRAM_TLS_TUNNEL_CONFIG_DIR:-$HOME/.config/telegram-tls-tunnel}"
APP_DIR="${TELEGRAM_TLS_TUNNEL_APP_DIR:-$HOME/Applications/TelegramProxy.app}"
PID_FILE="${TELEGRAM_TLS_TUNNEL_PID:-/tmp/telegram_tls_tunnel.pid}"
PURGE=0

for arg in "$@"; do
  case "$arg" in
    --purge) PURGE=1 ;;
    -h|--help)
      cat <<'EOF'
uninstall.sh [--purge]

  Removes tunnel binaries and TelegramProxy.app.
  Idempotent / safe to re-run.

  --purge   also delete ~/.config/telegram-tls-tunnel/
EOF
      exit 0
      ;;
    *)
      echo "unknown arg: $arg" >&2
      exit 2
      ;;
  esac
done

# Stop running tunnel if we own the pid file
if [[ -f "$PID_FILE" ]]; then
  pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    echo "stopped: tunnel pid $pid"
  fi
  rm -f "$PID_FILE"
fi

rm -f "$BIN_DIR/telegram_tls_tunnel.py" "$BIN_DIR/start_telegram_with_tunnel.sh"
echo "removed: binaries in $BIN_DIR"

if [[ -d "$APP_DIR" ]]; then
  rm -rf "$APP_DIR"
  echo "removed: $APP_DIR"
else
  echo "already clean: app"
fi

if (( PURGE )); then
  if [[ -d "$CFG_DIR" ]]; then
    rm -rf "$CFG_DIR"
    echo "purged:  $CFG_DIR"
  else
    echo "no config dir to purge"
  fi
else
  echo "kept:    $CFG_DIR  (pass --purge to delete)"
fi

echo
echo "verify leftovers:"
left=0
[[ -e "$BIN_DIR/telegram_tls_tunnel.py" ]] && { echo "  residual binary"; left=1; }
[[ -e "$APP_DIR" ]] && { echo "  residual app"; left=1; }
if (( PURGE )); then
  [[ -e "$CFG_DIR" ]] && { echo "  residual config"; left=1; }
fi
(( left == 0 )) && echo "  tool install: clean"
echo
echo "done. Telegram itself and its in-app proxy settings are untouched."
