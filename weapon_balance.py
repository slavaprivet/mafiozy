"""Pure shared firearm balance for production and the local preview adapter.

This module deliberately has no bot, network, database, clock or random
dependencies. Mutable combat authorization remains owned by ``WorldSim``.
"""

from __future__ import annotations

from collections.abc import Mapping


WEAPON_CRIT_CHANCE = 0.12
WEAPON_CRIT_MUL = 1.25
NAGAN_CHAIN_COOLDOWNS = (0.48, 0.38, 0.30, 0.24)

WEAPON_PROFILE = {
    "grenade": {"dmg": 95, "cd": 0.0, "range": 12.0, "falloff_start": 1.0, "min_mul": 1.0},
    "molotov_fire": {"dmg": 12, "cd": 0.0, "range": 12.0, "falloff_start": 1.0, "min_mul": 1.0},
    "pistol": {"dmg": 24, "cd": 0.38, "range": 8.0, "falloff_start": 0.72, "min_mul": 0.65},
    "nagan": {"dmg": 32, "cd": 0.48, "range": 9.2, "falloff_start": 0.78, "min_mul": 0.76,
              "duel_pause": 0.80, "duel_crit_mul": 1.80, "armor_pen": 0.45},
    "revolver": {"dmg": 86, "cd": 0.58, "range": 10.5, "falloff_start": 0.84, "min_mul": 0.80,
                 "armor_pen": 0.35},
    "pistol_heavy": {"dmg": 72, "cd": 0.46, "range": 11.2, "falloff_start": 0.80, "min_mul": 0.76},
    "pistol_gold": {"dmg": 48, "cd": 0.24, "range": 11.5, "falloff_start": 0.80, "min_mul": 0.76},
    "shotgun": {"dmg": 76, "cd": 0.90, "range": 6.2, "falloff_start": 0.36, "min_mul": 0.38},
    "smg": {"dmg": 15, "cd": 0.105, "range": 8.0, "falloff_start": 0.60, "min_mul": 0.52},
    "tommy_gun": {"dmg": 24, "cd": 0.12, "range": 10.0, "falloff_start": 0.68, "min_mul": 0.58},
    "golden_tommy": {"dmg": 24, "cd": 0.12, "range": 10.0, "falloff_start": 0.68, "min_mul": 0.58},
    "rifle": {"dmg": 42, "cd": 0.20, "range": 14.0, "falloff_start": 0.76, "min_mul": 0.68},
    "sniper": {"dmg": 132, "cd": 1.25, "range": 20.0, "falloff_start": 0.92, "min_mul": 0.88},
    "rpg": {"dmg": 160, "cd": 1.65, "range": 15.0, "falloff_start": 1.00, "min_mul": 1.00},
}

WEAPON_ALIASES = {
    "tt": "pistol", "tt_pistol": "pistol", "pm": "pistol", "glock": "pistol",
    "desert_eagle": "pistol_heavy", "deagle": "pistol_heavy",
    "golden_colt": "pistol_gold", "sawn_off": "shotgun",
    "uzi": "smg", "ump": "smg", "mp5": "smg", "golden_uzi": "smg",
    "ak": "rifle", "ak74": "rifle", "m4": "rifle", "m16": "rifle",
}

WEAPON_AMMO = {
    "pistol": "9mm", "pistol_gold": "9mm", "smg": "9mm",
    "tommy_gun": "9mm", "golden_tommy": "9mm", "nagan": "magnum",
    "revolver": "magnum", "pistol_heavy": "magnum", "shotgun": "shell",
    "rifle": "rifle", "sniper": "sniper", "rpg": "rocket",
}
AMMO_DROP_ROUNDS = {"9mm": 12, "magnum": 6, "shell": 6,
                    "rifle": 15, "sniper": 3, "rocket": 1}
WEAPON_DMG = {
    key: int(WEAPON_PROFILE[key]["dmg"])
    for key in WEAPON_AMMO
}


def is_known_weapon(weapon: str, *, profiles: Mapping = WEAPON_PROFILE,
                    aliases: Mapping = WEAPON_ALIASES) -> bool:
    raw = str(weapon or "")
    return aliases.get(raw, raw) in profiles


def weapon_key(weapon: str, *, profiles: Mapping = WEAPON_PROFILE,
               aliases: Mapping = WEAPON_ALIASES) -> str:
    key = str(weapon or "pistol")
    key = aliases.get(key, key)
    return key if key in profiles else "pistol"


def weapon_profile(weapon: str, *, profiles: Mapping = WEAPON_PROFILE,
                   aliases: Mapping = WEAPON_ALIASES) -> dict:
    return profiles[weapon_key(weapon, profiles=profiles, aliases=aliases)]


def weapon_damage(weapon: str, distance: float = 0.0,
                  shot_profile: dict | None = None, *,
                  profiles: Mapping = WEAPON_PROFILE,
                  aliases: Mapping = WEAPON_ALIASES) -> int:
    profile = shot_profile or weapon_profile(
        weapon, profiles=profiles, aliases=aliases)
    base = float(profile["dmg"])
    max_range = float(profile["range"])
    start = max_range * float(profile.get("falloff_start", 0.7))
    damage_mul = float(profile.get("_damage_mul", 1.0))
    if distance <= start or max_range <= start:
        return int(round(base * damage_mul))
    fraction = max(0.0, min(1.0, (distance - start) / (max_range - start)))
    minimum = float(profile.get("min_mul", 0.6))
    return max(1, int(round(base * (1.0 - fraction * (1.0 - minimum))
                            * damage_mul)))


def ammo_drop_for(weapon: str) -> tuple[str, int]:
    key = weapon_key(weapon)
    ammo_type = WEAPON_AMMO.get(key, "9mm")
    return ammo_type, int(AMMO_DROP_ROUNDS.get(ammo_type, 6))
