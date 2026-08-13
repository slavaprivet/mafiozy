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
    assert "three_preview.js?v=3d387-alternating-stance-cycle" in WORLD


def test_renderer_uses_one_cached_stance_rig_and_smooth_blends():
    assert "player-stance-rig" in THREE
    assert "crouchBlend:0,proneBlend:0" in THREE
    assert "playerAnim.proneBlend=expDamp" in THREE
    assert "playerAnim.crouchBlend=expDamp" in THREE
    assert "player-head-look-rig" in THREE
    assert "playerHeadRig.rotation.x=-proneBlend*(1.27+idleBreath*.035)" in THREE
    assert "posePlayerLimb(leftArm,leftShoulder,leftElbow,1.8)" in THREE
    assert "renderer.domElement.dataset.weaponPose='unarmed-crawl'" in THREE
    assert "crawlDrive=proneBlend*Math.abs(playerStep)*gait" in THREE
    assert "playerHeadRig.rotation.y=head.rotation.y" in THREE
    assert "leftKneelShin.visible=rightKneelShin.visible=crouchBlend>.035" in THREE
    assert "leftKneelShin.rotation.set(-1.16-kneeDrive*.34" in THREE
    assert "leftLeg.scale.y=rightLeg.scale.y=THREE.MathUtils.lerp(1,.62,crouchBlend)" in THREE
    assert "gun.rotation.x-=proneBlend*1.39+crouchBlend*.12" in THREE
    assert "gun.position.z-=proneBlend*(proneSupport+kickNorm*.11)" in THREE
    assert "renderer.domElement.dataset.stanceWeaponClearance" in THREE
    assert "renderer.domElement.dataset.stanceFirePose" in THREE
    assert "const poseTwoHandedGrip=(kick=0,reload=0,crawl=0)" in THREE
    assert "poseTwoHandedGrip(Math.min(1.9,kickNorm),activeReloadProgress,armedCrawl)" in THREE
    assert "poseProneSidearmCrawl(armedCrawl)" in THREE
    assert "leftLeg.rotation.x=-.44+crawlStroke*.82" in THREE
    assert "leftLeg.position.z=.28+kneeDrive*.24" in THREE
    assert "dataset.playerStanceCycle" in THREE
    assert "previewstancemotion" in THREE


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
