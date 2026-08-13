from pathlib import Path
import re


ROOT = Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")


def test_authoritative_stance_controls_and_speed():
    assert "e.code === 'KeyZ'" in WORLD
    assert "e.code === 'ControlLeft' || e.code === 'ControlRight'" in WORLD
    assert "stance==='prone' ? .32 : stance==='crouch' ? .58 : 1" in WORLD
    assert "inDx*=stanceMoveMul;inDy*=stanceMoveMul" in WORLD


def test_bridge_exposes_deterministic_stance_fixture():
    assert "previewstance" in WORLD
    assert "stance,crouching:stance==='crouch',prone:stance==='prone'" in WORLD
    assert "three_preview.js?v=3d373-player-stances" in WORLD


def test_renderer_uses_one_cached_stance_rig_and_smooth_blends():
    assert "player-stance-rig" in THREE
    assert "crouchBlend:0,proneBlend:0" in THREE
    assert "playerAnim.proneBlend=expDamp" in THREE
    assert "playerAnim.crouchBlend=expDamp" in THREE
    assert "gun.rotation.x-=proneBlend*1.18+crouchBlend*.06" in THREE
    assert "poseTwoHandedGrip(Math.min(1.9,kickNorm),activeReloadProgress)" in THREE


def test_stances_do_not_lock_combat_or_reload():
    lock_line = next(line for line in THREE.splitlines() if "animationActionLocked=playerAnimationLayer" in line)
    assert "prone" not in lock_line and "crouch" not in lock_line and "stance" not in lock_line
    shoot = re.search(r"function shoot\(now\)\{(.+?)\n\s*\}\n\s*const spawnReloadDebris", THREE, re.S)
    assert shoot, "shoot() contract not found"
    assert "state.prone" not in shoot.group(1)
    assert "state.crouching" not in shoot.group(1)
    assert "activeReloadProgress" in THREE


def test_complete_weapon_table_remains_available_in_stances():
    expected = {
        "pistol", "nagan", "revolver", "pistol_heavy", "pistol_gold",
        "shotgun", "smg", "tommy_gun", "golden_tommy", "rifle",
        "sniper", "water_hose", "taser", "rpg", "grenade", "molotov", "c4",
    }
    table = re.search(r"const WEAPON_VISUALS=\{(.+?)\n\s*\};", THREE, re.S)
    assert table, "WEAPON_VISUALS table not found"
    missing = {weapon for weapon in expected if not re.search(rf"(?:^|,)\s*{re.escape(weapon)}:\{{", table.group(1))}
    assert not missing, f"missing stance-compatible weapon visuals: {sorted(missing)}"


if __name__ == "__main__":
    tests = [value for name, value in sorted(globals().items()) if name.startswith("test_") and callable(value)]
    for test in tests:
        test()
    print(f"player stances regression: ok ({len(tests)} checks)")
