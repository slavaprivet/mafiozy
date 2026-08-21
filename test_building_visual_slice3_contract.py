"""Standalone contract for the third bounded building storefront slice."""

from pathlib import Path


ROOT = Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")


def block(start: str, end: str) -> str:
    left = THREE.index(start)
    return THREE[left:THREE.index(end, left)]


def run() -> None:
    assert "v423 Building slice 3" in WORLD
    assert "building3=coffee-barbershop-pizza-storefront-v1" in WORLD
    assert "v=3d418-authoritative-business-skins" in WORLD
    assert "facade=depth-roof-sign-v1" in WORLD

    catalog = block("const businessExteriorSpecs=", "const bounds=")
    for marker in (
        "coffee:'recessed-cafe-bays-cornice'",
        "barbershop:'framed-display-bays-stepped-crown'",
        "pizza:'warm-window-bays-brick-chimney'",
    ):
        assert marker in catalog
    assert "buildingSlice3Profiles" in catalog
    assert "buildingSlice3Budget='storefronts:3,build-time-static-spatial-merge,frame-allocations:0,frame-scans:0,lights:0,materials:0,programs:0'" in catalog

    storefront = block("const addThirdBuildingSliceStorefront=", "const sign=")
    for kind in ("coffee", "barbershop", "pizza"):
        assert f"targetKind==='{kind}'" in storefront
    for forbidden in ("new THREE.", "PointLight", "SpotLight", "requestAnimationFrame"):
        assert forbidden not in storefront
    assert "addThirdBuildingSliceStorefront(kind)" in THREE
    assert "queueStaticBuildingDetail(child)" in THREE

    assert "buildingDoorDefs=bridge?.getBuildingDoors?.()||[]" in THREE
    assert "operation_type" in WORLD
    assert "function drawMuzzles" in WORLD
    assert "3D animation v417: NPC walk start/stop blends one pose chain" in THREE
    assert "visual=roads-trees-smoke-v1" in WORLD
    assert "lighting=authoritative-circadian-v1" in WORLD
    print("building visual slice 3: coffee/barbershop/pizza storefront depth OK")


if __name__ == "__main__":
    run()
