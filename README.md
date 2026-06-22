# EditIE

Windows batch utility for configuring Microsoft Edge IE Mode and Internet Options for GUMS office automation sites.

## Opt-in installation statistics

On first run, users are asked whether they agree to send a **one-time report** to the IT server when the system is online.

- **Default:** No data is sent unless the user explicitly chooses "Yes".
- **Offline / VPN support:** Report is saved locally at `C:\IEMode\telemetry_pending.json`. A Windows scheduled task runs when:
  - **A new network connects** (including OpenVPN TAP adapter)
  - **Windows VPN (RAS) connects**
  - **User logs on** (if VPN auto-connects at login)
- Before sending, the script checks that `http://185.252.200.112:8080/health` is reachable — so it only sends when the server is actually available through VPN.

### Optional: instant send on OpenVPN connect

If you manage OpenVPN configs centrally, add these lines to each `.ovpn` file:

```
script-security 2
up "C:\\IEMode\\vpn-send.cmd"
```

The batch file creates `C:\IEMode\vpn-send.cmd` automatically when the user opts in. This sends the report immediately when OpenVPN connects (in addition to the Windows network event trigger).
- **Data collected:** Computer name, Windows version, script version. Server also records sender IP.

---

## Server setup (Ubuntu 24)

Server IP: `185.252.200.112` — API port: `8080`

### 1. Copy server files to Ubuntu

From your PC, copy the `server/` folder to the Ubuntu server:

```bash
scp -r server/ root@185.252.200.112:/root/editie-server/
```

### 2. Run setup script

SSH into the server and run:

```bash
ssh root@185.252.200.112
cd /root/editie-server
chmod +x setup.sh view-installs.sh
bash setup.sh
```

### 3. Verify it works

```bash
curl http://127.0.0.1:8080/health
```

Expected response: `{"status":"ok"}`

Test install endpoint:

```bash
curl -X POST http://127.0.0.1:8080/api/install \
  -H "Content-Type: application/json" \
  -d '{"installId":"test-1","computerName":"PC-TEST","windowsVersion":"Windows 10 Pro","version":"1.0.0","installedAt":"2026-06-22T10:00:00Z"}'
```

### 4. View installations

```bash
bash /root/editie-server/view-installs.sh
```

Or read raw logs:

```bash
tail -f /var/log/editie/installs.jsonl
```

Each line is one JSON record:

```json
{
  "received_at": "2026-06-22T10:05:00+00:00",
  "client_ip": "1.2.3.4",
  "install_id": "guid",
  "computer_name": "DESKTOP-ABC",
  "windows_version": "Microsoft Windows 10 Pro",
  "script_version": "1.0.0",
  "installed_at": "2026-06-22T09:58:00.0000000Z"
}
```

### 5. Firewall (if enabled)

```bash
ufw allow 8080/tcp
ufw status
```

### Service management

```bash
systemctl status editie-telemetry
systemctl restart editie-telemetry
journalctl -u editie-telemetry -f
```

---

## Client configuration

The batch file is preconfigured with:

```batch
set TELEMETRY_URL=http://185.252.200.112:8080/api/install
```

User preference is stored in `HKCU\Software\GUMS\EditIE`.
