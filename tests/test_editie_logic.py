#!/usr/bin/env python3
"""Logic tests mirroring EditIE-Logic.ps1 (Linux CI)."""

import sys
from datetime import datetime, timedelta, timezone


def tls13_assessment(
    os_build,
    is_win11,
    crypto_ui,
    schannel_enabled,
    schannel_disabled_by_default,
    schannel_key_exists,
):
    if os_build < 19041:
        return "Unsupported"
    if schannel_key_exists and schannel_enabled == 0:
        return "Unsupported"

    schannel_explicit_on = (
        schannel_key_exists
        and schannel_enabled == 1
        and (schannel_disabled_by_default is None or schannel_disabled_by_default == 0)
    )

    if not is_win11:
        if not schannel_key_exists:
            return "Skipped"
        if schannel_explicit_on:
            return "Skipped"
        return "Skipped"

    if not schannel_key_exists:
        return "Supported" if crypto_ui else "Skipped"
    if schannel_explicit_on or (schannel_disabled_by_default == 0):
        return "Supported"
    if crypto_ui:
        return "Skipped"
    return "Unsupported"


def elevation_fresh(captured: datetime, now: datetime, max_age=15):
    age = (now - captured).total_seconds() / 60
    return 0 <= age <= max_age


def menu_session_fresh(valid_until: datetime, now: datetime):
    return valid_until > now


def launcher_target_match(launcher_sid, target_sid):
    return bool(launcher_sid) and launcher_sid == target_sid


def machine_backup_skip_create(exists, valid):
    return exists and valid


def sites_backup_immutable(backup_exists):
    return backup_exists


def exit_decision(results, policy_blocked=False, partial_restore=False):
    if partial_restore:
        return 4
    failed = [r for r in results if r["status"] == "Failed"]
    if failed:
        return 2
    required = [r for r in results if r.get("required")]
    not_success = [r for r in required if r["status"] != "Success"]
    if not_success:
        if all(r["status"] == "Blocked" for r in not_success) and policy_blocked:
            return 3
        return 2
    if policy_blocked:
        return 3
    return 0


def main():
    failures = 0

    def ok(cond, name):
        nonlocal failures
        if not cond:
            print(f"FAIL: {name}")
            failures += 1
        else:
            print(f"OK: {name}")

    ok(
        tls13_assessment(19045, False, True, 1, 0, True) == "Skipped",
        "Win10 Schannel+CRYPTO never Supported",
    )
    ok(
        tls13_assessment(19045, False, True, None, 1, True) == "Skipped",
        "Win10 TLS1.3 key default-off => Skipped",
    )
    ok(
        tls13_assessment(22631, True, True, None, None, False) == "Supported",
        "Win11 no Schannel key + CRYPTO => Supported",
    )
    ok(
        tls13_assessment(22631, True, True, 0, 1, True) == "Unsupported",
        "Enabled=0 => Unsupported",
    )

    now = datetime.now(timezone.utc)
    ok(elevation_fresh(now - timedelta(minutes=5), now), "Elevation 5m valid")
    ok(not elevation_fresh(now - timedelta(minutes=20), now), "Elevation 20m invalid")
    ok(menu_session_fresh(now + timedelta(hours=2), now), "Menu session valid")
    ok(not menu_session_fresh(now - timedelta(minutes=1), now), "Menu session expired")

    ok(launcher_target_match("S-1-5-1", "S-1-5-1"), "SID match")
    ok(not launcher_target_match("S-1-5-1", "S-1-5-2"), "SID mismatch blocks")

    ok(machine_backup_skip_create(True, True), "Do not overwrite valid machine backup")
    ok(not machine_backup_skip_create(False, False), "Create when no backup")
    ok(sites_backup_immutable(True), "sites.xml.bak immutable when exists")

    ok(exit_decision([], partial_restore=True) == 4, "Partial restore exit 4")
    ok(
        exit_decision(
            [{"status": "Success", "required": True}, {"status": "Failed", "required": True}]
        )
        == 2,
        "WinHTTP fail => 2",
    )

    if failures:
        print(f"\n{failures} test(s) failed.")
        return 1
    print("\nAll logic tests passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
