"""Static contract for bounded Visual C roads, trees and smoke."""

from pathlib import Path


ROOT = Path(__file__).resolve().parent
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")


def block(start: str, end: str) -> str:
    left = THREE.index(start)
    return THREE[left:THREE.index(end, left)]


def run() -> None:
    roads = block("const roadAxes=", "// Загородные кварталы")
    assert "const verticalRoads=" in roads and "horizontalRoads=" in roads
    assert "curbDetailDefs" in roads and "drainDefs.length<80" in roads
    assert "if(curbDetailDefs.length>404)" in roads
    assert "curbDetailDefs.length=404" in roads
    assert "new THREE.InstancedMesh" in roads
    assert "addRoadBoxInstances(new THREE.BoxGeometry(1,1,1),curbMat" in roads
    assert "new THREE.BoxGeometry(.5,.055,1.08),roadHardwareMaterial" in roads
    assert "visualCRoadProfile='instanced-curb-runs-drains-wear-patches-v1'" in roads
    assert "collisionProbe" not in roads and "route" not in roads and "door" not in roads

    trees = block("const streetTreeDefs=[]", "// Detailed shootable hydrants")
    assert "streetTreeDefs.length<42" in trees
    assert "new THREE.LatheGeometry" in trees
    assert "streetTreeTrunkGeometry" in trees
    assert "streetTreeCrownGeometry" in trees
    assert trees.count("staticInstances(streetTree") == 4
    assert "visualCTreeProfile='lathed-root-flare-three-crown-deterministic-palette-v1'" in trees
    assert "resident:${streetTreeDefs.length*5}/210,draws:5" in trees
    assert "new THREE.PointLight" not in trees

    atmosphere = block("const industrialBuildings=", "// Keep signals readable")
    assert "styleId==='industrial'" in atmosphere and "p.id==='factory'" in atmosphere
    assert "Math.min(72,smokeSources.length*10)" in atmosphere
    assert "steamSources=manholeDefs.slice(0,20)" in atmosphere
    assert "smokeCullDistanceSq=110*110" in atmosphere
    assert "steamCullDistanceSq=82*82" in atmosphere
    update = atmosphere[atmosphere.index("const updateAtmosphere="):]
    assert "for(let i=0;i<smokeState.length;i++)" in update
    assert "for(let i=0;i<steamState.length;i++)" in update
    assert "for(let i=0;i<leafState.length;i++)" in update
    assert ".forEach(" not in update
    assert "smokePoints.visible=visibleSmoke>0" in update
    assert "steamPoints.visible=visibleSteam>0" in update
    assert "fixed-float32-pools-distance-culled-deterministic-cleanup-v1" in update
    assert "smokeSources.push" not in atmosphere

    # Vehicle wreck smoke remains on the pre-existing bounded source lifecycle.
    assert "for(let i=0;i<12;i++){const fire=" in THREE
    assert "createPooledVehicleFx(groundFireSmokeGeometry" in THREE
    assert "depthWrite:false}),5);" in THREE
    assert "effectLifecycleProfile='bounded-source-expiry-v352'" in THREE

    exact_budget = (
        "visualCBudget='meshes:2,geometries:2,materials:0,textures:0,"
        "lights:0,programs:0,draws:2,frame-allocations:0'"
    )
    assert exact_budget in THREE
    assert "visualCPools='curbs:404,drains:80,trees:42x5,smoke:72,steam:60,vehicle-smoke:12x5'" in THREE

    # Concurrent tokenizer and bands-ruin authority must survive this renderer-only pass.
    assert "String(chat).match(/\\S+/g) || []" in WORLD
    assert "Global ruin also releases that family's player wars before any comeback." in WORLD
    assert "Checkpoint and final resolve revalidate war/ownership generation first." in WORLD
    walking = WORLD[WORLD.index("function drawWalkingLegs("):WORLD.index("function spawnWorldC4Explosion(")]
    assert "const firstSide = plusFootY < minusFootY ? 1 : -1;" in walking
    assert "for (let legIndex = 0; legIndex < 2; legIndex++)" in walking
    assert "[-1, 1].map" not in walking and "legs.sort" not in walking
    projectiles = WORLD[WORLD.index("function updateProjectiles("):WORLD.index("function _bulletY(")]
    assert "const bulletAge = burnNow - (+b.born || 0);" in projectiles
    assert "impactHoldUntil=b.impactHoldUntil||burnNow+72" in projectiles
    assert "born:burnNow" in projectiles
    bullets = WORLD[WORLD.index("function drawBullets("):WORLD.index("function drawMuzzles(")]
    assert "const centerX = stage.clientWidth / 2;" in bullets
    assert "const headX = centerX + (headC - headR) * TS * 0.5 - cam.x;" in bullets
    assert "const tailX = centerX + (tailC - tailR) * TS * 0.5 - cam.x;" in bullets
    assert "w2s(" not in bullets
    assert "facade=depth-roof-sign-v1" in WORLD
    assert "material=physical-glass-soft-shadow-v1" in WORLD
    assert "visual=roads-trees-smoke-v1" in WORLD


if __name__ == "__main__":
    run()
    print("Visual C roads/trees/smoke contract: OK")
