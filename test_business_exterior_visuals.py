"""Regression contract for switchable exterior kits and bounded ruin FX."""

from pathlib import Path


ROOT = Path(__file__).resolve().parent
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")


def run() -> None:
    operations = (
        "beer_bar", "pawnshop", "bookmaker", "strip_club",
        "gun_shop", "chop_shop", "poker_club", "print_shop",
    )
    for operation in operations:
        assert f"profileMeshes.{operation}=" in THREE

    # The real shell remains in place; only its adaptive frontage and material
    # skin are rebuilt from the latest authoritative operationType.
    assert "preserved-original-3d-adaptive-frontage" in THREE
    assert "marker.currentOperation!==operation" in THREE
    assert "marker.operationChangedAt=t" in THREE
    assert "empireBusinessSkinKeys" in THREE
    assert "resolveEmpireBusinessSkinKey" in THREE
    assert "mesh.visible=src.isHq===false&&key===skin" in THREE

    # Destruction uses two global pools, not meshes allocated on impact.
    assert "BUSINESS_RUIN_DUST_PER=4" in THREE
    assert "BUSINESS_RUIN_DEBRIS_PER=6" in THREE
    assert "new THREE.InstancedMesh(new THREE.SphereGeometry" in THREE
    assert "2-draw-call-instanced-dust-debris-v404" in THREE
    assert "closedStartedAt" in THREE and "ruinAge" in THREE
    assert "marker.closedArtSecond!==closedSeconds" in THREE
    assert "closedSeconds<=0&&marker.closedArtSecond!==-1" in THREE
    assert "marker.label.scale.set(11.2,2.24,1)" in THREE
    assert THREE.count("gradient=g.createLinearGradient") >= 1
    assert "marker.facadeDark.color.setHex(0x080b10)" in THREE
    assert "businessRuinMatricesDirty" in THREE
    assert "businessRuinDust.visible=animatedBusinessRuins>0" in THREE
    assert "marker.facadeBand.visible=false" in THREE

    assert "previewbuildingpurpose" in WORLD
    assert "previewbuildingclosed" in WORLD
    assert "three_preview.js?v=3d418-authoritative-business-skins" in WORLD


if __name__ == "__main__":
    run()
    print("business exterior visuals regression: ok")
