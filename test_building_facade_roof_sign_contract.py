"""Static contract for bounded Visual A building architecture."""

from pathlib import Path


ROOT = Path(__file__).resolve().parent
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")


def block(start: str, end: str) -> str:
    left = THREE.index(start)
    right = THREE.index(end, left)
    return THREE[left:right]


def run() -> None:
    catalog = block("const buildingVisualProfileCatalog=Object.freeze({", "const roofMat")
    expected = {
        "glass": "terraced_glass",
        "brick": "hipped_masonry",
        "limestone": "classical_crown",
        "concrete": "mechanical_step",
        "deco": "deco_tiers",
        "industrial": "sawtooth_plant",
    }
    for family, roof in expected.items():
        assert f"{family}:Object.freeze(" in catalog
        assert f"roofForm:'{roof}'" in catalog

    # Generic architecture is visual-only. Business identity stays on the two
    # already-authoritative routes and malformed legacy remains deterministic.
    assert "fixed businesses remain biz_id" in THREE
    assert "converted holdings remain persisted operation_type" in THREE
    assert "operationType:String(holding.operation_type||'')" in WORLD
    assert "operationType:String(apartmentInfo.operation_type||'')" in WORLD
    assert "legacy_business" in THREE

    depth = block("const addArchitecturalFacadeDepth=", "const addProceduralBuildingIdentity=")
    assert "buildingVisualProfileCatalog[familyId]" in depth
    assert "authoritative central doorway" in depth
    assert "new THREE." not in depth
    assert "buildingFacadeDepthProfiles='six-family-restraint-single-cornice-door-clear-static-merged-v2'" in depth
    assert "for(let floor=" not in depth
    assert "addArchitecturalFacadeDepth(x,z,w,d,h,familyId,accent)" in THREE

    roof = block("const addRoofDetails=", "const themedWhite=")
    assert "buildingVisualProfileCatalog[familyId]" in roof
    assert "roofMechanicalMat" in roof and "roofFanMat" in roof and "roofTankMat" in roof
    assert "new THREE.MeshStandardMaterial" not in roof
    assert "new THREE.MeshBasicMaterial" not in roof
    assert "new THREE.PointLight" not in roof
    assert "buildingRoofProfiles='glass:terraced" in roof
    assert "addRoofDetails(x,z,w,d,h,roofVariant,architectureFamily.id)" in THREE

    sign = block("const roofMountedSign=", "const apartmentLabelSprite=")
    assert "new THREE.Sprite" not in sign
    assert "roofSignBackingGeometries.get(profile)" in sign
    assert "roofSignFaceGeometry" in sign
    assert "attachedProfile:`roof-${profile}-two-draw`" in sign
    assert "roofSignCache=`textures:" in sign
    assert "new THREE.BoxGeometry" not in sign
    assert "new THREE.PlaneGeometry" not in sign
    assert "signCv.width=512;signCv.height=128" not in THREE
    assert "genericBuildingSigns='physical-roof-board-two-draw-no-sprite-v1'" in THREE
    assert "sgn=roofMountedSign(sign,signColor" in THREE

    # Cached sign resources survive streamed-sector eviction, while ordinary
    # sector meshes retain the existing dispose path and spatial batching.
    assert "roofSignHeightProfiles=Object.freeze({small:.9,medium:1.35,large:1.75})" in THREE
    assert "roofSignFaceMaterialCache=new Map()" in THREE
    assert "geometry.userData.mfzPersistent=true" in THREE
    assert "!object.geometry.userData?.mfzPersistent" in THREE
    assert "!value.userData?.mfzPersistent" in THREE
    assert "queueStaticBuildingDetail(child)" in THREE
    assert "STATIC_DETAIL_MERGE_CAP=48" in THREE

    # Visual A owns this exact cache suffix without rewriting the older gait
    # or business-skin cache identities.
    assert "3d418-authoritative-business-skins" in WORLD
    assert "opt=burning-pool-v414+pooled-marker-accounting-v416" in WORLD
    assert "facade=depth-roof-sign-v1" in WORLD

    # The local PC fixture must expose the renderer instead of leaving the
    # mode-selection sheet over the deterministic day/night camera.
    preview = WORLD[WORLD.index("previewEnterBuildingPurpose("):]
    assert "modeModal.style.display='none'" in preview[:1800]


if __name__ == "__main__":
    run()
    print("Visual A building facade/roof/sign contract: OK")
