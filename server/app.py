#!/usr/bin/env python3
"""EditIE install telemetry receiver."""

from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from pathlib import Path

from flask import Flask, jsonify, request

APP = Flask(__name__)
LOG_DIR = Path(os.environ.get("EDITIE_LOG_DIR", "/var/log/editie"))
LOG_FILE = LOG_DIR / "installs.jsonl"


def append_record(record: dict) -> None:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    with LOG_FILE.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record, ensure_ascii=False) + "\n")


@APP.get("/health")
def health():
    return jsonify({"status": "ok"})


@APP.post("/api/install")
def install():
    payload = request.get_json(silent=True) or {}

    record = {
        "received_at": datetime.now(timezone.utc).isoformat(),
        "client_ip": request.headers.get("X-Forwarded-For", request.remote_addr),
        "install_id": payload.get("installId"),
        "computer_name": payload.get("computerName"),
        "windows_version": payload.get("windowsVersion"),
        "script_version": payload.get("version"),
        "installed_at": payload.get("installedAt"),
    }

    append_record(record)
    return jsonify({"ok": True})


if __name__ == "__main__":
    host = os.environ.get("EDITIE_HOST", "0.0.0.0")
    port = int(os.environ.get("EDITIE_PORT", "8080"))
    APP.run(host=host, port=port)
