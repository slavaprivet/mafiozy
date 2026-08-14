"""Runtime checks for symmetric interior projectile arrival and dodge."""

from pathlib import Path
import json
import subprocess


ROOT = Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")


def extract_function(name: str) -> str:
    start = WORLD.index(f"function {name}(")
    brace = WORLD.index("{", start)
    depth = 0
    quote = None
    escaped = False
    for pos in range(brace, len(WORLD)):
        char = WORLD[pos]
        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = None
            continue
        if char in "'\"`":
            quote = char
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return WORLD[start:pos + 1]
    raise AssertionError(name)


def run() -> None:
    queue = extract_function("_queuePlayerInteriorBallisticHit")
    raid_fire = extract_function("_fireBusinessRaidRound")
    hit = extract_function("_hitInteriorNpc")
    assert "playerBallistic&&arrivalTarget&&!arrivalApplied" in hit
    assert "target.isRaidPlayer?+player.r:+target.r" in raid_fire
    assert "Math.hypot(currentR-tr,currentC-tc)>.72" in raid_fire
    assert "speed:visualSpeed" in raid_fire
    assert "currentWeapon,false,true" in WORLD
    assert "firedWeapon,false,true" in WORLD

    script = f"""
let clock=1000,callbacks=[],impacts=0,damageCalls=0,hurtCalls=0,BULLET_SPEED=20;
const performance={{now:()=>clock}},document={{documentElement:{{dataset:{{}}}}}},player={{r:5,c:5}},currentWeapon='rifle';
const target={{id:'raid-target',r:5,c:11,hp:50,dead:false,businessRaidSide:'defender'}},bi={{npcs:[target],businessInteriorRaid:{{}}}};let _buildingInt=bi,myDead=false;
function weaponMuzzleD(){{return .5;}} function weaponProfile(){{return {{bulletSpeed:15}};}}
function _scheduleBallisticFx(ms,fn){{callbacks.push({{ms,fn}});}} function setTimeout(fn,ms){{callbacks.push({{ms,fn}});}}
function spawnImpact(){{impacts++;}} function _showCurrentShotCritical(){{}}
{queue}
function _damageBusinessRaidNpc(_bi,_state,n,dmg){{damageCalls++;n.hp-=dmg;}}
function _hitNpcEmpireAssaultNpc(n,dmg){{damageCalls++;n.hp-=dmg;}}
function _igniteInteriorCharacter(){{}} function sendInput(){{}}
let _majorInteriorObjectId=null,_majorRaidLocal=null,ws=null;
{hit}
_hitInteriorNpc(target,0,1,13,'rifle',false,true);
const playerDelay=callbacks[0].ms;
const playerBefore={{hp:target.hp,impacts,damageCalls,playerDelay}};
clock+=callbacks[0].ms;callbacks.shift().fn();
const playerAfter={{hp:target.hp,impacts,damageCalls}};
const hqTarget={{id:'hq-boss',r:5,c:10,hp:60,dead:false,npcEmpireBoss:true}},hq={{type:'npc_hq',npcEmpireAssault:{{}},npcs:[hqTarget]}};
_buildingInt=hq;_hitInteriorNpc(hqTarget,0,1,14,'rifle',false,true);
const hqBefore={{hp:hqTarget.hp,impacts,damageCalls}};
clock+=callbacks[0].ms;callbacks.shift().fn();
const hqAfter={{hp:hqTarget.hp,impacts,damageCalls}};
function _interiorGuardWeaponAi(){{return {{hit:1,damage:9}};}} function _npcMuzzleWorldPoint(r,c){{return {{r,c}};}}
function spawnMuzzle(){{}} function spawnBullet(){{}} function _majorInteriorLineClear(){{return true;}}
function _hurtLocal(){{hurtCalls++;}}
Math.random=()=>0;
const shooter={{id:'atk',r:0,c:0,weapon:'pistol',raidHit:1,raidDamage:9,dead:false,name:'A'}},state={{shots:0,hits:0,empire:{{gang_name:'G'}}}},moving={{id:'player',r:0,c:5,isRaidPlayer:true,dead:false}};
bi.npcs.push(shooter);_buildingInt=bi;
{raid_fire}
_fireBusinessRaidRound(bi,state,shooter,moving);
const npcBefore={{hits:state.hits,hurtCalls,impacts}};
player.r=0;player.c=6;clock+=callbacks[0].ms;callbacks.shift().fn();
const npcDodged={{hits:state.hits,hurtCalls,impacts}};
player.c=5;moving.c=5;_fireBusinessRaidRound(bi,state,shooter,moving);clock+=callbacks[0].ms;callbacks.shift().fn();
console.log(JSON.stringify({{playerBefore,playerAfter,hqBefore,hqAfter,npcBefore,npcDodged,npcArrival:{{hits:state.hits,hurtCalls,impacts}}}}));
"""
    result = subprocess.run(
        ["node", "-e", script], cwd=ROOT, check=False,
        capture_output=True, text=True, encoding="utf-8",
    )
    assert result.returncode == 0, f"node runtime failed:\n{result.stderr}\n{result.stdout}"
    data = json.loads(result.stdout)
    assert data["playerBefore"]["hp"] == 50
    assert data["playerBefore"]["impacts"] == 0
    assert data["playerBefore"]["damageCalls"] == 0
    assert data["playerAfter"] == {"hp": 37, "impacts": 1, "damageCalls": 1}
    assert data["hqBefore"] == {"hp": 60, "impacts": 1, "damageCalls": 1}
    assert data["hqAfter"] == {"hp": 46, "impacts": 2, "damageCalls": 2}
    assert data["npcBefore"] == {"hits": 0, "hurtCalls": 0, "impacts": 2}
    assert data["npcDodged"] == {"hits": 0, "hurtCalls": 0, "impacts": 2}
    assert data["npcArrival"] == {"hits": 1, "hurtCalls": 1, "impacts": 3}


if __name__ == "__main__":
    run()
    print("interior projectile arrival: OK")
