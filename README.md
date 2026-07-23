# telegram-tls-tunnel

为 Telegram macOS 原生版提供 **TLS 包装的 SOCKS5** 本地隧道。

Telegram 内置 SOCKS5/HTTP 客户端无法给上游加 TLS，而很多机场节点要求 `tls: true`。本项目在本机监听明文 `127.0.0.1:1080`，内部通过 TLS 连到远程代理节点并双向转发。

不依赖 Clash / 重客户端；隧道与 Telegram 联动启停（**非**开机自启 / Login Item）。

## 功能概览

- 本地明文 SOCKS5（默认 `127.0.0.1:1080`）→ 远程 **SOCKS5 over TLS**
- `TelegramProxy.app` 与 Telegram 同生命周期：开 Telegram 启隧道，退出 Telegram 停隧道
- PID 文件防止重复启动隧道；已有隧道时再点 App 只唤起 Telegram
- 通过 `tg://socks?...` 深度链接**自动注入** Telegram 代理设置（凭据来自配置文件）

## 安装

```bash
git clone https://github.com/Euraxluo/telegram-tls-tunnel.git
cd telegram-tls-tunnel
./install.sh
```

幂等安装。写入：

| 路径 | 用途 |
|------|------|
| `~/.local/bin/telegram_tls_tunnel.py` | TLS 隧道（`-c` 读配置） |
| `~/.local/bin/start_telegram_with_tunnel.sh` | CLI 启动器 |
| `~/Applications/TelegramProxy.app` | 双击启动器 |
| `~/.config/telegram-tls-tunnel/config.json` | 远程节点 + SOCKS 凭据（仅首次创建） |

编辑配置（**不要**把真实 `config.json` 提交进 git）：

```bash
$EDITOR ~/.config/telegram-tls-tunnel/config.json
```

示例（占位符）：

```json
{
  "local": { "host": "127.0.0.1", "port": 1080 },
  "remote": {
    "host": "your-node.example.com",
    "port": 443,
    "verify_tls": false,
    "server_name": null
  },
  "socks": {
    "server": "127.0.0.1",
    "port": 1080,
    "user": "YOUR_SUBSCRIPTION_UUID",
    "pass": "YOUR_SUBSCRIPTION_UUID"
  }
}
```

然后打开 **Telegram (带代理)** / `TelegramProxy.app`。若配置了 `socks.user` / `socks.pass`，启动约 3 秒后会自动打开：

```text
tg://socks?server=127.0.0.1&port=1080&user=...&pass=...
```

Telegram 会据此写入连接类型为 SOCKS5 的代理。也可手动设置：

- Connection type: **SOCKS5**
- Server: `127.0.0.1`
- Port: `1080`
- User / password: 订阅 UUID（与节点 YAML 一致）

## 卸载

```bash
./uninstall.sh          # 移除 binaries + app，保留配置
./uninstall.sh --purge  # 同时删除 ~/.config/telegram-tls-tunnel/
```

## 工作原理

1. `telegram_tls_tunnel.py -c config.json` 在本地明文 TCP 上监听。
2. 每个入站连接向 `remote.host:remote.port` 建立 TLS，再双向 relay。
3. SOCKS5 握手发生在 TLS 隧道**内部**。
4. `TelegramProxy.app` / CLI 启动器启动隧道、打开 Telegram，并在 Telegram 退出后结束隧道。
5. 若配置含 `socks.user` / `socks.pass`，启动器通过 `tg://socks` 深度链接注入代理。

路径约定（可用环境变量覆盖）：

| 变量 | 默认 |
|------|------|
| `TELEGRAM_TLS_TUNNEL_BIN` | `~/.local/bin/telegram_tls_tunnel.py` |
| `TELEGRAM_TLS_TUNNEL_CONFIG` | `~/.config/telegram-tls-tunnel/config.json` |
| `TELEGRAM_TLS_TUNNEL_PID` | `/tmp/telegram_tls_tunnel.pid` |

## 仓库结构

```text
bin/telegram_tls_tunnel.py
bin/start_telegram_with_tunnel.sh
app/TelegramProxy.app/Contents/Info.plist
app/TelegramProxy.app/Contents/MacOS/launch
config.example.json          # 仅占位符；真实 config.json 不入库
install.sh
uninstall.sh
```

`AppIcon.icns` 不入库（Telegram 商标资源）。`install.sh` 会从 `/Applications/Telegram.app` 复制图标。

## 要求

- macOS
- Python 3（系统 `/usr/bin/python3` 即可，无额外 pip 依赖）
- 已安装 `Telegram.app`

## License

MIT
