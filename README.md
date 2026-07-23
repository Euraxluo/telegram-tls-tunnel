# telegram-tls-tunnel

Local plain SOCKS5 → remote **SOCKS5 over TLS** tunnel for Telegram on macOS.

Telegram’s built-in SOCKS5/HTTP client cannot wrap the hop in TLS. Many airport nodes require `tls: true`. This project listens on `127.0.0.1:1080` (plain), opens a TLS connection to the remote node, and relays bytes both ways.

No Clash / heavy client — tunnel follows the app lifecycle (not a login item).

## Install

```bash
git clone https://github.com/Euraxluo/telegram-tls-tunnel.git
cd telegram-tls-tunnel
./install.sh
```

Idempotent. Writes:

| Path | Purpose |
|------|---------|
| `~/.local/bin/telegram_tls_tunnel.py` | TLS tunnel |
| `~/.local/bin/start_telegram_with_tunnel.sh` | CLI launcher |
| `~/Applications/TelegramProxy.app` | double-click launcher |
| `~/.config/telegram-tls-tunnel/config.json` | remote host/port (created once) |

Edit the config:

```bash
$EDITOR ~/.config/telegram-tls-tunnel/config.json
```

```json
{
  "local": { "host": "127.0.0.1", "port": 1080 },
  "remote": {
    "host": "your-node.example.com",
    "port": 443,
    "verify_tls": false
  }
}
```

Then open **Telegram (带代理)** / `TelegramProxy.app`, and in Telegram:

- Connection type: **SOCKS5**
- Server: `127.0.0.1`
- Port: `1080`
- User / password: your subscription UUID (from the YAML node)

## Uninstall

```bash
./uninstall.sh          # remove binaries + app, keep config
./uninstall.sh --purge  # also delete ~/.config/telegram-tls-tunnel/
```

## How it works

1. `telegram_tls_tunnel.py` listens on local plain TCP.
2. Each inbound connection opens a TLS session to `remote.host:remote.port`.
3. Bidirectional relay; SOCKS5 handshake happens *inside* the TLS tunnel.
4. `TelegramProxy.app` starts the tunnel, opens Telegram, and kills the tunnel when Telegram exits. Re-launch while tunnel is up only opens Telegram.

## Layout

```
bin/telegram_tls_tunnel.py
bin/start_telegram_with_tunnel.sh
app/TelegramProxy.app/Contents/...
config.example.json
install.sh
uninstall.sh
```

Icon is copied from `/Applications/Telegram.app` at install time (not shipped in git).

## Requirements

- macOS
- Python 3 (system `/usr/bin/python3` is fine)
- Telegram.app installed

## License

MIT
