"""Regression contract for the NPC appearance scope that gates the first 3D frame."""

from pathlib import Path


ROOT = Path(__file__).resolve().parent
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")


def run() -> None:
    appearance_loop = THREE.index("npcAppearanceSignatures.clear()")
    equipment = THREE.index("if(police||securityGuard||prisonStaff||empireBoss)", appearance_loop)
    scoped_source = THREE[appearance_loop:equipment]
    assert "bodyProfile=NPC_BODY_PROFILES[bodyIndex]" in scoped_source
    assert "shoulderScale=gender?.82:1,depthScale=gender?.94:1" in scoped_source
    assert "shoulderX=.78*bodyProfile.shoulder*shoulderScale" in scoped_source
    assert "playerTeleported=false,playerFrameState=null" in THREE
    assert "const state=playerFrameState=bridge.getPlayerState()" in THREE
    assert "!!playerFrameState?.prone" in THREE
    assert "!!playerFrameState?.crouching" in THREE
    assert "three_preview.js?v=3d395-gang-squad-integrity" in WORLD
    assert "_residentBuildingRouteBudget=1" in WORLD
    assert "if(_residentBuildingRouteBudget<=0)" in WORLD
    assert "if(telemetryDue){renderer.domElement.dataset.buildingDoorMoving" in THREE
    assert "gangMatrixActiveSlots=new Array(NPC_CAP).fill(true)" in THREE
    assert "if(gangMatricesDirty){npcParts.gangAura.instanceMatrix.needsUpdate=true" in THREE


if __name__ == "__main__":
    run()
    print("3D startup NPC scope regression: ok")
