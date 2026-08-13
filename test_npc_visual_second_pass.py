"""Regression contract for NPC motion, role silhouettes and weapon handling v371."""

from pathlib import Path


ROOT = Path(__file__).resolve().parent
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")


def run() -> None:
    # Start/stop weight transfer reuses bounded motion state and frame scratch.
    assert "weightLean:0,lastMeasuredSpeed:0" in THREE
    assert "acceleration=(measuredSpeed-(+motion.lastMeasuredSpeed||0))" in THREE
    assert "npcRootSideOffset.set(pose.weightShift||0,0,0)" in THREE
    assert "acceleration-lean-lateral-pelvis-v371" in THREE
    assert "new THREE.Euler(pose.pitch" not in THREE
    assert "new THREE.Vector3(x,pose.bob,z)" not in THREE

    # Weapon pose replaces the entire arm chain, not shoulders alone.
    assert "const leftHand=i*2,rightHand=i*2+1" in THREE
    assert "setPart(npcParts.forearm,rightHand" in THREE
    assert "setPart(npcParts.cuff,rightHand" in THREE
    assert "setPart(npcParts.hand,leftHand" in THREE
    assert "full-arm-chain-support-hand-v371" in THREE

    # Role details stay in fixed population pools.
    for part in ("epaulette", "holster", "medicMark"):
        assert f"{part}:makeInstances" in THREE
    assert "'epaulette','medicMark'" in THREE
    assert "epaulettes-holsters-medical-cross-v371" in THREE
    assert "medic?0xe8f2f4" in THREE and "medic?0x36536a" in THREE

    # Weapon class survives into impacts and profiles muzzle/impact scale.
    assert "impacts.push({ r: wr, c: wc, weapon, parts })" in WORLD
    assert "weapon:String(x.weapon||'pistol')" in WORLD
    assert "weapon-profiled-muzzle-and-impact-v371" in THREE
    assert "impactPower=weaponClass==='rpg'?1.8" in THREE
    assert "flash.scale.set(base*width,base*width,base*length)" in THREE

    # Local audit alternates actors between walking/stopped and fires weapons.
    assert "qaMoving=!visualAudit" in WORLD
    assert "qaFiring=visualAudit&&!!sample.weapon" in WORLD
    assert "three_preview.js?v=3d371-npc-motion-combat" in WORLD


if __name__ == "__main__":
    run()
    print("npc visual second pass regression: ok")
