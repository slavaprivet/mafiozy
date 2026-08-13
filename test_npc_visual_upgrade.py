"""Regression contract for NPC visuals, walking joints and ammunition classes."""

from pathlib import Path


ROOT = Path(__file__).resolve().parent
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")


def run() -> None:
    # Population remains bounded and every new detail is pooled.
    assert "const NPC_CAP=72" in THREE
    for part in ("neck", "coatSeam", "shin", "cuff", "shoeSole"):
        assert f"{part}:makeInstances" in THREE
    assert "'shoeSole','shin','forearm','hand','cuff'" in THREE
    assert "npcThighOffset=new THREE.Vector3()" in THREE
    assert "npcAnkleOffset=new THREE.Vector3()" in THREE
    assert "const legX=.34*hipWidth,hipY=1.38" in THREE
    assert "leftKneeBend" in THREE and "rightKneeBend" in THREE
    assert "articulated-knee-heel-toe-v370" in THREE

    # Generic NPCs use recognisable weapon silhouettes through existing pools.
    for weapon_class in (
        "pistol", "heavy", "revolver", "shotgun", "smg", "tommy",
        "rifle", "sniper", "taser", "rpg", "melee",
    ):
        assert f"{weapon_class}:{{shape:" in THREE
    assert "npcEmpireWeaponShapes[id]||npcGenericWeaponShapes[weaponKey]" in THREE
    assert "semantic-class-silhouettes-shared-pools-v370" in THREE

    # Fired weapon type reaches the bounded shell pool and controls casing form.
    assert "vrot: (Math.random() - 0.5) * 10,\n      weapon," in WORLD
    assert "weapon:String(x.weapon||'pistol')" in WORLD
    assert "shellColorSignatures=new Array(30)" in THREE
    assert "weapon-class-brass-and-hulls-v370" in THREE
    assert "shellPool.instanceColor.needsUpdate=true" in THREE

    # One local lineup exercises anatomy, weapons and ammunition in one tab.
    assert "previewnpcvisual" in WORLD
    assert "previewNpcShellClasses" in WORLD
    for weapon in ("pistol", "rifle", "smg", "shotgun", "golden_tommy", "sniper"):
        assert f"weapon:'{weapon}'" in WORLD
    assert "three_preview.js?v=3d395-gang-squad-integrity" in WORLD


if __name__ == "__main__":
    run()
    print("npc visual upgrade regression: ok")
