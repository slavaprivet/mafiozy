"""Server contract for doctrine-aware player-business target decisions."""

from pathlib import Path

import npc_empire


ROOT = Path(__file__).resolve().parent
SOURCE = (ROOT / "npc_empire.py").read_text(encoding="utf-8")


def scored(leader_id: str, *, value_band: str, distance: float,
           defense_band: str) -> dict:
    profile = npc_empire.PROFILE_BY_ID[leader_id]
    return npc_empire.score_player_business_target(
        {"value_band": value_band, "intel": {"defense_band": defense_band}},
        distance=distance, guards=999,
        force=4, quality=55, relation=-50, aggression=profile.aggression,
        raid_policy=npc_empire._boss_player_raid_policy(profile),
    )


def run() -> None:
    policies = {
        profile.leader_id: npc_empire._boss_player_raid_policy(profile)
        for profile in npc_empire.PROFILES
    }
    assert len(policies) == 19
    assert all(.5 <= policy["value_weight"] <= 1.75 for policy in policies.values())
    assert all(.5 <= policy["distance_weight"] <= 2 for policy in policies.values())
    assert all(.5 <= policy["defense_weight"] <= 1.75 for policy in policies.values())
    assert all(.6 <= policy["risk_tolerance"] <= 1.5 for policy in policies.values())
    assert all(15 <= policy["stickiness"] <= 90 for policy in policies.values())
    assert max(p["value_weight"] for p in policies.values()) - min(
        p["value_weight"] for p in policies.values()) > .35
    assert max(p["risk_tolerance"] for p in policies.values()) - min(
        p["risk_tolerance"] for p in policies.values()) > .4
    assert max(p["stickiness"] for p in policies.values()) - min(
        p["stickiness"] for p in policies.values()) > 50

    # Identical tactical facts produce authored risk differences.
    assert scored("emil", value_band="premium", distance=20, defense_band="guarded")["feasible"]
    assert scored("viktor", value_band="premium", distance=20, defense_band="guarded")["feasible"]
    assert not scored("zara", value_band="premium", distance=20, defense_band="guarded")["feasible"]
    assert not scored("sofia", value_band="premium", distance=20, defense_band="guarded")["feasible"]

    # A distant lucrative opening is worth the route to mobile/value doctrines,
    # while the fortress and duelist prefer the nearby exposed venue.
    for leader_id in ("zara", "marco", "sofia", "viktor"):
        assert scored(leader_id, value_band="premium", distance=120,
                      defense_band="guarded")["score"] > scored(
            leader_id, value_band="local", distance=10,
            defense_band="unconfirmed")["score"]
    for leader_id in ("marat", "emil"):
        assert scored(leader_id, value_band="premium", distance=120,
                      defense_band="guarded")["score"] < scored(
            leader_id, value_band="local", distance=10,
            defense_band="unconfirmed")["score"]

    # The fixed 70-point follow-up rule is gone: patience keeps Marat on a
    # target 60 points behind, while adaptable Marco switches.
    assert policies["marat"]["stickiness"] >= 60
    assert policies["marco"]["stickiness"] < 60
    selector = SOURCE[SOURCE.index("async def _select_player_business_target_smart"):
                      SOURCE.index("def _player_business_raid_objective")]
    assert "int(policy['stickiness'])" in selector
    assert "best['_raid']['score']) - 70" not in selector
    assert "raid_policy=policy" in selector

    metrics = scored("marco", value_band="premium", distance=120,
                     defense_band="guarded")
    target = {"ref": "building:4,7", "kind": "building", "holding_id": "4,7",
              "_raid": metrics}
    activity = npc_empire._player_war_activity(
        npc_empire.PROFILE_BY_ID["marco"],
        {"attacks": 0, "last_business_id": "", "last_attack_at": 100,
         "next_attack_at": 200}, target, 100)
    assert activity["target_reason"] == metrics["target_reason"]
    assert activity["raid_metrics"] == metrics["metrics"]
    assert activity["raid_policy"] == policies["marco"]
    assert activity["objective"] == "first-close"

    followup = npc_empire._player_war_activity(
        npc_empire.PROFILE_BY_ID["marco"],
        {"attacks": 1, "last_business_id": "building:4,7",
         "last_attack_at": 100, "next_attack_at": 200}, target, 100)
    switched = npc_empire._player_war_activity(
        npc_empire.PROFILE_BY_ID["marco"],
        {"attacks": 1, "last_business_id": "building:other",
         "last_attack_at": 100, "next_attack_at": 200}, target, 100)
    assert followup["objective"] == "followup-capture"
    assert switched["objective"] == "first-close"

    assert "'target_reason':" in SOURCE and "'raid_metrics':" in SOURCE
    assert "'raid_policy':" in SOURCE


if __name__ == "__main__":
    run()
    print("npc boss raid doctrine: 19 bounded policies, risk, value, stickiness and telemetry OK")
