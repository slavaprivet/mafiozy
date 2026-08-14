"""Runtime regression for intergang and gang-to-police projectile arrival."""

from pathlib import Path
import json
import subprocess


ROOT = Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")
SERVER = (ROOT / "mafiozi_bot.py").read_text(encoding="utf-8")


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
    raise AssertionError(f"unterminated function {name}")


def run() -> None:
    functions = "\n".join(extract_function(name) for name in (
        "_worldGangArrivalGate", "_releaseWorldGangArrivalGate",
        "_markGangBotShot", "_findWorldGangBot", "_playWorldNpcWeaponShot",
        "_applyIntergangBallisticArrival", "_applyGangShotCopArrival",
    ))
    assert "} else if(kind==='gang_shot_cop'){" in WORLD
    assert "_playWorldNpcWeaponShot(d,()=>_applyGangShotCopArrival(d))" in WORLD
    assert "speed:requestedSpeed" in functions
    assert "'hp':int(cop['hp'])" in SERVER
    assert "if(!_worldGangArrivalGate('gang',nb.id))ob.hp=nb.hp" in WORLD
    assert "_worldGangArrivalGate('gang',id))merged.push(ob)" in WORLD
    assert "_worldGangArrivalGate('cop',id))next.push(o)" in WORLD
    assert "some(bot=>_worldGangArrivalGate('gang',bot.id))" in WORLD

    script = f"""
let clock=1000,callbacks=[],impacts=0,corpses=0,lastBullet=null;
const performance={{now:()=>clock}},document={{documentElement:{{dataset:{{}}}}}},BULLET_SPEED=20;
const shooter={{id:'s',hp:80,alive:true}},victim={{id:'v',hp:20,alive:true}},cop={{id:'c',hp:12,alive:true}};
const aggroZones={{a:{{bots:[shooter,victim]}}}},worldCops=[cop],cityCops=[],lastBossShotAt=new Map(),_worldGangArrivalGates=new Map();
function weaponMuzzleD(){{return .5;}} function weaponProfile(){{return {{bulletSpeed:19}};}}
function spawnBullet(sr,sc,tr,tc,opts){{lastBullet={{sr,sc,tr,tc,opts}};}}
function spawnMuzzle(){{}} function spawnImpact(){{impacts++;}} function spawnFloatText(){{}}
function spawnCriticalBlood(){{}} function spawnBotCorpse(){{corpses++;}}
function setTimeout(fn,ms){{callbacks.push({{fn,ms}});return callbacks.length;}}
{functions}
const inter={{shooter_bot_id:'s',bot_id:'v',weapon:'rifle',bullet_speed:14,sy:0,sx:0,ty:0,tx:7,hp:0,dmg:20,killed:true,npc_gang_fight:true}};
const delay=_playWorldNpcWeaponShot(inter,()=>_applyIntergangBallisticArrival(inter));
_worldGangArrivalGate('gang','v',delay);
const before={{victimHp:victim.hp,victimAlive:victim.alive,impacts,corpses,speed:lastBullet.opts.speed,shotSeq:shooter._shotSeq,delay,gated:!!_worldGangArrivalGate('gang','v')}};
clock+=callbacks[0].ms;callbacks.shift().fn();
const interArrival={{victimHp:victim.hp,victimAlive:victim.alive,impacts,corpses}};
const police={{bot_id:'s',cop_id:'c',weapon:'pistol',bullet_speed:11,sy:0,sx:0,ty:0,tx:5,hp:0,dmg:12,killed:true,miss:false}};
_playWorldNpcWeaponShot(police,()=>_applyGangShotCopArrival(police));
_worldGangArrivalGate('cop','c',callbacks[0].ms);
const copBefore={{hp:cop.hp,alive:cop.alive,impacts,speed:lastBullet.opts.speed,shotSeq:shooter._shotSeq}};
clock+=callbacks[0].ms;callbacks.shift().fn();
console.log(JSON.stringify({{before,interArrival,copBefore,copAfter:{{hp:cop.hp,alive:cop.alive,impacts}},telemetry:document.documentElement.dataset}}));
"""
    result = subprocess.run(
        ["node", "-e", script], cwd=ROOT, check=True,
        capture_output=True, text=True, encoding="utf-8",
    )
    data = json.loads(result.stdout)
    assert data["before"]["victimHp"] == 20
    assert data["before"]["victimAlive"] is True
    assert data["before"]["impacts"] == 0
    assert data["before"]["corpses"] == 0
    assert data["before"]["speed"] == 14
    assert data["before"]["shotSeq"] == 1
    assert data["before"]["gated"] is True
    assert data["interArrival"] == {
        "victimHp": 0, "victimAlive": False, "impacts": 1, "corpses": 1,
    }
    assert data["copBefore"] == {
        "hp": 12, "alive": True, "impacts": 1, "speed": 11, "shotSeq": 2,
    }
    assert data["copAfter"] == {"hp": 0, "alive": False, "impacts": 2}
    assert "gangShotCopArrival" in data["telemetry"]


if __name__ == "__main__":
    run()
    print("world gang ballistic arrival: OK")
