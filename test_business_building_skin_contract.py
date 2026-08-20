"""Deterministic contract for authoritative business-building skins."""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")

FIXED_BUSINESSES = {
    "coffee", "carwash", "barbershop", "pizza", "garage",
    "bar", "club", "warehouse", "casino", "port",
}
CONVERTED_BUSINESSES = {
    "beer_bar", "pawnshop", "bookmaker", "strip_club",
    "gun_shop", "chop_shop", "poker_club", "print_shop",
}


def _block(source: str, start: str, end: str) -> str:
    begin = source.index(start)
    return source[begin:source.index(end, begin)]


def run() -> None:
    poi_catalog = _block(WORLD, "const BUSINESS_POIS = [", "];")
    operation_catalog = _block(
        WORLD, "const PLAYER_BUILDING_OPERATIONS=Object.freeze({", "});")
    assert {match.group(1) for match in re.finditer(r"id: '([^']+)'", poi_catalog)} == FIXED_BUSINESSES
    assert {match.group(1) for match in re.finditer(r"\b([a-z_]+):\{name:", operation_catalog)} == CONVERTED_BUSINESSES

    specs = _block(THREE, "const businessExteriorSpecs=", ";")
    identities = _block(
        THREE, "const addBusinessIdentityArchitecture=", "renderer.domElement.dataset.businessExteriorIdentity")
    for business in FIXED_BUSINESSES:
        assert f"{business}:[" in specs
        assert f"kind==='{business}'" in identities

    resolver = _block(
        THREE, "const resolveEmpireBusinessSkinKey=", "const empireBuildingVisualAt=")
    assert "'legacy_business'" in resolver
    assert "Math.random" not in resolver
    assert "new THREE." not in resolver
    for operation in CONVERTED_BUSINESSES:
        assert f"skin==='{operation}'" in resolver
        assert f"profileMeshes.{operation}=" in THREE
    assert "applyEmpireBusinessFacadeLayout(marker,skin" in THREE
    assert "mesh.visible=src.isHq===false&&key===skin" in THREE

    # The persisted server field remains the sole type authority. Skin choice
    # is derived at the facade boundary and never copied into snapshot state.
    assert "operationType:String(holding.operation_type||'')" in WORLD
    assert "operationType:String(apartmentInfo.operation_type||'')" in WORLD
    assert "operation_type:operationType" in WORLD
    assert "skin_type" not in WORLD and "skinType" not in WORLD

    # Existing shell, door/collision geometry and visible-part budget stay put.
    fit = _block(THREE, "const fitEmpireBuildingFacade=", "const restoreEmpireBuildingSkin=")
    assert "profile.door" in fit and "buildingDoorDefs" in THREE
    assert "facadeFront.visible=false" in fit
    assert "facadeAwning.visible=false" in fit
    assert "for(const window of marker.facadeWindows)window.visible=false" in fit
    assert "new THREE." not in fit
    assert "3d418-authoritative-business-skins" in WORLD


if __name__ == "__main__":
    run()
    print("business building skin contract: 10 fixed + 8 converted + legacy fallback OK")
