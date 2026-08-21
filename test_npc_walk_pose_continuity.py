"""Static and numeric regression contract for NPC walk pose continuity."""

import re
from math import cos, exp, sin
from pathlib import Path


ROOT = Path(__file__).resolve().parent
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")


def lerp(a: float, b: float, amount: float) -> float:
    return a + (b - a) * amount


def pose(phase: float, idle_phase: float, gait: float) -> tuple[float, ...]:
    step, idle, pace = sin(phase), sin(idle_phase), 0.62
    bob = lerp(idle * 0.012, abs(step) * (0.018 + pace * 0.006), gait)
    shoulder = lerp(idle * 0.008, cos(phase) * (0.025 + pace * 0.012), gait)
    arm = lerp(idle * 0.025, -step * (0.3 + pace * 0.1), gait)
    lift = max(0.0, step) ** 1.35 * 0.21 * gait
    foot = (arm * (0.08 if step < 0 else 0.48) - lift * 0.28) * gait
    root_pitch = -(0.025 + pace * 0.035) * gait
    return bob, shoulder, arm, lift, foot, root_pitch


def run() -> None:
    assert "poseGait=!dead&&!cowering&&!surrendering&&!helping?gait:0" in THREE
    assert "uprightBob=THREE.MathUtils.lerp(idle*.012,walkBob,poseGait)" in THREE
    assert "shoulderSway=THREE.MathUtils.lerp(idle*.008" in THREE
    assert "THREE.MathUtils.lerp(idle*.025,-step*naturalArmSwing,poseGait)" in THREE
    assert "leftLift=Math.pow(Math.max(0,step),1.35)" in THREE
    assert "walking?Math.pow(Math.max(0,step)" not in THREE
    hook = re.search(
        r'<script type="module" src="(three_preview\.js\?[^\"]+)"></script>', WORLD
    )
    assert hook is not None
    query = hook.group(1).split("?", 1)[1]
    params = dict(part.split("=", 1) for part in query.split("&") if "=" in part)
    assert params.get("v") == "3d418-authoritative-business-skins"
    assert params.get("opt") == "burning-pool-v414+pooled-marker-accounting-v416"
    assert params.get("facade") == "depth-roof-sign-v1"

    # The former boolean boundary could swap unrelated idle/walk waves. The
    # shared scalar must keep every linked endpoint continuous around .035.
    before = pose(19.73, 4.91, 0.0349)
    after = pose(19.73, 4.91, 0.0351)
    assert max(abs(a - b) for a, b in zip(before, after)) < 0.0001

    # Exercise a complete start/stop at a deliberately large accumulated phase.
    dt, phase, idle_phase, gait = 1 / 60, 37.8, 8.2, 0.0
    frames = []
    for frame in range(300):
        target = 0.91 if frame < 150 else 0.0
        rate = 14 if target else 7
        gait = lerp(gait, target, 1 - exp(-dt * rate))
        phase += dt * 9.4 * max(0.38, gait)
        idle_phase += dt * 1.8
        frames.append(pose(phase, idle_phase, gait))
    deltas = [
        max(abs(a - b) for a, b in zip(previous, current))
        for previous, current in zip(frames, frames[1:])
    ]
    assert max(deltas) < 0.06

    pose_block = THREE.split("const npcLifeAnimationPose=", 1)[1].split(
        "const npcAnimationPose=", 1
    )[0]
    assert "new THREE." not in pose_block


if __name__ == "__main__":
    run()
    print("npc walk pose continuity regression: ok")
