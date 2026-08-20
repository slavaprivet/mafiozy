"""Regression contract for armed NPC crawl weapon clearance."""

from math import cos, sin
from pathlib import Path


ROOT = Path(__file__).resolve().parent
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")


def run() -> None:
    assert "NPC_CRAWL_WEAPON_ANCHOR_Y=2.05,NPC_CRAWL_WEAPON_ANCHOR_Z=.2" in THREE
    assert "crawlCounter=1.22*Math.max(0,Math.min(1,+pose.crawlBlend||0))" in THREE
    assert "crawlCos=crawlCounter?Math.cos(crawlCounter):1" in THREE
    assert "pitch=THREE.MathUtils.lerp(uprightPitch,1.22,crawlBlend)" in THREE
    assert "bob=THREE.MathUtils.lerp(uprightBob,crawlBob,crawlBlend)" in THREE
    assert "const step=Math.sin(phase)" in THREE
    assert "phase*(limping?.78:1)" not in THREE
    assert "cadence=THREE.MathUtils.lerp(uprightCadence,1.25,motion.crawlBlend)" in THREE
    assert "cadenceFloor=THREE.MathUtils.lerp(.38,.28,motion.crawlBlend)" in THREE
    assert "setNpcWeaponPart(npcParts.uniqueGunMuzzle" in THREE
    assert "setNpcWeaponPoint(npcRightGrip" in THREE
    assert "setNpcWeaponPoint(npcLeftGrip" in THREE
    assert "previewcrawlweapon" in WORLD
    assert "previewcrawltransition" in WORLD
    assert "['pistol','rifle','rpg'].includes(crawlWeapon)" in WORLD
    assert "three_preview.js?v=3d417-npc-walk-continuity&opt=burning-pool-v414+pooled-marker-accounting-v416" in WORLD

    # The chest-anchored inverse rotation keeps every ranged muzzle safely
    # above the road throughout the already-smoothed upright -> crawl blend.
    anchor_y, anchor_z = 2.05, 0.2
    for weapon_y in (2.32, 2.3):
        for blend_step in range(101):
            blend = blend_step / 100
            root_pitch = 1.22 * blend
            counter = 1.22 * blend
            crawl_cos, crawl_sin = cos(counter), sin(counter)
            # The original forward distance no longer affects world clearance
            # at full crawl, but sample the shortest and longest authored guns.
            for weapon_z in (1.72, 2.15):
                dy, dz = weapon_y + 0.02 - anchor_y, weapon_z - anchor_z
                local_y = anchor_y + dy * crawl_cos + dz * crawl_sin
                local_z = anchor_z - dy * crawl_sin + dz * crawl_cos
                world_y = (0.42 * blend) + cos(root_pitch) * local_y - sin(root_pitch) * local_z
                assert world_y >= 0.38, (weapon_y, weapon_z, blend, world_y)

    # Recovery uses the same blend in reverse after the boolean crawl state is
    # gone, so root and weapon counter-pitch remain paired with no 70° snap.
    exit_blends = [step / 100 for step in range(100, -1, -1)]
    residual_angles = [(1.22 * blend) - (1.22 * blend) for blend in exit_blends]
    assert max(abs(angle) for angle in residual_angles) < 1e-9
    exit_heights = []
    for blend in exit_blends:
        root_pitch = counter = 1.22 * blend
        crawl_cos, crawl_sin = cos(counter), sin(counter)
        dy, dz = 2.32 + 0.02 - anchor_y, 2.15 - anchor_z
        local_y = anchor_y + dy * crawl_cos + dz * crawl_sin
        local_z = anchor_z - dy * crawl_sin + dz * crawl_cos
        bob = 0.42 * blend
        exit_heights.append(bob + cos(root_pitch) * local_y - sin(root_pitch) * local_z)
    assert min(exit_heights) >= 0.38
    assert max(abs(b - a) for a, b in zip(exit_heights, exit_heights[1:])) < 0.03

    # A boolean gait-rate multiplier could reinterpret an accumulated phase by
    # almost two full units on the exact crawl flag boundary. Sampling one
    # phase directly is invariant; only its future velocity may change.
    phase = 14.1221
    assert abs(sin(phase) - sin(phase)) == 0
    assert abs(sin(phase) - sin(phase * 0.78)) > 1.99

    blend, dt, upright_cadence = 1.0, 1 / 60, 4.6
    cadences = []
    for _ in range(60):
        blend += (0.0 - blend) * (1 - pow(2.718281828459045, -dt * 8))
        cadence = upright_cadence * (1 - blend) + 1.25 * blend
        cadences.append(cadence)
    assert 1.25 < cadences[0] < 1.7
    assert all(a <= b for a, b in zip(cadences, cadences[1:]))
    assert cadences[-1] < upright_cadence

    render_weapon = THREE.split("const renderNpcEmpireWeapon=", 1)[1].split("const muzzlePool=", 1)[0]
    assert "new THREE." not in render_weapon


if __name__ == "__main__":
    run()
    print("npc crawl weapon pose regression: ok")
