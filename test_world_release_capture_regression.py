import time

import mafiozi_bot as game


def _make_target(world):
    return {
        "id": "release-target",
        "x": float(world.JAIL_RELEASE_X) + 0.15,
        "y": float(world.JAIL_RELEASE_Y),
        "hp": 10000,
        "max_hp": 10000,
        "alive": True,
        "kind": "member",
        "level": 1,
    }


def test_jail_release_restores_every_weapon_route():
    weapons = sorted(game.WorldSim.WEAPON_PROFILE)
    for weapon in weapons:
        world = game.WorldSim()
        world.add_or_update(
            "shooter",
            "Shooter",
            {},
            jail_until=int(time.time()) + 60,
            mode="pvp",
        )
        shooter = world.players["shooter"]
        shooter["x"], shooter["y"] = world.JAIL_X, world.JAIL_Y
        shooter["_weapon_classes"] = set(weapons)
        target = _make_target(world)
        world.city_gangs = [{
            "id": "release-gang",
            "bots": [target],
            "state": "patrol",
            "district_did": None,
        }]

        assert world.city_gang_shoot_bot("shooter", target["id"], weapon) is None

        shooter["_jail_until"] = time.time() - 1
        shooter["_jail_released"] = False
        world.tick_jail_release()

        assert shooter["_jail_until"] == 0
        assert shooter["_jail_released"] is True
        assert (shooter["x"], shooter["y"]) == (
            world.JAIL_RELEASE_X,
            world.JAIL_RELEASE_Y,
        )

        shooter["_weapon_shot_t"] = 0.0
        hit = world.city_gang_shoot_bot("shooter", target["id"], weapon)
        assert hit and hit["kind"] == "aggro_hit", weapon


def test_district_capture_keeps_chat_and_authoritative_role_snapshot():
    world = game.WorldSim()
    world.add_or_update("owner", "Owner", {}, mode="pvp")
    world.add_or_update("observer", "Observer", {}, mode="pvp")
    owner = world.players["owner"]
    observer = world.players["observer"]
    owner["_mafia"] = True
    owner["_mafia_family"] = "bellini"

    did = "northside"
    district = world.DISTRICTS_DEF[did]
    row, column = district["escape"]
    owner["x"], owner["y"] = float(column), float(row)
    observer["x"], observer["y"] = owner["x"], owner["y"]
    world.district_captures[did] = {
        "by_uid": "owner",
        "by_name": "Owner",
        "color": "#a020f0",
        "phase": "escape",
        "done": [],
        "charges": {},
    }

    captured = world.apply_district_capture_try("owner", did)
    assert captured and captured["kind"] == "district_captured"
    assert world.district_owners[did]["owner_uid"] == "owner"
    assert did not in world.district_captures

    world.apply_chat("owner", "capture chat survives")
    snapshot = world.snapshot_for("observer")
    visible_owner = next(
        player for player in snapshot["d"]["others"]
        if player["uid"] == "owner"
    )
    assert visible_owner["chat"] == "capture chat survives"
    assert visible_owner["mafia"] is True
    assert visible_owner["mafia_family"] == "bellini"


if __name__ == "__main__":
    test_jail_release_restores_every_weapon_route()
    test_district_capture_keeps_chat_and_authoritative_role_snapshot()
    print("WORLD_RELEASE_CAPTURE_REGRESSION_OK")
