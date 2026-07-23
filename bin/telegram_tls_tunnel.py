#!/usr/bin/env python3
"""
Lightweight TLS tunnel for SOCKS5 proxy.

Listens on a local plain TCP port, wraps each connection in TLS to a remote
SOCKS5-over-TLS proxy. Telegram (or any SOCKS5 client) connects locally;
this process peels TLS for the remote hop.
"""

from __future__ import annotations

import argparse
import json
import os
import signal
import socket
import ssl
import sys
import threading
from pathlib import Path

DEFAULT_CONFIG = Path.home() / ".config" / "telegram-tls-tunnel" / "config.json"


def load_config(path: Path) -> dict:
    if not path.is_file():
        raise SystemExit(
            f"config not found: {path}\n"
            f"copy config.example.json -> {path} and edit remote.host"
        )
    with path.open() as f:
        data = json.load(f)
    local = data.get("local") or {}
    remote = data.get("remote") or {}
    if not remote.get("host"):
        raise SystemExit(f"remote.host missing in {path}")
    return {
        "local_host": local.get("host", "127.0.0.1"),
        "local_port": int(local.get("port", 1080)),
        "remote_host": remote["host"],
        "remote_port": int(remote.get("port", 443)),
        "verify_tls": bool(remote.get("verify_tls", False)),
        "server_name": remote.get("server_name") or remote["host"],
    }


def relay(src: socket.socket, dst: socket.socket) -> None:
    try:
        while True:
            data = src.recv(4096)
            if not data:
                break
            dst.sendall(data)
    except Exception:
        pass
    finally:
        for s in (src, dst):
            try:
                s.close()
            except Exception:
                pass


def handle_client(client_sock: socket.socket, cfg: dict) -> None:
    try:
        context = ssl.create_default_context()
        if not cfg["verify_tls"]:
            context.check_hostname = False
            context.verify_mode = ssl.CERT_NONE
        remote_sock = socket.create_connection(
            (cfg["remote_host"], cfg["remote_port"]), timeout=10
        )
        tls_sock = context.wrap_socket(
            remote_sock, server_hostname=cfg["server_name"]
        )
        t1 = threading.Thread(target=relay, args=(client_sock, tls_sock), daemon=True)
        t2 = threading.Thread(target=relay, args=(tls_sock, client_sock), daemon=True)
        t1.start()
        t2.start()
        t1.join()
        t2.join()
    except Exception as e:
        print(f"[!] Connection error: {e}", file=sys.stderr)
    finally:
        try:
            client_sock.close()
        except Exception:
            pass


def main() -> None:
    parser = argparse.ArgumentParser(description="Telegram / SOCKS5 TLS tunnel")
    parser.add_argument(
        "-c",
        "--config",
        default=os.environ.get("TELEGRAM_TLS_TUNNEL_CONFIG", str(DEFAULT_CONFIG)),
        help="path to config.json",
    )
    args = parser.parse_args()
    cfg = load_config(Path(args.config).expanduser())

    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((cfg["local_host"], cfg["local_port"]))
    server.listen(128)
    print(f"[*] TLS tunnel listening on {cfg['local_host']}:{cfg['local_port']}")
    print(f"[*] Forwarding to {cfg['remote_host']}:{cfg['remote_port']} (TLS)")
    print(f"[*] Telegram SOCKS5 -> {cfg['local_host']}:{cfg['local_port']}")
    sys.stdout.flush()

    def shutdown(sig, frame):
        print("\n[*] Shutting down...")
        try:
            server.close()
        except Exception:
            pass
        sys.exit(0)

    signal.signal(signal.SIGINT, shutdown)
    signal.signal(signal.SIGTERM, shutdown)

    while True:
        try:
            client_sock, _addr = server.accept()
            threading.Thread(
                target=handle_client, args=(client_sock, cfg), daemon=True
            ).start()
        except Exception:
            break


if __name__ == "__main__":
    main()
