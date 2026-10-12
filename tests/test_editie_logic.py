#!/usr/bin/env python3
"""Mirrors tests/Run-EditIELogicTests.ps1 for Linux CI (logic only)."""

import sys
from datetime import datetime, timedelta


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
    schannel_default_off = (
        schannel_key_exists
        and schannel_disabled_by_default == 1
        and (schannel_enabled is None or schannel_enabled != 1)
    )
    if is_win11:
        if not schannel_key_exists:
            return "Supported" if crypto_ui else "Skipped"
        if schannel_default_off:
            return "Skipped" if crypto_ui else "Unsupported"
        return "Supported"
    if not schannel_key_exists:
        return "Skipped"
    if schannel_default_off:
        return "Skipped"
    return "Supported" if crypto_ui else "Skipped"


def context_fresh(captured: datetime, now: datetime, max_age=15):
    age = (now - captured).total_seconds() / 60
    return 0 <= age <= max_age


def exit_decision(results, policy_blocked=False):
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
        tls13_assessment(19045, False, True, None, 1, True) == "Skipped",
        "Win10 TLS1.3 key default-off => Skipped",
    )
    ok(
        tls13_assessment(22631, True, True, None, None, False) == "Supported",
        "Win11 no Schannel key + CRYPTO => Supported",
    )
    ok(
        tls13_assessment(22631, True, False, None, None, False) == "Skipped",
        "Win11 no key no UI => Skipped",
    )
    ok(
        tls13_assessment(22631, True, True, 0, 1, True) == "Unsupported",
        "Enabled=0 => Unsupported",
    )
    now = datetime.utcnow()
    ok(context_fresh(now - timedelta(minutes=5), now), "Context 5m valid")
    ok(not context_fresh(now - timedelta(minutes=20), now), "Context 20m invalid")
    ok(
        exit_decision(
            [{"status": "Success", "required": True}, {"status": "Failed", "required": True}]
        )
        == 2,
        "WinHTTP fail => 2",
    )
    ok(
        exit_decision(
            [{"status": "Success", "required": True}, {"status": "Blocked", "required": True}],
            policy_blocked=True,
        )
        == 3,
        "GPO blocked => 3",
    )

    if failures:
        print(f"\n{failures} test(s) failed.")
        return 1
    print("\nAll logic tests passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
