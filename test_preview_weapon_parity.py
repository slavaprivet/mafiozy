"""The local preview consumes production damage, aliases, ammo and gang style."""

from __future__ import annotations

from pathlib import Path

import _preview_ws_server as preview
import weapon_balance


ROOT = Path(__file__).resolve().parent


def test_preview_damage_alias_and_range_parity() -> None:
    assert preview.preview_weapon_hit("pistol", 0.0) == {
        "weapon": "pistol", "damage": 24, "range": 8.0,
    }
    assert preview.preview_weapon_hit("rifle", 0.0)["damage"] == 42
    assert preview.preview_weapon_hit("deagle", 0.0)["damage"] == 72
    pistol = weapon_balance.weapon_profile("pistol")
    edge = preview.preview_weapon_hit("pistol", pistol["range"])
    assert edge is not None and edge["damage"] == 16
    assert preview.preview_weapon_hit("pistol", pistol["range"] + 0.0001) is None
    assert preview.preview_weapon_hit("pistol", float("nan")) is None
    assert preview.preview_actor_distance({"x": 0, "y": 0}, {"x": 3, "y": 4}) == 5.0
    assert preview.preview_actor_distance(None, {"x": 3, "y": 4}) is None
    assert preview.preview_actor_distance({"x": float("inf"), "y": 0}, {"x": 3, "y": 4}) is None


def test_preview_ammo_and_yellow_suit_parity() -> None:
    assert weapon_balance.ammo_drop_for("ak74") == ("rifle", 15)
    yellow = next(gang for gang in preview.preview_city_gangs if gang["faction"] == "yellow")
    assert yellow["bots"]
    assert all(bot["look"]["suit"] == "#f3efe5" for bot in yellow["bots"])


def test_preview_source_has_no_second_weapon_tables() -> None:
    source = (ROOT / "_preview_ws_server.py").read_text(encoding="utf-8")
    assert "damage = 42" not in source
    assert "ammo_map=" not in source
    assert "round_map=" not in source
    assert "weapon_balance.ammo_drop_for(weapon)" in source
    assert '"weapon": weapon' in source
    assert "if hit is None:" in source
    assert "preview_actor_distance(p, found)" in source


if __name__ == "__main__":
    test_preview_damage_alias_and_range_parity()
    test_preview_ammo_and_yellow_suit_parity()
    test_preview_source_has_no_second_weapon_tables()
    print("preview weapon parity: damage, aliases, range, ammo and yellow suit OK")
