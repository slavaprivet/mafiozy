// Presentation only: the existing world remains the sole owner of HP/lifecycle.
const finite=value=>typeof value==='number'&&Number.isFinite(value);
const number=value=>finite(value)?value:null;
const copyPoint=value=>value&&[value.x,value.y,value.z].every(finite)?{x:value.x,y:value.y,z:value.z}:null;
const combatVersion=source=>number(source?.combat_state?.combat_version)??number(source?.combat_state?.body?.version)??number(source?.combat_state?.version);
const impactStamp=impact=>number(impact?.at)??number(impact?.stamp);
const custodyPhases=new Set(['awaiting_pickup','downed','surrendering','surrender_wait_transport','cuffing','escort','loading','transport','unloading','handoff','prison_escort','booking']);
const emptySnapshot=()=>({available:false,hp:null,max:null,dead:false,deathConfirmed:false,deathSource:null,custodyOwned:false,downed:false,stunned:false,inputsBlocked:false,combatVersion:null,sourceDead:false});

export function readWorldWalkHealth(source,previous=emptySnapshot()){
 if(!source||typeof source!=='object')return {...previous,available:false};
 const body=source.combat_state?.body,topHp=number(source.hp),bodyHp=number(body?.current),hp=topHp??bodyHp;
 if(hp===null)return {...previous,available:false};
 const maximum=number(body?.max),max=maximum!==null&&maximum>0?maximum:previous.max;
 const stun=source.meleeStunned,stunned=stun===true||!!(stun&&typeof stun==='object'&&(number(stun.remaining)===null||stun.remaining>0));
 const custodyDown=['downed','awaiting_pickup'].includes(source.arrestPhase)||source.arrest?.down===true;
 const custodyOwned=typeof source.healthCustody==='boolean'?source.healthCustody:custodyPhases.has(source.arrestPhase)||custodyDown;
 // myHp includes local emergency restore/preview changes. A stale body snapshot
 // cannot override a newer positive top-level HP merely by retaining dead:true.
 const bodyAgrees=bodyHp===null||topHp===null||Math.abs(bodyHp-topHp)<1e-6;
 const explicitDeath=typeof source.healthDead==='boolean'?source.healthDead:null;
 const deathEvidence=explicitDeath!==null?explicitDeath:hp<=0||(body?.dead===true&&bodyAgrees&&!stunned);
 const dead=!custodyOwned&&deathEvidence,deathSource=dead?(explicitDeath!==null?'world-health':hp<=0?'hp-zero':'combat-body'):null;
 const downed=!dead&&(custodyDown||stunned||source.dead===true);
 return {available:true,hp:Math.max(0,hp),max,dead,deathConfirmed:dead,deathSource,custodyOwned,downed,stunned,inputsBlocked:dead||downed||custodyOwned,combatVersion:combatVersion(source),sourceDead:source.dead===true};
}

/**
 * update({actorKey,time,source}) returns source edges and the current safe pose.
 * `time`/now are monotonic milliseconds. actorKey is the actual hero/rig identity.
 * Edges do not repeat when a renderer/appearance is replaced. actorSync carries
 * the current settled state for that replacement instead of replaying a fall.
 */
