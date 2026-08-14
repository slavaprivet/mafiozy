"""Runtime contract for serialized, server-authoritative street-boss hits."""

import json
import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent
WORLD = (ROOT / 'world.html').read_text(encoding='utf-8')


def _function(name: str) -> str:
    marker = f'function {name}('
    start = WORLD.index(marker)
    brace = WORLD.index('{', start)
    depth = 0
    for index in range(brace, len(WORLD)):
        if WORLD[index] == '{':
            depth += 1
        elif WORLD[index] == '}':
            depth -= 1
            if depth == 0:
                return WORLD[start:index + 1]
    raise AssertionError(name)


def _async_function(name: str) -> str:
    start = WORLD.index(f'async function {name}(')
    brace = WORLD.index('{', start)
    depth = 0
    for index in range(brace, len(WORLD)):
        if WORLD[index] == '{':
            depth += 1
        elif WORLD[index] == '}':
            depth -= 1
            if depth == 0:
                return WORLD[start:index + 1]
    raise AssertionError(name)


queue_source = _function('_queueNpcEmpireBossHit')
down_source = _function('_downEmpireCombatant')
hospital_source = _async_function('_hospitalizeEmpireBoss')

assert "mode:'field'" in queue_source
assert "target:'boss'" in queue_source
assert 'session.chain=session.chain.then' in queue_source
assert 'shot_contract' in queue_source and 'next_shot_seq' in queue_source
assert 'weapon:shotWeapon' in queue_source
assert 'hit_r:hitR' in queue_source and 'hit_c:hitC' in queue_source
assert 'shot_seq:shotSeq' in queue_source
assert 'JSON.stringify(hitPayload)' in queue_source
assert '_downEmpireCombatant(target' in queue_source
assert 'body:JSON.stringify({token,hospital_id:hospitalId})' in hospital_source
assert 'leader_id' not in hospital_source
assert 'patient._hiddenByEmpire=true' in hospital_source
assert hospital_source.index('if(!response.ok') < hospital_source.index(
    'patient._hiddenByEmpire=true')

harness = f"""
const calls=[];
let QP={{api:'http://api',uid:'7'}},_LOCAL_PREVIEW=false;
const finishDelay=20;
const document={{documentElement:{{dataset:{{}}}}}},player={{r:2,c:3}};
const _npcEmpireFieldSessions=new Map();
function _empireLeaderIdOf(){{return 'leila'}}
function _empireDoctrineOf(){{return {{id:'plain'}}}}
function _empireRecordIncoming(){{}} function _empireScatterSquad(){{}}
function _markCombatBleeding(){{}} function _npcBodyPassable(){{return false}}
function _empireBossPassable(){{return true}} function spawnFloatText(){{}}
function _clearNpcRoute(){{}} function _empireLessonFor(){{return {{casualties:0}}}}
function _empireSpeak(){{}} let _previewPlayerBusinessRaid=null;
{down_source}
{queue_source}
let resolvePrepare,failHitOnce=false,hitAttempts=0;
globalThis.fetch=(url,opt)=>{{
  calls.push({{url,body:JSON.parse(opt.body)}});
  if(url.endsWith('/prepare'))return new Promise(r=>resolvePrepare=()=>r({{ok:true,json:async()=>({{ok:true,token:'proof',expires_at:9999999999,boss:{{hp:200,max_hp:200}}}})}}));
  if(failHitOnce&&++hitAttempts===1)return Promise.resolve({{ok:false,json:async()=>({{ok:false,error:'weapon shot rejected'}})}});
  return Promise.resolve({{ok:true,json:async()=>({{ok:true,boss_hp:0,boss_max_hp:200,proof_ready:true}})}});
}};
const target={{_empireBoss:true,_specialistId:'leila',r:4,c:5,_empireBattleHp:200,_empireBattleMaxHp:200,dead:false}};
_queueNpcEmpireBossHit(target,35,'pistol',0,1,10);
const before={{hp:target._empireBattleHp,dead:target.dead,hidden:!!target._hiddenByEmpire,calls:calls.length}};
setTimeout(()=>{{resolvePrepare();setTimeout(()=>{{
  const after={{hp:target._empireBattleHp,dead:target.dead,token:target._empireFieldToken,calls:calls.map(x=>x.body)}};
  process.stdout.write(JSON.stringify({{before,after}}));
}},finishDelay)}},0);
"""
proc = subprocess.run(['node', '-'], input=harness, text=True,
                      encoding='utf-8', capture_output=True, cwd=ROOT)
assert proc.returncode == 0, proc.stderr
result = json.loads(proc.stdout)
assert result['before'] == {'hp': 200, 'dead': False, 'hidden': False, 'calls': 0}
assert result['after']['hp'] == 0 and result['after']['dead'] is True
assert result['after']['token'] == 'proof'
assert result['after']['calls'][0] == {'leader_id': 'leila', 'mode': 'field'}
assert result['after']['calls'][1]['token'] == 'proof'

# A v2 prepare removes client damage, and a cadence retry reuses the exact
# sequence/body instead of authorizing a second physical shot.
v2 = harness.replace(
    "ok:true,token:'proof',expires_at:9999999999,boss:{hp:200,max_hp:200}",
    "ok:true,token:'proof',expires_at:9999999999,shot_contract:2,next_shot_seq:1,boss:{hp:200,max_hp:200}")
v2 = v2.replace("failHitOnce=false", "failHitOnce=true")
v2 = v2.replace("const finishDelay=20", "const finishDelay=180")
v2_proc = subprocess.run(['node', '-'], input=v2, text=True,
                         encoding='utf-8', capture_output=True, cwd=ROOT)
assert v2_proc.returncode == 0, v2_proc.stderr
v2_result = json.loads(v2_proc.stdout)
v2_hits = v2_result['after']['calls'][1:]
assert len(v2_hits) == 2 and v2_hits[0] == v2_hits[1]
assert v2_hits[0]['shot_seq'] == 1 and v2_hits[0]['weapon'] == 'pistol'
assert v2_hits[0]['hit_r'] == 4 and v2_hits[0]['hit_c'] == 5
assert 'damage' not in v2_hits[0] and 'leader_id' not in v2_hits[0]

# Prepare failure leaves the actor alive and visible.
failure = harness.replace(
    "new Promise(r=>resolvePrepare=()=>r({ok:true,json:async()=>({ok:true,token:'proof',expires_at:9999999999,boss:{hp:200,max_hp:200}})}))",
    "new Promise(r=>resolvePrepare=()=>r({ok:false,json:async()=>({ok:false,error:'player not in world'})}))")
failed = subprocess.run(['node', '-'], input=failure, text=True,
                        encoding='utf-8', capture_output=True, cwd=ROOT)
assert failed.returncode == 0, failed.stderr
failure_result = json.loads(failed.stdout)
assert failure_result['after']['hp'] == 200
assert failure_result['after']['dead'] is False

print('npc field hospital client: serialized proof HP/down and token-only hospital OK')
