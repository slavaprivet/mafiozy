"""Static contract for bounded Visual B materials, glass and soft shadows."""

from pathlib import Path


ROOT = Path(__file__).resolve().parent
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")


def block(start: str, end: str) -> str:
    left = THREE.index(start)
    return THREE[left:THREE.index(end, left)]


def run() -> None:
    families = block("const architectureFamilies=[", "architectureFamilyById")
    for family in ("glass", "brick", "limestone", "concrete", "deco", "industrial"):
        assert f"id:'{family}'" in families
        assert "nightEnv:" in families
    assert families.count("physical:true") == 1
    assert "id:'glass'" in families and "clearcoat:.92" in families

    material = block("const wallOptions=", "wall.userData.mfzOcclusionOpacity")
    assert "new THREE.MeshPhysicalMaterial" in material
    assert "new THREE.MeshStandardMaterial" in material
    assert "architectureFamily.physical?" in material
    assert "transparent:" not in material and "transmission:" not in material
    assert "mfzFacadeDayEnv" in material and "mfzFacadeNightEnv" in material
    assert "mfzFacadeDayEmissive" in THREE and "mfzFacadeNightEmissive" in THREE
    assert "buildingMaterialBudget='meshes:0,geometries:0,textures:0,draws:0,lights:0,programs:1,frame-allocations:0'" in THREE

    shadow = block("const contactShadowCanvas=", "const makeContactShadow=")
    assert shadow.count("new THREE.CanvasTexture") == 1
    assert "contactShadowContext.scale(1,.72)" in shadow
    assert "single-atlas-elliptic-soft-v1" in THREE
    assert "THREE.PCFSoftShadowMap" in THREE
    assert "sun.shadow.mapSize.set(1536, 1536)" in THREE
    assert "shadowCadence=220" in THREE
    assert "shadowUpdateCount++" in THREE
    assert "memoryGeometries" in THREE and "memoryTextures" in THREE

    palette = block("const updateDayNight=", "if(interiorLightingActive)")
    assert "m.envMapIntensity=THREE.MathUtils.lerp" in palette
    assert "mfzFacadeNightEnv" in palette and "mfzFacadeDayEnv" in palette
    assert "mfzFacadeNightEmissive" in palette and "mfzFacadeDayEmissive" in palette
    assert "new THREE." not in palette

    # Visual B is presentation-only and keeps the Visual A and authoritative
    # business routes intact.
    assert "operationType:String(holding.operation_type||'')" in WORLD
    assert "operationType:String(apartmentInfo.operation_type||'')" in WORLD
    assert "legacy_business" in THREE
    assert "facade=depth-roof-sign-v1" in WORLD
    assert "material=physical-glass-soft-shadow-v1" in WORLD


if __name__ == "__main__":
    run()
    print("Visual B building materials/glass/shadows contract: OK")
