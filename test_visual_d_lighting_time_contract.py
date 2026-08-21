"""Static contract for bounded Visual D authoritative lighting and time."""

from pathlib import Path


ROOT = Path(__file__).resolve().parent
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")


def block(start: str, end: str) -> str:
    left = THREE.index(start)
    return THREE[left:THREE.index(end, left)]


def run() -> None:
    lighting = block("const daySky=", "addEventListener('error'")
    assert "bridge?.getEnvironmentState?.()" in lighting
    assert "lastServerHour+lastServerMinute/60" in lighting
    assert "timeSampleAt=t+250" in lighting
    assert "Math.sin((hour-6)/24*Math.PI*2)" in lighting
    assert "targetDawn=" in lighting and "targetDusk=" in lighting
    assert "continuous-authoritative-circadian" in lighting
    assert "Date.now" not in lighting and "new Date" not in lighting
    assert "setInterval" not in lighting and "requestAnimationFrame" not in lighting
    update = lighting[lighting.index("const updateDayNight="):]
    assert "new THREE." not in update

    assert "lampsScheduledOn=hour<7||hour>=17" in lighting
    assert "on-17-07':'off-07-17" in lighting
    for channel in (
        "scene.background.copy(skyColor)",
        "scene.fog.color.copy(skyColor)",
        "skyLight.color.setRGB",
        "sun.color.copy(daySun)",
        "renderer.toneMappingExposure=",
        "scene.environmentIntensity=",
        "environmentFogDensity=",
    ):
        assert channel in lighting
    assert "FACADE_GRADE_BATCH=32" in lighting
    assert "SHOP_GRADE_BATCH=18" in lighting
    assert "facadeMaterials.forEach" not in lighting
    assert "shopMaterials.forEach" not in lighting

    exact_budget = (
        "visualDBudget='meshes:0,geometries:0,materials:0,textures:0,lights:0,"
        "programs:0,draws:0,render-targets:0,frame-allocations:0'"
    )
    assert exact_budget in THREE
    assert "visualDBloom='rejected-no-bounded-existing-postprocess-path'" in THREE
    assert "visualDDegrade='shadows-query,pc-mobile-profile,fps-cadence,direct-aces,canvas-rollback'" in THREE
    assert "new THREE.WebGLRenderTarget" not in THREE
    for forbidden in ("EffectComposer", "UnrealBloomPass", "RenderPass", "ShaderPass"):
        assert forbidden not in THREE
    assert "renderer.setRenderTarget(null);renderer.render(" in THREE
    assert "palettePipeline='direct-aces-srgb'" in THREE

    # Preserve the existing renderer, shadow and outdoor-light budgets.
    assert "renderer.shadowMap.type = THREE.PCFSoftShadowMap" in THREE
    assert "const OUTDOOR_POINT_LIGHT_CAP=16" in THREE
    assert "shadowCadence=220" in THREE
    assert "visualCBudget='meshes:2,geometries:2,materials:0,textures:0,lights:0,programs:0,draws:2,frame-allocations:0'" in THREE
    assert "visualCPools='curbs:404,drains:80,trees:42x5,smoke:72,steam:60,vehicle-smoke:12x5'" in THREE

    # World remains the sole mutable city clock and the 3D bridge is read-only.
    clock = WORLD[WORLD.index("let _gameMinutes ="):WORLD.index("function getNightAlpha()")]
    assert "_gameMinutes = (_gameMinutes + 1) % 1440" in clock
    assert "setInterval(updateGameClock, 1000)" in clock
    env = WORLD[WORLD.index("getEnvironmentState() {"):WORLD.index("getCustomGangHqs()", WORLD.index("getEnvironmentState() {"))]
    assert "Number.isFinite(_gameMinutes)" in env
    assert "hour, minute: Math.floor(safeMinutes % 60)" in env
    assert "_gameMinutes =" not in env
    assert "lighting=authoritative-circadian-v1" in WORLD
    assert "facade=depth-roof-sign-v1" in WORLD
    assert "material=physical-glass-soft-shadow-v1" in WORLD
    assert "visual=roads-trees-smoke-v1" in WORLD
    assert "Guard roster writes expire only their exact holding's overdue raid locks." in WORLD
    smoke = WORLD[WORLD.index("function drawSmokePuffs() {"):WORLD.index("function drawShells() {")]
    assert "const stage = document.getElementById('stage');" in smoke
    assert "const sx = cx + (pc - pr) * TS * 0.5 - cam.x;" in smoke
    assert "const sy = cy + (pc + pr) * TS * 0.5 * ISO_Y - cam.y;" in smoke
    assert "w2s(" not in smoke


if __name__ == "__main__":
    run()
    print("Visual D lighting/time contract: OK")
