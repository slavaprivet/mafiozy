"""Thirty deterministic murder-custody cycles with delay/reconnect injection."""

import json
import subprocess
from pathlib import Path


HTML = Path("world.html").read_text(encoding="utf-8")


def _function(name: str) -> str:
    start = HTML.index(f"function {name}(")
    brace = HTML.index("{", start)
    depth = 0
    quote = None
    escaped = False
    line_comment = block_comment = False
    i = brace
    while i < len(HTML):
        ch = HTML[i]
        nxt = HTML[i + 1] if i + 1 < len(HTML) else ""
        if line_comment:
            if ch == "\n":
                line_comment = False
        elif block_comment:
            if ch == "*" and nxt == "/":
                block_comment = False
                i += 1
        elif quote:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == quote:
                quote = None
        elif ch == "/" and nxt == "/":
            line_comment = True
            i += 1
        elif ch == "/" and nxt == "*":
            block_comment = True
            i += 1
        elif ch in "'\"`":
            quote = ch
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return HTML[start:i + 1]
        i += 1
    raise AssertionError(name)


def run() -> None:
    functions = "\n".join(_function(name) for name in (
        "_murderPoliceVehicleOwnsCustody",
        "_enforceMurderPoliceCustodyVehicle",
        "_setMurderPoliceArrestPhase",
        "_startMurderPolicePrisonTransport",
        "_completeMurderPolicePrisonTransport",
    ))
    script = f"""
let simNow=0;Object.defineProperty(globalThis,'performance',{{value:{{now:()=>simNow}}}});
const document={{documentElement:{{dataset:{{}}}}}},player={{r:0,c:0,ang:0,walking:false,vr:0,vc:0}},cam={{x:0,y:0}},window={{}};
const TS=32,ISO_Y=.5,PVP={{max_hp:100}},JAIL_ISLAND_3D_ENABLED=false,JAIL_CENTER_R=76,JAIL_CENTER_C=76;
const POLICE_RESPONSE_SPEED=12.4,_LOCAL_PREVIEW=false,_UP=new URLSearchParams(),cityCops=[];
let _murderPoliceArrest=null,_custodyPoseResetUntil=0,myDead=false,_localDeath=false,myHp=100,myDeathLeft=0,myDeathBy='',
  _localHpHurtAt=0,_selfHpBarUntil=0,_prisonLocalJailUntil=0,myJailIn=0,_prisonReleaseGateOpenedAt=0;
const _deathOv=null,ws=null;
function _murderCrewForVehicle(v){{return cityCops.filter(c=>c.alive&&c._responseVehicleId===v.id)}}
function _murderVehicleCrewCount(){{return 2}}
function _setVehicleRoute(v,_a,_b,r,c){{v.path=[{{r,c}}];v.finalTarget={{y:r,x:c}}}}
function _confiscateBagOnArrest(){{}}
function _syncPrisonServerJailSeconds(s){{return s}}
function _clearPrisonAssault(){{}}
function showEventBanner(){{}}
function _finishMurderPoliceCall(v){{v.finished=true;return true}}
{functions}
const phases=['downed','cuffing','escort','loading','transport','unloading','handoff','prison_escort','booking'];
let blockedEmptyDepartures=0,reconnects=0,routeDelayFrames=0,booked=0,overlaps=0,poseConflicts=0;
for(let run=0;run<30;run++){{
  simNow=run*100000;document.documentElement.dataset={{}};cityCops.length=0;
  const v={{id:'van_'+run,x:40+run*.01,y:30+run*.01,ang:run*.07,state:'police_arrest_scene',speed:0,
    _murderFleet:true,_policePrisonTransport:false,homeR:77,homeC:77,path:[],pathIdx:0,payload:{{murderIncident:{{id:'incident_'+run}}}}}};
  cityCops.push({{id:'lead_'+run,alive:true,_responseVehicleId:v.id,look:{{}},name:'Lead',_crewSlot:0}},
                {{id:'cover_'+run,alive:true,_responseVehicleId:v.id,look:{{}},name:'Cover',_crewSlot:1}});
  _murderPoliceArrest={{vehicleId:v.id,incidentId:'incident_'+run,copId:'lead_'+run,phase:'downed',phaseAt:simNow,
    jailSeconds:60+run,serverRequested:false,playerBoarded:false,playerAttachedVehicleId:''}};
  player.r=30;player.c=40;myDead=true;_localDeath=true;myHp=0;

  // Downed is the only phase allowed to own the death/prone rig.
  for(const phase of phases.slice(0,4)){{
    _setMurderPoliceArrestPhase(_murderPoliceArrest,phase,++simNow);
    const dead=['awaiting_pickup','downed'].includes(phase),cuffed=['cuffing','escort','loading'].includes(phase);
    if(dead&&cuffed)poseConflicts++;
    if((run+phases.indexOf(phase))%7===0){{
      _murderPoliceArrest=JSON.parse(JSON.stringify(_murderPoliceArrest));reconnects++;
      if(_murderPoliceArrest.vehicleId!==v.id)throw new Error('reconnect lost custody owner');
    }}
  }}

  // Delayed routing/service timeout tries to send the car home before loading.
  v.state='returning';v.path=[{{r:99,c:99}}];
  for(let delay=0;delay<(run%6)+1;delay++){{simNow+=167;routeDelayFrames++;if(!_enforceMurderPoliceCustodyVehicle(v,simNow))blockedEmptyDepartures++;}}
  if(v.state!=='police_arrest_scene'||_murderPoliceArrest.playerBoarded)throw new Error('unboarded car departed');

  if(!_startMurderPolicePrisonTransport(v,_murderPoliceArrest,++simNow))throw new Error('loading failed');
  if(v.state!=='returning'||!_murderPoliceArrest.playerBoarded||_murderPoliceArrest.playerAttachedVehicleId!==v.id)
    throw new Error('boarding was not atomic');
  for(let frame=0;frame<20+(run%13);frame++){{
    simNow+=100;v.y+=.08;v.x+=.04;_enforceMurderPoliceCustodyVehicle(v,simNow);
    if(player.r!==v.y||player.c!==v.x||player.walking)throw new Error('player detached in transit');
    if(run%10===0&&frame===8){{_murderPoliceArrest=JSON.parse(JSON.stringify(_murderPoliceArrest));reconnects++;}}
  }}

  for(const phase of ['unloading','handoff','prison_escort','booking']){{
    _setMurderPoliceArrestPhase(_murderPoliceArrest,phase,++simNow);
    const dead=['awaiting_pickup','downed'].includes(phase),cuffed=true;if(dead&&cuffed)poseConflicts++;
    // Fixed handoff corridor in this non-3D harness is clear of the test solid.
    player.r=76.5;player.c=76.5;if(player.r>=50&&player.r<=55&&player.c>=50&&player.c<=55)overlaps++;
  }}
  if(!_completeMurderPolicePrisonTransport(v,++simNow,'stress30'))throw new Error('booking failed');
  if(_murderPoliceArrest!==null||myDead||_localDeath||myJailIn<=0||player.r!==77||player.c!==77||
     document.documentElement.dataset.policeArrestPhase!=='jailed:stress30'||!v.finished)
    throw new Error('jail completion invariant failed');
  booked++;
}}
const result={{runs:30,booked,blockedEmptyDepartures,reconnects,routeDelayFrames,overlaps,poseConflicts}};
if(booked!==30||blockedEmptyDepartures!==30||overlaps||poseConflicts)throw new Error(JSON.stringify(result));
console.log(JSON.stringify(result));
"""
    proc = subprocess.run(["node", "-"], input=script, text=True, encoding="utf-8", capture_output=True)
    assert proc.returncode == 0, proc.stderr
    result = json.loads(proc.stdout)
    assert result["runs"] == result["booked"] == 30

    # Reconnect snapshots reserve jail time but must not teleport while the
    # physical client custody state machine still owns the player.
    snapshot = HTML[HTML.index("if (typeof d.me.jail_in === 'number'"):]
    snapshot = snapshot[:snapshot.index("if (typeof d.me.terr_cd")]
    assert "if(!_murderPoliceArrest)" in snapshot
    assert "if(_murderPoliceArrest&&myJailIn>0)" in snapshot
    print("POLICE_MURDER_CUSTODY_STRESS_OK:", json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    run()
