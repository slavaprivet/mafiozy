"""Behavioral matrix for all nineteen Boss Brain v2 personalities."""

from pathlib import Path

import npc_empire as ne


WORLD = (Path(__file__).resolve().parent / "world.html").read_text(encoding="utf-8")
NOW = 2_000_000_000


def _plans(state, holdings, events, **kwargs):
    return {
        profile.leader_id: ne._boss_brain(
            profile, state, holdings, events, NOW, **kwargs
        )
        for profile in ne.PROFILES
    }


def run() -> None:
    assert len(ne.PROFILES) == len(ne.BOSS_DOCTRINES) == 19
    assert len(ne.BOSS_MINDSETS) == 19
    assert set(ne.BOSS_DOCTRINES) == set(ne.PROFILE_BY_ID)
    assert len({item["id"] for item in ne.BOSS_DOCTRINES.values()}) == 19
    assert len({item["signature"] for item in ne.BOSS_DOCTRINES.values()}) == 19
    assert len({tuple(item.values()) for item in ne.BOSS_MINDSETS.values()}) == 19
    assert all(len(item["orders"]) == 3 for item in ne.BOSS_DOCTRINES.values())
    assert all(0.1 <= item["retreat_hp"] <= 0.4 for item in ne.BOSS_DOCTRINES.values())

    weak = _plans(
        {"treasury": 5000, "members": 3, "strength": 45,
         "status": "active", "hospital_until": 0},
        [], [], neutral_buildings=5, affordable_businesses=0,
    )
    rich = _plans(
        {"treasury": 100000, "members": 18, "strength": 260,
         "status": "active", "hospital_until": 0},
        [{"kind": "building", "holding_id": "1,1"}], [],
        neutral_buildings=2, affordable_businesses=4,
    )
    war = _plans(
        {"treasury": 12000, "members": 14, "strength": 180,
         "status": "active", "hospital_until": 0},
        [{"kind": "building", "holding_id": "1,1"}],
        [{"kind": "player_attack", "created_at": NOW, "target_id": "101"}],
        active_wars=1, neutral_buildings=3, affordable_businesses=0,
    )
    loss = _plans(
        {"treasury": 9000, "members": 10, "strength": 135,
         "status": "active", "hospital_until": 0},
        [{"kind": "building", "holding_id": "1,1"}],
        [{"kind": "war_lost", "created_at": NOW},
         {"kind": "hospital", "created_at": NOW - 60}],
        active_wars=1, neutral_buildings=3, affordable_businesses=0,
    )

    for matrix in (weak, rich, war, loss):
        assert set(matrix) == set(ne.PROFILE_BY_ID)
        assert all(plan["doctrine"]["id"] == ne.BOSS_DOCTRINES[leader]["id"]
                   for leader, plan in matrix.items())
        assert all(plan["scores"] and plan["reason"] for plan in matrix.values())

    assert {plan["strategy"] for plan in rich.values()} >= {
        "acquire", "expand", "fortify", "recruit"
    }
    assert {plan["strategy"] for plan in war.values()} == {"fortify", "retaliate"}
    assert all(plan["adaptation"]["recent_wounds"] == 1 for plan in loss.values())
    assert rich["zara"]["strategy"] == "acquire"
    assert rich["marat"]["strategy"] == "fortify"
    assert war["viktor"]["strategy"] == "retaliate"
    assert weak["leila"]["strategy"] == "recruit"

    # Client combat contracts: one bounded squad cadence, player-war tactics,
    # three-stage HQ behavior, persistent effects and all mirrored doctrines.
    for marker in (
        "const NPC_EMPIRE_DOCTRINES=", "_empirePlayerSquadOrder",
        "EMPIRE_SQUAD_ORDER_MS=900", "_empirePlayerCombatThink",
        "_empireUseSignature", "_applyEmpirePlayerWeaponHit",
        "_tickEmpirePlayerStatuses", "_npcEmpireAssaultAi",
        "empireAssaultPhase", "empirePlayerOrder",
    ):
        assert marker in WORLD
    assert WORLD.count("strategy_bias") == 0
    for leader, doctrine in ne.BOSS_DOCTRINES.items():
        assert f"{leader}:{{id:'{doctrine['id']}'" in WORLD
        assert f"signature:'{doctrine['signature']}'" in WORLD

    print("boss_intelligence_v2: 19/19 doctrines and four behavioral scenarios OK")


if __name__ == "__main__":
    run()
