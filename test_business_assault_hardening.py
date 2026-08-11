"""Focused regression for business-assault recovery and one-shot decisions."""

from pathlib import Path
from types import SimpleNamespace

import mafiozi_bot as game


ROOT = Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")
SERVER = (ROOT / "mafiozi_bot.py").read_text(encoding="utf-8")


def fake_world():
    return SimpleNamespace(
        _business_rob_sessions={},
        _business_war_claims={},
        _business_war_choice_results={},
    )


def test_every_business_can_restore_all_assault_phases():
    now = 1_000_000.0
    business_ids = set(game.SHOP_ROB_CONFIG)
    assert business_ids == set(game.SHOP_ROB_GUARDS)
    assert business_ids <= set(game.BUSINESS_POIS_RC)
    assert len(business_ids) >= 10

    for index, biz_id in enumerate(sorted(business_ids)):
        world = fake_world()
        guards = int(game.SHOP_ROB_GUARDS[biz_id])
        down = set(range(max(0, guards - 1)))
        world._business_rob_sessions["7"] = {
            "token": f"raid-{biz_id}", "biz_id": biz_id,
            "guard_count": guards, "guards_down": down,
            "owner_pressure": 69.0, "owner_hit_seq": 3,
            "attempt": 1 + index % 3, "expires_at": now + 120,
        }
        state = game._business_rob_state_payload(world, "7", now=now)
        active = state["active"]
        assert active["biz_id"] == biz_id
        assert active["rob_token"] == f"raid-{biz_id}"
        assert active["guards_down"] == sorted(down)
        assert active["owner_pressure"] == 69.0
        assert active["owner_hit_seq"] == 3
        assert active["expires_s"] == 120


def test_choice_and_terminal_result_survive_reconnect_without_reapply():
    now = 2_000_000.0
    for action in ("cash", "capture", "sabotage"):
        world = fake_world()
        token = f"choice-{action}"
        world._business_war_claims["9"] = {
            "token": token, "biz_id": "coffee", "money": 250,
            "family": "bellini", "expires_at": now + 90,
        }
        pending = game._business_rob_state_payload(world, "9", now=now)
        assert pending["pending_choice"]["business_choice_token"] == token
        assert pending["pending_choice"]["can_capture"] is True

        world._business_war_claims.clear()
        terminal = {"ok": True, "action": action, "biz_id": "coffee",
                    "money": 250, "_cached_until": now + 300}
        world._business_war_choice_results[("9", token)] = terminal
        first = game._business_choice_cached_reply(world, "9", token, now)
        second = game._business_choice_cached_reply(world, "9", token, now)
        assert first == second
        assert first["action"] == action
        assert "_cached_until" not in first
        recovered = game._business_rob_state_payload(world, "9", token, now)
        assert recovered["choice_result"] == first
        assert recovered["pending_choice"] is None


def test_expired_state_is_removed_and_cannot_be_replayed():
    world = fake_world()
    world._business_rob_sessions["11"] = {
        "token": "old-raid", "biz_id": "bar", "guard_count": 2,
        "guards_down": set(), "expires_at": 50,
    }
    world._business_war_claims["11"] = {
        "token": "old-choice", "biz_id": "bar", "expires_at": 50,
    }
    world._business_war_choice_results[("11", "old-choice")] = {
        "ok": True, "action": "cash", "_cached_until": 50,
    }
    state = game._business_rob_state_payload(world, "11", "old-choice", now=51)
    assert state == {"active": None, "pending_choice": None, "choice_result": None}
    assert "11" not in world._business_rob_sessions
    assert "11" not in world._business_war_claims


def test_client_and_server_contract_markers_are_present():
    for marker in (
        "business_rob_state_reply", "_restoreBusinessRobberyState",
        "_repairBusinessRobberyActors", "_recoverStalledBusinessGuard",
        "businessGuardRecovery", "last_choice_token",
        "attempts===1", "safe",  # one bounded client retry
        'data-business-choice="cash"', 'data-business-choice="capture"',
        'data-sabotage-kind="shutdown"', 'data-sabotage-kind="arson"',
        'data-sabotage-kind="alarm"', "businessRobberyHud3d",
    ):
        assert marker in WORLD, marker
    for marker in (
        "_business_rob_state_payload", "_business_choice_cached_reply",
        "_business_war_choice_results", "replayed=True",
        "guard_id not in guards_down", "hit_seq == expected_seq",
        "BEGIN IMMEDIATE", "INSERT OR REPLACE INTO shop_robs",
    ):
        assert marker in SERVER, marker


if __name__ == "__main__":
    test_every_business_can_restore_all_assault_phases()
    test_choice_and_terminal_result_survive_reconnect_without_reapply()
    test_expired_state_is_removed_and_cannot_be_replayed()
    test_client_and_server_contract_markers_are_present()
    print("business assault hardening: all businesses, reconnect and choices passed")
