from pathlib import Path


ROOT = Path(__file__).resolve().parent
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")


def between(text, start, end):
    return text.split(start, 1)[1].split(end, 1)[0]


def run():
    identity = between(THREE, "const addProceduralBuildingIdentity=", "const STATIC_DETAIL_CHUNK_WORLD=")
    brick = between(identity, "// Bank-reference composition", "}else if(familyId==='limestone'){")

    assert "split stone plinth" in brick
    assert "single-entry-split-plinth-corner-piers-hipped-roof-v2" in brick
    assert "const brickFormal=(seed&1)===0" in brick
    assert "const pierH=" in brick
    assert "front+.2,pierW,.28,pierH" in brick
    assert "side<0?identityStone:accent" not in brick
    assert "w*.44,d*.46,.4" not in brick
    assert "front+.11,w*.9,.18,.52" not in brick
    assert "for(let floor=" not in brick
    assert "new THREE." not in brick
    assert "if(familyId!=='brick'){" in identity

    doors = between(WORLD, "function _residentBuildingDoors()", "function _residentDoorById")
    assert "door_${r}_${c}_1" not in doors
    assert "Exactly one authoritative pavement door" in WORLD
    assert "single-authoritative-flush-dark-void-v1" in THREE
    first_floor = between(identity, "if(familyId==='glass'){", "// Building modernization slice 1")
    assert "const brickDoorGap=Math.min(w*.7,Math.max(3.2,w*.3))" in first_floor
    assert "for(const side of [-1,1])add(x+side*brickShoulderX,front+.08,brickShoulderW,.18,.52" in first_floor
    assert "w*.12,.16,2.3,identityDark,1.7" in first_floor
    assert "add(x,front+.08,w*.86,.24,.68" not in first_floor
    assert "npcgear=police-layer-separation-v1&brick=bank-reference-massing-v2" in WORLD

    for forbidden in ("new THREE.PointLight", "new THREE.SpotLight", "requestAnimationFrame", "scene.traverse"):
        assert forbidden not in brick
    assert "drawMuzzles" in WORLD + THREE
    assert "operation_type" in WORLD

    print("brick bank-reference building: split entry plinth and bounded corner depth OK")


if __name__ == "__main__":
    run()
