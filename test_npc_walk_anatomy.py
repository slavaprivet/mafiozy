"""Static and numeric regression contract for the shared walking NPC rig."""

from math import sin
from pathlib import Path


ROOT = Path(__file__).resolve().parent
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")


def run() -> None:
    # Root lift is intentionally much smaller than the explicit swing-foot lift.
    # This protects every role because all pooled humanoids share this root pose.
    samples = [
        abs(sin(step / 1000 * 6.283185307179586)) * (0.018 + pace * 0.006 + panic * 0.008)
        for step in range(1001)
        for pace in (0.0, 1.0)
        for panic in (0.0, 1.0)
    ]
    assert max(samples) <= 0.0320001
    assert "Math.abs(step)*(.018+pace*.006+(panicking?.008:0))*gait" in THREE
    assert "Math.abs(Math.sin(phase))*.13" not in THREE

    # Gang bands and role gear must consume the same cached pose/root as the body.
    assert "pose=npcFramePoses[i]||npcAnimationPose(src,i,t)" in THREE
    assert "setNpcRoot(pose,i,x,z);setPart(npcParts.gangBand" in THREE
    assert "bodyProfile.bodyX*shoulderScale*.9,1,bodyProfile.bodyZ*depthScale*1.42" in THREE
    assert "npcParts.prisonVest" in THREE and "pose.torsoTwist,pose.shoulderSway" in THREE
    assert "npcWalkingRootBobMax" in THREE
    assert "pooled-neck-seam-cuffs-soles-articulated-knees-v370" in THREE

    # The vest keeps the same close fit for every authored body/gender profile.
    # Before this fix its fixed width protruded by roughly 47% on the slim body.
    for body_x, body_z in ((0.8, 0.76), (1.0, 1.0), (1.22, 1.28), (1.18, 1.08)):
        for shoulder_scale, depth_scale in ((1.0, 1.0), (0.82, 0.94)):
            torso_half_width = 0.58 * body_x * shoulder_scale
            vest_half_width = 0.68 * body_x * shoulder_scale * 0.9
            torso_front = 0.58 * body_z * depth_scale
            vest_front = 0.02 + 0.42 * body_z * depth_scale * 1.42
            assert 1.0 <= vest_half_width / torso_half_width <= 1.06
            assert 0.0 < vest_front - torso_front < 0.05

    # The local QA lineup covers slim/heavy civilians, police, tactical police,
    # security, prison staff, empire boss/crew, owner and medic.
    assert "previewnpcanatomy" in WORLD
    for actor_id in (
        "qa_walk_civilian_slim",
        "qa_walk_police_slim",
        "qa_walk_police_heavy",
        "qa_walk_security",
        "qa_walk_prison_guard",
        "qa_walk_boss",
        "qa_walk_crew",
        "qa_walk_owner",
        "qa_walk_medic",
        "qa_walk_civilian_heavy",
    ):
        assert actor_id in WORLD
    assert "three_preview.js?v=3d373-player-stances" in WORLD


if __name__ == "__main__":
    run()
    print("npc walking anatomy regression: ok")
