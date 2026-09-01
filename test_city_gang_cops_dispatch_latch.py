"""Focused exactly-once police redispatch contract for ordinary city gangs."""

import os
from pathlib import Path
from unittest.mock import patch

os.environ.setdefault("BOT_TOKEN", "123456:city-gang-cops-latch-regression")

import mafiozi_bot as game


ROOT = Path(__file__).resolve().parent
UID = "gang-cops-player"
T0 = 1_910_000_000.0


def fresh_encounter() -> tuple[game.WorldSim, dict, dict]:
    world = game.WorldSim()
    world.city_gangs.clear()
    world.cops.clear()
    world.players.clear()
    world._city_gang_next_spawn_at = T0 + 3600.0
    with patch.object(game.time, "time", return_value=T0), \
            patch.object(game, "_world_bot_passable", return_value=True):
        gang = world._spawn_city_gang("purple")
    assert gang and not gang.get("district_did")
    gang["_reinforcements"] = world.CITY_GANG_MAX_REINFORCEMENTS
    gang["_rival_replan_at"] = T0 + 3600.0
    for index, bot in enumerate(gang["bots"]):
        bot.update(
            x=42.0 + index * 0.3,
            y=40.0 + index * 0.2,
            hp=1000,
            max_hp=1000,
            alive=True,
            weapon="pistol",
            _shot_t=T0,
            _act="walk",
            _act_until=T0 + 3600.0,
        )
    world.add_or_update(UID, "Cops latch", {})
    player = world.players[UID]
    player.update(
        x=40.0,
        y=40.0,
        dead=False,
        hp=100,
        max_hp=100,
        _mode="pvp",
        _jail_until=0.0,
        _weapon_classes={"rifle"},
        _weapon_shot_t=0.0,
    )
    return world, gang, gang["bots"][0]


def hit_and_tick(world: game.WorldSim, gang: dict, bot: dict,
                 now: float) -> tuple[dict, list]:
    player = world.players[UID]
    player["_weapon_shot_t"] = 0.0
    with patch.object(game.time, "time", return_value=now), \
            patch.object(game, "_world_los", return_value=True), \
            patch.object(game, "_world_bot_passable", return_value=True), \
            patch.object(game.random, "random", return_value=0.99):
        hit = world.city_gang_shoot_bot(UID, bot["id"], "rifle")
        packets = world.tick_city_gangs(0.0)
    assert hit and hit["kind"] == "aggro_hit"
    assert gang["state"] == "hostile"
    return hit, packets


def invalidate(world: game.WorldSim, mode: str, now: float) -> None:
    player = world.players.get(UID)
    if mode == "missing":
        world.players.pop(UID)
    elif mode == "dead":
        player["dead"] = True
    elif mode == "pve":
        player["_mode"] = "pve"
    elif mode == "jail":
        player["_jail_until"] = now + 30.0
    elif mode == "range":
        player.update(x=70.0, y=70.0)
    else:
        raise AssertionError(mode)


def restore_player(world: game.WorldSim) -> dict:
    if UID not in world.players:
        world.add_or_update(UID, "Cops latch", {})
    player = world.players[UID]
    player.update(
        x=40.0,
        y=40.0,
        dead=False,
        hp=100,
        max_hp=100,
        _mode="pvp",
        _jail_until=0.0,
        _weapon_classes={"rifle"},
        _weapon_shot_t=0.0,
    )
    return player


def assert_redispatch_after(mode: str) -> None:
    world, gang, bot = fresh_encounter()
    _, first_packets = hit_and_tick(world, gang, bot, T0 + 1.0)
    first_events = [p for p in first_packets
                    if p.get("kind") == "city_gang_combat"]
    first_cops = [c for c in world.cops if c.get("alive")]
    first_ids = {str(c["id"]) for c in first_cops}
    assert len(first_events) == 1
    assert len(first_cops) == world.CITY_GANG_COPS_PER_GANG
    assert gang["_cops_dispatched"] is True

    invalidate(world, mode, T0 + 2.0)
    with patch.object(game.time, "time", return_value=T0 + 2.0), \
            patch.object(game, "_world_bot_passable", return_value=True):
        invalid_packets = world.tick_city_gangs(0.0)
    assert not any(p.get("kind") == "city_gang_combat"
                   for p in invalid_packets)
    assert gang["state"] == "patrol"
    assert gang["_target_uid"] is None
    assert gang["_hostile_until"] == 0.0
    assert gang["_cops_dispatched"] is False

    for cop in first_cops:
        cop["alive"] = False
    restore_player(world)
    _, second_packets = hit_and_tick(world, gang, bot, T0 + 3.0)
    second_events = [p for p in second_packets
                     if p.get("kind") == "city_gang_combat"]
    second_cops = [c for c in world.cops if c.get("alive")]
    second_ids = {str(c["id"]) for c in second_cops}
    assert len(second_events) == 1
    assert len(second_cops) == world.CITY_GANG_COPS_PER_GANG
    assert second_ids.isdisjoint(first_ids)

    with patch.object(game.time, "time", return_value=T0 + 3.1), \
            patch.object(game, "_world_bot_passable", return_value=True):
        repeat_packets = world.tick_city_gangs(0.0)
    assert not any(p.get("kind") == "city_gang_combat"
                   for p in repeat_packets)
    assert len([c for c in world.cops if c.get("alive")]) == \
        world.CITY_GANG_COPS_PER_GANG


def test_invalid_target_redispatch_matrix() -> None:
    for mode in ("missing", "dead", "pve", "jail", "range"):
        assert_redispatch_after(mode)


def test_timeout_path_remains_exactly_once() -> None:
    world, gang, bot = fresh_encounter()
    _, first_packets = hit_and_tick(world, gang, bot, T0 + 1.0)
    assert len([p for p in first_packets
                if p.get("kind") == "city_gang_combat"]) == 1
    gang["_hostile_until"] = T0 + 1.5
    with patch.object(game.time, "time", return_value=T0 + 2.0), \
            patch.object(game, "_world_bot_passable", return_value=True):
        world.tick_city_gangs(0.0)
    assert gang["state"] == "patrol"
    assert gang["_cops_dispatched"] is False


def test_world_marker_is_inert_and_exact() -> None:
    world_source = (ROOT / "world.html").read_text(encoding="utf-8")
    marker = (
        '<meta name="mafiozy-city-gang-cops-redispatch-contract" '
        'content="invalid-target-unlatch-v1">'
    )
    assert world_source.count(marker) == 1


def run() -> None:
    test_invalid_target_redispatch_matrix()
    test_timeout_path_remains_exactly_once()
    test_world_marker_is_inert_and_exact()
    print("city gang cops redispatch latch: 7/7 OK")


if __name__ == "__main__":
    run()
