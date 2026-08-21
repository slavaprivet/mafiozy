"""Standalone static contract for generic building modernization slice 2."""

from pathlib import Path


ROOT = Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")


def block(start: str, end: str) -> str:
    left = THREE.index(start)
    return THREE[left:THREE.index(end, left)]


def run() -> None:
    assert "v422 Building slice 2" in WORLD
    assert "building2=concrete-deco-industrial-depth-v1" in WORLD
    assert "v=3d418-authoritative-business-skins" in WORLD
    assert "facade=depth-roof-sign-v1" in WORLD

    catalog = block("const buildingVisualProfileCatalog=Object.freeze({", "const roofMat")
    for marker in (
        "recessed_frames_mechanical_screen",
        "stepped_fins_glazed_portal",
        "loading_ribs_clerestory_duct_screen",
    ):
        assert marker in catalog
    assert "buildingSlice2Profiles" in catalog
    assert "buildingSlice2Budget='families:3,build-time-static-spatial-merge,frame-allocations:0,frame-scans:0,lights:0,materials:0,programs:0'" in catalog

    depth = block("const addSecondBuildingSliceDepth=", "const addProceduralBuildingIdentity=")
    for family in ("concrete", "deco", "industrial"):
        assert f"familyId==='{family}'" in depth
    for forbidden in ("new THREE.", "new Mesh", "PointLight", "SpotLight", "requestAnimationFrame"):
        assert forbidden not in depth
    assert "addSecondBuildingSliceDepth(x,z,w,d,h,familyId,accent,add)" in THREE
    assert "queueStaticBuildingDetail(child)" in THREE

    # Authoritative gameplay and earlier visual contracts remain independent.
    assert "buildingDoorDefs=bridge?.getBuildingDoors?.()||[]" in THREE
    assert "mainBuilding.userData.building=buildingMeta" in THREE
    assert "operation_type" in WORLD
    assert "function drawMuzzles" in WORLD
    assert "3D animation v417: NPC walk start/stop blends one pose chain" in THREE
    assert "visual=roads-trees-smoke-v1" in WORLD
    assert "lighting=authoritative-circadian-v1" in WORLD
    print("building visual slice 2: concrete/deco/industrial bounded depth OK")


if __name__ == "__main__":
    run()
