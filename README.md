# EditIE — GUMS Office Automation Configuration

Batch entry point with PowerShell helpers for Microsoft Edge IE Mode and per-user Internet Options (Trusted Sites, TLS / `SecureProtocols`, WinHTTP, optional legacy Schannel).

## Files

| Path | Role |
|------|------|
| `Enable-IEMode and IO setup.bat` | Main menu (run as user; self-elevates for HKLM) |
| `scripts/EditIE-Core.ps1` | Registry helpers, backup/restore, TLS bitmask, logging |
| `scripts/Save-LaunchContext.ps1` | Stores launching user SID before UAC |
| `scripts/Invoke-EdgeSettings.ps1` | Option 1 — Edge IE Mode site list |
| `scripts/Invoke-InternetSettings.ps1` | Option 2 / 2L — Internet Options |
| `scripts/Invoke-RestoreSettings.ps1` | Option 3 — restore from backup |

Data written on target PCs:

- `C:\IEMode\sites.xml`, `C:\IEMode\logs\`, `C:\IEMode\backup\backup_<UserSid>.json`
- `%ProgramData%\GUMS-EditIE\launcher-context.json`

## Windows verification (manual)

Not run in CI (Linux agents have no Windows registry). On each scenario:

1. Run the `.bat` as the target user (not as SYSTEM unless you accept documented limits).
2. After option **2** or **2L**, run `inetcpl.cpl` → **Advanced** → **Security** protocols.
3. Compare checkboxes to the summary line `SecureProtocols mask` in the latest log under `C:\IEMode\logs\`.
4. Confirm Trusted Sites: **Security** → **Trusted sites** → **Sites** (`*.gums.ac.ir` hosts).
5. Option **3** should revert to values in `C:\IEMode\backup\backup_<Sid>.json`.

### Scenarios to cover

| # | Scenario |
|---|----------|
| 1 | Windows 10, Administrator |
| 2 | Windows 10, Standard user + UAC |
| 3 | Windows 11, Administrator |
| 4 | Windows 11, Standard user + UAC |
| 5 | Domain member with GPO `SecureProtocols` → expect exit code **3**, **Blocked** in log |
| 6 | Run elevated while another user is logged on → confirm `launcher-context.json` SID matches logged-on user |
| 7 | SYSTEM / SCCM → expect error if interactive user / loaded hive cannot be resolved |
| 8 | OS without TLS 1.3 → log **SKIP** for TLS 1.3; bitmask excludes `0x2000` |

### Exit codes (Internet Options script)

| Code | Meaning |
|------|---------|
| 0 | All required settings applied |
| 1 | Fatal error (user hive, I/O, etc.) |
| 2 | One or more required operations failed |
| 3 | Partial success — GPO blocks `SecureProtocols` |
| 4 | Partial restore — user HKU restored; HKLM/sites skipped (owner mismatch or no machine backup) |

## Automated tests (logic only — no Windows registry)

```bash
python3 tests/test_editie_logic.py
```

On Windows, also run:

```powershell
powershell -NoProfile -File tests\Run-EditIELogicTests.ps1
```

These cover TLS 1.3 assessment, launch-context TTL, exit-code rules, and policy path helpers. **Registry I/O, GPO, Advanced UI, and multi-user restore require manual Windows verification** (see scenario matrix above).

## Security notes

- **Modern (2)** enables TLS 1.2 + TLS 1.3 (when supported) only; does **not** change Schannel or disable certificate revocation.
- **Legacy (2L)** enables weak protocols and Schannel client keys for compatibility with older GUMS servers — use only when required.
- Previous versions incorrectly set WinTrust `State` to `146432` while commenting “disable certificate checks”; that value actually corresponds to publisher revocation **enabled** per Microsoft KB. WinTrust is no longer modified by default.