export function createWorldWalkHealth({bridge=null,now=()=>performance.now()}={}){
 let disposed=false,snapshot=emptySnapshot(),initialized=false,actorKey,actorKnown=false,lastTime=-Infinity,lastVersion=null,lastImpact=-Infinity,deathAt=null,impactAt=null,impactData=null,sequence=0;
 const seenImpact=new Set();
 function update(options={}){
  if(disposed)throw Error('World walk health is disposed');
  const suppliedTime=options.time??now();if(!finite(suppliedTime))throw Error('Health presentation requires finite milliseconds');const time=Math.max(lastTime,suppliedTime);lastTime=time;
  let source,sourceError=null;
  try{source=Object.hasOwn(options,'source')?options.source:bridge?.getPlayerState?.();}catch(error){source=null;sourceError=String(error?.message||error);}
  const incoming=readWorldWalkHealth(source,snapshot),events=[],candidateVersion=incoming.combatVersion;
  const stale=incoming.available&&candidateVersion!==null&&lastVersion!==null&&candidateVersion<lastVersion;
  const replacing=Object.hasOwn(options,'actorKey')&&(!actorKnown||options.actorKey!==actorKey),hadActor=actorKnown;
  if(Object.hasOwn(options,'actorKey')){actorKey=options.actorKey;actorKnown=true}
  let initialSync=false;
  if(incoming.available&&!stale){
   const wasDead=snapshot.dead,first=!initialized;snapshot=incoming;
   if(candidateVersion!==null)lastVersion=candidateVersion;
   if(first){initialized=true;initialSync=true;if(snapshot.dead)deathAt=time-1000;}
   else if(snapshot.dead&&!wasDead){deathAt=time;impactAt=null;impactData=null;events.push({type:'death',id:'world-health:death:'+(++sequence),confirmed:true,fatal:true,dead:true,combatVersion:candidateVersion,hp:snapshot.hp});}
   else if(!snapshot.dead&&wasDead){deathAt=null;impactAt=null;impactData=null;events.push({type:'restore',id:'world-health:restore:'+(++sequence),confirmed:true,reason:snapshot.custodyOwned?'custody-takeover':'source-alive',combatVersion:candidateVersion,hp:snapshot.hp});}
   const raw=source.impact,stamp=impactStamp(raw);
   if(stamp!==null&&stamp>0&&!seenImpact.has(stamp)&&stamp>lastImpact){
    lastImpact=stamp;seenImpact.add(stamp);while(seenImpact.size>256)seenImpact.delete(seenImpact.values().next().value);
    // Initial attachment consumes the current stamp without replaying history.
    if(!first){const age=Math.max(0,number(raw.age)??Math.max(0,time-stamp)),power=number(raw.power);
     const impact={stamp,age,angle:number(raw.angle),power,kind:typeof raw.kind==='string'?raw.kind:null,bodyPart:typeof raw.bodyPart==='string'?raw.bodyPart:null,combatVersion:candidateVersion,fatal:snapshot.dead};
     events.push({type:'impact',id:'world-health:impact:'+stamp,...impact});
     if(!snapshot.dead&&age<480&&power!==null&&power>0){impactAt=time-age;impactData=impact;}
    }
   }
  }
  // Missing/older snapshots preserve the last accepted life/input state.
  if(replacing&&snapshot.dead)deathAt=Math.min(deathAt??time,time-1000);
  const safeSnapshot={...snapshot,available:incoming.available&&!stale,stale};
  const age=deathAt===null?0:Math.max(0,(time-deathAt)/1000),impactAge=impactAt===null?Infinity:Math.max(0,(time-impactAt)/1000);
  const reaction=snapshot.dead?{kind:'dead',age,side:1,zone:null}:impactData&&impactAge<.48&&!snapshot.downed&&!snapshot.custodyOwned?{kind:'hit',age:impactAge,side:1,zone:null}:null;
  const actorSync=(replacing||initialSync)&&initialized?{reason:hadActor&&replacing?'actor-replaced':'initial-state',dead:snapshot.dead,custodyOwned:snapshot.custodyOwned,downed:snapshot.downed,settled:true,reaction:snapshot.dead?{kind:'dead',age:Math.max(1,age),side:1,zone:null}:null}:null;
  return {snapshot:safeSnapshot,events,actorSync,reaction,inputsBlocked:snapshot.inputsBlocked,sourceError};
 }
 return {update,get snapshot(){return {...snapshot}},get inputsBlocked(){return snapshot.inputsBlocked},dispose(){if(disposed)return;disposed=true;seenImpact.clear();impactData=null;actorKey=null;}};
}

/** Build a surface receipt only when the host has independently resolved contact.
 * Death may omit contact; an impact stamp/angle/bodyPart is NOT a world point.
 */
export function worldWalkHealthSurfaceReceipt(event,contact=null){
 if(event?.type==='death')return {id:event.id,confirmed:true,fatal:true,dead:true,kind:'world-health'};
 if(event?.type!=='impact'||contact?.confirmed!==true)return null;
 const point=copyPoint(contact.point);if(!point)return null;
 const normal=copyPoint(contact.normal),receipt={id:event.id,confirmed:true,kind:event.kind||'generic',fatal:event.fatal===true,point};
 if(normal)receipt.normal=normal;
 // A host contact must explicitly identify the zone; bodyPart telemetry alone
 // cannot certify a wound, bruise side, projectile normal or anatomical socket.
 if(typeof contact.zone==='string')receipt.zone=contact.zone;
 if(contact.side===-1||contact.side===1)receipt.side=contact.side;
 if(contact.projectile===true)receipt.projectile=true;
 return receipt;
}

/** Synchronize a replacement surface to settled death using its own valid
 * snapshot (wet/wound resources stay rig-owned). Never synthesize a hit point.
 */
export function synchronizeWorldWalkHealthSurface(surface,actorSync,{time}={}){
 if(!surface||!actorSync)return false;
 if(!actorSync.dead){if(surface.state?.kind==='dead')surface.reset();return true;}
 if(typeof surface.snapshot!=='function'||typeof surface.restore!=='function')return false;
 const saved=surface.snapshot(),reaction={kind:'dead',age:Math.max(1,actorSync.reaction?.age||0),side:1,zone:null};
 surface.restore({...saved,reaction},{...(finite(time)?{time}:{}),elapsedSeconds:0});return true;
}
