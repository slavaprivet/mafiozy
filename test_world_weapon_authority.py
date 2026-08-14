"""Exact production weapon balance, aliases, ownership and shared cadence.

The local preview adapter still applies a display-only fixed 42 damage and has
no safe shared-profile import boundary. Do not duplicate this table there;
preview parity needs a later shared balance module instead of a second truth.
"""

import os
from unittest.mock import patch

os.environ.setdefault("BOT_TOKEN", "123456:world-weapon-authority")

import mafiozi_bot as game


EXPECTED = {
    "pistol": 24, "nagan": 32, "revolver": 86,
    "pistol_heavy": 72, "pistol_gold": 48,
    "shotgun": 76, "smg": 15, "tommy_gun": 24,
    "golden_tommy": 24, "rifle": 42, "sniper": 132, "rpg": 160,
    "tt_pistol": 24, "deagle": 72, "sawn_off": 76,
    "uzi": 15, "ak74": 42,
}


def run() -> None:
    world = game.WorldSim()
    world.add_or_update("shooter", "Shooter", {})
    shooter = world.players["shooter"]
    shooter.update(dead=False, _weapon_classes=set(game.WorldSim.WEAPON_PROFILE))
    clock = [2_004_000_000.0]

    with patch.object(game.time, "time", side_effect=lambda: clock[0]), \
            patch.object(game.random, "random", return_value=1.0):
        for weapon, expected in EXPECTED.items():
            clock[0] += 2.0
            # Nagan's deliberate pause is a real critical mechanic; keep this
            # table focused on authored base damage by using its first cadence.
            shooter["_weapon_shot_t"] = clock[0] - .5 if weapon == "nagan" else 0.0
            shooter["_nagan_chain"] = 0
            profile = world._authorize_weapon_shot(shooter, weapon)
            assert profile is not None, weapon
            assert world._weapon_damage(weapon, 0.0, profile) == expected, weapon
            assert world._authorize_weapon_shot(shooter, weapon) is None, weapon

        shooter["_weapon_classes"] = {"pistol"}
        shooter["_weapon_shot_t"] = 0.0
        assert world._authorize_weapon_shot(shooter, "rifle") is None
        pistol = world._weapon_profile("pistol")
        assert world._weapon_damage("pistol", pistol["range"]) == round(
            pistol["dmg"] * pistol["min_mul"])

    assert world._weapon_key("tt_pistol") == "pistol"
    assert world._weapon_key("deagle") == "pistol_heavy"
    assert world._weapon_key("sawn_off") == "shotgun"
    assert world._weapon_key("uzi") == "smg"
    assert world._weapon_key("ak74") == "rifle"
    print("world weapon authority: exact damage, aliases, ownership and cadence OK")


if __name__ == "__main__":
    run()
