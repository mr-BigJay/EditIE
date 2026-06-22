# EditIE

Windows batch utility for configuring Microsoft Edge IE Mode and Internet Options for GUMS office automation sites.

## Opt-in installation statistics

On first run, users are asked whether they agree to send a **one-time anonymous report** to the internal IT server. This helps track how many systems have installed the tool.

- **Default:** No data is sent unless the user explicitly chooses "Yes".
- **Data collected:** Random install ID, script version, Windows version.
- **No personal information** (username, hostname, IP, etc.) is included.

### Configuration

Before distributing, set your server endpoint in the batch file:

```batch
set TELEMETRY_URL=https://YOUR-SERVER.example.com/api/install
```

The server should accept a `POST` request with JSON body:

```json
{
  "installId": "guid",
  "version": "1.0.0",
  "os": "Microsoft Windows 10 Pro"
}
```

User preference is stored in `HKCU\Software\GUMS\EditIE`.
