#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="${EDITIE_LOG_DIR:-/var/log/editie}/installs.jsonl"

if [[ ! -f "${LOG_FILE}" ]]; then
  echo "No installs logged yet (${LOG_FILE})"
  exit 0
fi

python3 - "${LOG_FILE}" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
rows = []
for line in path.read_text(encoding="utf-8").splitlines():
    line = line.strip()
    if line:
        rows.append(json.loads(line))

unique = {}
for row in rows:
    key = row.get("install_id") or row.get("computer_name")
    unique[key] = row

print(f"Total reports received : {len(rows)}")
print(f"Unique installations   : {len(unique)}")
print()
print(f"{'IP':<18} {'Computer':<20} {'Windows':<30} {'Received'}")
print("-" * 95)
for row in sorted(unique.values(), key=lambda r: r.get("received_at", "")):
    print(
        f"{row.get('client_ip', '-'):<18} "
        f"{row.get('computer_name', '-'):<20} "
        f"{(row.get('windows_version') or '-')[:28]:<30} "
        f"{row.get('received_at', '-')}"
    )
PY
