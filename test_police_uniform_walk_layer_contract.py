from pathlib import Path


ROOT = Path(__file__).resolve().parent
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")


def run():
    start = THREE.index("// Police gear uses distinct depth layers")
    end = THREE.index("if(police||securityGuard||prisonStaff||empireBoss)", start)
    gear = THREE[start:end]

    assert "police?.1:.02" in gear
    assert "police?1.5:1.42" in gear
    assert "(police?.78:.62)*bodyProfile.bodyZ*depthScale" in gear
    assert "policeBelt" in gear and ",.24,-pose.hit*.06" in gear
    assert "policeRadio" in gear and ",.78*bodyProfile.bodyZ*depthScale" in gear
    assert "policePatch" in gear and ",.06,0,unitScale" in gear
    assert "vest-forward-badge-radio-belt-separated-v1" in THREE
    assert "npcgear=police-layer-separation-v1" in WORLD

    # Existing pooled parts and gait remain authoritative: this correction
    # only changes their matrices and adds no meshes, materials or frame scans.
    for forbidden in ("new THREE.", "requestAnimationFrame", "scene.traverse", "Object.values"):
        assert forbidden not in gear
    for token in ("npcAnimationPose", "npcFramePoses", "walkingArmNpcCount"):
        assert token in THREE
    for token in ("drawMuzzles", "drawShells", "drawShockwaves", "drawSmokePuffs"):
        assert token in WORLD + THREE

    print("police uniform walk layers: vest, badge, radio, belt and patches separated OK")


if __name__ == "__main__":
    run()
