"""Static regression for readable, impact-synchronised NPC gang firefights."""

from pathlib import Path


ROOT = Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")


def run() -> None:
    field_start = WORLD.index("function _empireFieldCombatThink")
    field_end = WORLD.index("function _applyEmpirePlayerWeaponHit", field_start)
    field = WORLD[field_start:field_end]

    assert "!_npcPathPassable(n.r,n.c,target.r,target.c,_empireBossPassable)" in field
    assert "fullSizeNpc:true,targetActor:hit?target:null" in field
    assert "const visualSpeed=Math.max(11.5,Math.min(15.5" in field
    assert "setTimeout(()=>" in field
    assert "spawnImpact(hitR,hitC,weapon,true);_hitEmpireCombatant" in field
    assert field.index("spawnBullet(") < field.index("setTimeout(()=>")
    assert "document.documentElement.dataset.empireBallisticImpact" in field

    projectile_start = WORLD.index("function updateProjectiles")
    projectile_end = WORLD.index("function draw", projectile_start)
    projectile_update = WORLD[projectile_start:projectile_end]
    assert "if(b.targetActor)" in projectile_update
    assert "b.r=(+b.startR||0)+(point.r-(+b.startR||0))*p" in projectile_update
    assert "targetActor:opts.targetActor?{ref:opts.targetActor}:null" in WORLD
    assert "&& !fullSizeNpc" in WORLD

    assert "npc._empireBoss||npc._empireCrew||npc._empireHoldingGuard" in WORLD
    assert "readability=src.empireBoss?1.28:" in THREE
    assert "src.empireCrew||src.empireHoldingGuard||src.gang?1.16:1" in THREE
    assert "3d392-boss-war-target-label" in WORLD


if __name__ == "__main__":
    run()
    print("npc gang ballistics regression: OK")
