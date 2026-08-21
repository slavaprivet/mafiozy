from pathlib import Path


ROOT = Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")


def run() -> None:
    assert "v421 Building slice 1" in WORLD
    assert "building=brick-limestone-glass-depth-v2" in WORLD
    assert "v=3d418-authoritative-business-skins" in WORLD
    assert "facade=depth-roof-sign-v1" in WORLD
    assert "function drawMuzzles" in WORLD
    assert "Pair peace also terminalizes only that player's HQ assault token." in WORLD
    assert "buildingSlice1Profiles" in THREE
    assert "buildingSlice1Samples=new Map()" in THREE
    assert "buildingSlice1FamilyIds=new Set(['brick','limestone','glass'])" in THREE
    assert "dataset.buildingSlice1Samples" in THREE
    assert "buildingSlice1Budget='families:3,build-time-static-spatial-merge,frame-allocations:0,frame-scans:0,lights:0,materials:0'" in THREE
    for marker in (
        "deep_mullions_shadowbox_roof_screen",
        "corbel_sills_arched_lintels_parapet",
        "pediments_quoins_balustrade",
    ):
        assert marker in THREE
    assert "if(familyId==='brick')" in THREE
    assert "else if(familyId==='limestone')" in THREE
    assert "else if(familyId==='glass')" in THREE
    assert "queueStaticBuildingDetail(child)" in THREE
    assert "operation_type" in WORLD
    assert "3D animation v417: NPC walk start/stop blends one pose chain" in THREE
    assert "const crawlBlend=Math.max(0,Math.min(1,+motion?.crawlBlend" in THREE
    assert "npcAnimationLod='near-ambient-mid-gait-far-root'" in THREE
    print("building visual slice 1: brick/limestone/glass bounded depth OK")


if __name__ == "__main__":
    run()
