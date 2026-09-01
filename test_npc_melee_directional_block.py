import asyncio
import inspect
import math
import os
from pathlib import Path

os.environ.setdefault("BOT_TOKEN", "123456:npc-melee-direction-test")

import mafiozi_bot as game


ROOT = Path(__file__).resolve().parent


def test_authoritative_direction_classifier_front_back_and_boundary():
    classify = game.WorldSim._directional_npc_melee_kind
    target = {"x": 0, "y": 0, "ang": 0}

    assert classify({"x": 1, "y": 0}, target) == "melee"
    assert classify({"x": -1, "y": 0}, target) == "melee_back"
    assert classify({"x": 0, "y": 1}, target) == "melee"

    turned = {"x": 0, "y": 0, "ang": math.pi}
    assert classify({"x": 1, "y": 0}, turned) == "melee_back"
    assert classify({"x": -1, "y": 0}, turned) == "melee"


def test_invalid_authoritative_geometry_fails_closed_as_front():
    classify = game.WorldSim._directional_npc_melee_kind
    valid_target = {"x": 0, "y": 0, "ang": 0}

    for attacker, target in (
            (None, valid_target),
            ({}, valid_target),
            ({"x": "bad", "y": 0}, valid_target),
            ({"x": math.nan, "y": 0}, valid_target),
            ({"x": math.inf, "y": 0}, valid_target),
            ({"x": -math.inf, "y": 0}, valid_target),
            ({"x": 1, "y": 0}, None),
            ({"x": 1, "y": 0}, {"x": 0, "y": 0, "ang": math.nan}),
    ):
        assert classify(attacker, target) == "melee"


def test_directional_kind_drives_existing_block_resolution():
    async def scenario():
        world = game.WorldSim()
        world.add_or_update("target", "Target", {})
        target = world.players["target"]
        target.update(x=0, y=0, ang=0, dead=False, hp=100, max_hp=100,
                      _melee_block=True)
        token = game._SYNC_WORLD_HARNESS.set(True)
        try:
            front_kind = world._directional_npc_melee_kind(
                {"x": 1, "y": 0}, target)
            front = await world.apply_authoritative_damage(
                "target", "npc:front", front_kind, 12)
            assert front_kind == "melee"
            assert front["melee_blocked"]
            assert front["body"]["damage"] == 1

            target.update(dead=False, hp=100, max_hp=100)
            back_kind = world._directional_npc_melee_kind(
                {"x": -1, "y": 0}, target)
            back = await world.apply_authoritative_damage(
                "target", "npc:back", back_kind, 12)
            assert back_kind == "melee_back"
            assert back["melee_block_pierced"]
            assert back["melee_block_bypass"] == "back"
            assert not back.get("melee_blocked")
            assert back["body"]["damage"] == 12
        finally:
            game._SYNC_WORLD_HARNESS.reset(token)

    asyncio.run(scenario())


def test_only_boss_saber_route_invokes_direction_classifier():
    aggro = inspect.getsource(game.WorldSim._tick_aggro_async)
    assert aggro.count("_directional_npc_melee_kind(bot, target)") == 1
    assert "'npc-melee'" in aggro
    assert "'melee', dmg" not in aggro

    for firearm_route in (
            game.WorldSim.apply_player_shoot,
            game.WorldSim._tick_pending_bot_shots_async,
            game.WorldSim._tick_cops_async,
    ):
        assert "_directional_npc_melee_kind" not in inspect.getsource(
            firearm_route), firearm_route.__name__


def test_world_declares_inert_direction_contract_once():
    world = (ROOT / "world.html").read_text(encoding="utf-8")
    marker = (
        '<meta name="mafiozy-npc-melee-direction-contract" '
        'content="authoritative-front-back-v1">'
    )
    assert world.count(marker) == 1


if __name__ == "__main__":
    tests = [value for name, value in sorted(globals().items())
             if name.startswith("test_") and callable(value)]
    for test in tests:
        test()
        print(f"PASS {test.__name__}")
    print(f"{len(tests)}/{len(tests)} passed")
