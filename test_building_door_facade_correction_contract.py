from pathlib import Path


ROOT = Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")


def section(text, start, end):
    return text.split(start, 1)[1].split(end, 1)[0]


def run():
    doors = section(WORLD, "function _residentBuildingDoors()", "function _residentDoorById")
    assert "Exactly one authoritative pavement door" in WORLD
    assert "door_${r}_${c}_0" in doors
    assert "door_${r}_${c}_1" not in doors
    assert "queue.length>=12" not in doors
    assert "addAuthoredDoor" in doors and "const existing=doors.find" in doors

    pooled = section(THREE, "const buildingDoorDefs=", "const syncBuildingDoorTargets=")
    assert "new THREE.BoxGeometry(1,1,.025)" in pooled
    assert "color:0x000102" in pooled
    assert "DOOR_LEAF_PLANE=.055" in pooled
    assert "DOOR_VOID_PLANE=.018" in pooled
    assert "buildingDoorProfile='single-authoritative-flush-dark-void-v1'" in pooled
    assert "DOOR_H*.5,DOOR_VOID_PLANE" in pooled
    assert "DOOR_H*.5,.05,DOOR_FRAME" in pooled

    depth = section(THREE, "const addArchitecturalFacadeDepth=", "const addSecondBuildingSliceDepth=")
    assert "six-family-restraint-single-cornice-door-clear-static-merged-v2" in depth
    assert "for(let floor=" not in depth
    assert "second grille" in depth

    slice_two = section(THREE, "const addSecondBuildingSliceDepth=", "const addProceduralBuildingIdentity=")
    assert "visibleFloors" not in slice_two
    assert "for(let floor=" not in slice_two
    assert "for(let rail=" not in slice_two

    identity = section(THREE, "const addProceduralBuildingIdentity=", "const STATIC_DETAIL_CHUNK_WORLD=")
    assert "wide central doorway gap" in identity
    assert "single-authoritative-flush-dark-void-v1" in THREE

    # Preservation gates for unrelated renderer/world contracts.
    for token in ("drawMuzzles", "drawShells", "drawShockwaves", "drawSmokePuffs"):
        assert token in WORLD + THREE
    for token in ("operation_type", "_gameMinutes", "residentEligible"):
        assert token in WORLD

    print("building door/facade correction: one flush door, dark void, restrained depth OK")


if __name__ == "__main__":
    run()
