"""Shared weapon balance stays pure and WorldSim remains a compatible facade."""

from __future__ import annotations

import os
from pathlib import Path
import subprocess
import sys

os.environ.setdefault("BOT_TOKEN", "123456:weapon-balance-module")

import mafiozi_bot as game
import weapon_balance


ROOT = Path(__file__).resolve().parent


def test_isolated_import_has_no_bot_or_transport_side_effects() -> None:
    code = """
import sys
import weapon_balance
for name in ('mafiozi_bot', 'telegram', 'aiohttp', '_preview_ws_server'):
    assert name not in sys.modules, name
assert weapon_balance.weapon_damage('pistol') == 24
"""
    subprocess.run(
        [sys.executable, "-c", code], cwd=ROOT, check=True,
        capture_output=True, text=True,
    )


def test_worldsim_facade_delegates_to_shared_balance() -> None:
    assert game.WorldSim.WEAPON_PROFILE is weapon_balance.WEAPON_PROFILE
    assert game.WorldSim.WEAPON_ALIASES is weapon_balance.WEAPON_ALIASES
    assert game.WorldSim.WEAPON_AMMO is weapon_balance.WEAPON_AMMO
    assert game.WorldSim.AMMO_DROP_ROUNDS is weapon_balance.AMMO_DROP_ROUNDS
    assert game.WorldSim.WEAPON_DMG is weapon_balance.WEAPON_DMG

    for authored, canonical in (
        ("pistol", "pistol"), ("tt_pistol", "pistol"),
        ("deagle", "pistol_heavy"), ("ak74", "rifle"),
        ("not-a-weapon", "pistol"),
    ):
        assert game.WorldSim._weapon_key(authored) == canonical
        assert game.WorldSim._weapon_profile(authored) is weapon_balance.WEAPON_PROFILE[canonical]
        profile = weapon_balance.WEAPON_PROFILE[canonical]
        for distance in (0.0, profile["range"] * profile["falloff_start"], profile["range"]):
            assert game.WorldSim._weapon_damage(authored, distance) == weapon_balance.weapon_damage(
                authored, distance)

    critical = dict(weapon_balance.weapon_profile("nagan"), _damage_mul=1.8)
    assert game.WorldSim._weapon_damage("nagan", 0.0, critical) == 58
    assert weapon_balance.ammo_drop_for("deagle") == ("magnum", 6)


def test_backend_uploader_includes_shared_module() -> None:
    source = (ROOT / "github_upload_backend.py").read_text(encoding="utf-8")
    assert '"weapon_balance.py"' in source


if __name__ == "__main__":
    test_isolated_import_has_no_bot_or_transport_side_effects()
    test_worldsim_facade_delegates_to_shared_balance()
    test_backend_uploader_includes_shared_module()
    print("weapon balance module: isolated import, WorldSim facade and uploader OK")
