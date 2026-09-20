import {npcVisibleWeapon} from './npc_civilian_weapon_policy.mjs';
import {sourceLookAppearance} from './npc_role_catalogue.mjs';
import {bossArtDirectionForId} from './npc_boss_art_direction.mjs';
import {createNpcActor,loadNpcSources} from './npc_actor.mjs';
import {describeNpcAppearance,applyNpcAppearance} from './npc_appearance.mjs';
import {createWeaponModel,ARSENAL} from './hero_arsenal.mjs';
import {createNpcWeaponBatch} from './npc_weapon_batches.mjs';
import {ARTIST14_MELEE_DURATIONS} from './hero_artist14_melee.mjs';
import {normalizeNpcLifecycle} from './npc_source_lifecycle.mjs';
import {createNpcVisualShotLatch} from './npc_visual_shot.mjs';

const weaponIds=new Set(ARSENAL.map(x=>x.id));
const aliases={pistol:'tt_pistol',pistol_heavy:'deagle',revolver:'revolver',rifle:'ak74',smg:'uzi',shotgun:'shotgun',sniper:'sniper',bazooka:'rpg',golden_tommy:'tommy_gun',golden_ak:'ak74',golden_pistol:'golden_colt',pistol_gold:'golden_colt',melee:'none',fists:'none',unarmed:'none'};
export function npcWeaponId(value){return weaponIds.has(value)?value:aliases[value]||'none';}
export function npcAppearanceFromWorld(src){
 const look=src.look||{},role=src.police?'police':src.empireBoss?'boss':src.role||src.visualRole||'civilian',overrides={...sourceLookAppearance(look),role,prisonGear:src.prisonGear,shield:!!src.shield,accent:src.bossAccent||look.accent};
 if(look.gender===0||look.gender===1)overrides.sex=look.gender===1?'female':'male';
 if(typeof look.gender==='string')overrides.sex=look.gender==='female'?'female':'male';
 if(Number.isFinite(look.height))overrides.height=look.height;
 if(Number.isFinite(look.body))overrides.build=look.body===0?'slim':look.body>=2?'heavy':'normal';
 if(/^#[\da-f]{6}$/i.test(src.bossColor||look.suit||''))overrides.outfitColor=src.bossColor||look.suit;
 const authored=bossArtDirectionForId(src.id);
 // One authored identity feeds both street actors and menu portraits.
 if(authored){Object.assign(overrides,authored);delete overrides.outfitColor;}
 return describeNpcAppearance(String(src.id),overrides);
}
export function normalizeNpcSnapshot(src,{time,sourceNowMs,worldScale=4.1,originR=0,originC=0,groundHeight=()=>0,waterAt=()=>null}={}){
 if(!src||typeof src.id!=='string'||!src.id||!Number.isFinite(src.r)||!Number.isFinite(src.c))throw Error('NPC snapshot requires existing id and finite r/c');
 const x=(src.c-originC)*worldScale,z=(src.r-originR)*worldScale,y=groundHeight(x,z)+(Number.isFinite(src.elevation)?src.elevation:0),water=waterAt(x,z);
 const posture=src.forcedCrawl||src.prone?'prone':src.crouching||src.cowering?'crouch':'stand';
 const nowMs=Number.isFinite(sourceNowMs)?sourceNowMs:time*1000,downed=src.downed===true||src.lifeState==='downed',stunFlag=src.meleeStunned===true||downed,stunUntil=Number(downed?src.downedUntil:src.meleeStunnedUntil)||0,stunAt=Number(downed?src.downedAt:src.meleeStunnedAt)||Number(src.deadAt)||0;
 const stun={active:stunFlag&&(!stunUntil||nowMs<stunUntil),age:stunAt>0?Math.max(0,(nowMs-stunAt)/1000):undefined,remaining:stunUntil>0?Math.max(0,(stunUntil-nowMs)/1000):undefined,endedAge:stunUntil>0?Math.max(0,(nowMs-stunUntil)/1000):0};
 const shotAge=(Number.isFinite(sourceNowMs)?sourceNowMs/1000:time)-(Number(src._shotAt)||0)/1000,type=src.meleeType==='backfist'?'heavy':src.meleeType||'punch',duration=ARTIST14_MELEE_DURATIONS[type]||.34;
 const weapon=npcWeaponId(npcVisibleWeapon(src)),unarmed=weapon==='none',activeMelee=shotAge>=0&&shotAge<duration&&Number(src._shotAt)>0;
 const hasMelee=activeMelee||!!src.meleeBlock||Number(src.meleeChargeProgress)>0;
 return {position:{x,y,z},yaw:Math.PI/2-(Number(src.ang)||0),moving:!!(src.walking||src.moving),running:!!src.running||!!src.panic,posture:{target:posture,value:posture==='prone'?2:posture==='crouch'?1:0,blocked:false},
  action:unarmed&&hasMelee?{type:activeMelee?(ARTIST14_MELEE_DURATIONS[type]?type:'punch'):'none',progress:Math.max(0,Math.min(1,shotAge/duration)),side:src.meleeKickSide<0?-1:1,blocking:!!src.meleeBlock,charge:Number(src.meleeChargeProgress)||0}:null,
  aim:{aimYaw:Math.PI/2-(Number(src.ang)||0),aimPitch:Number(src.aimPitch)||0,recoil:shotAge>=0&&shotAge<.16?1-shotAge/.16:0},
  reloadProgress:Number(src.reloadProgress)||0,waterLevel:water?.level,inWater:!!water&&water.depth!==0,chestWorldY:y+1.13,time,
  stun,lifecycle:normalizeNpcLifecycle(src,{time,sourceNowMs:nowMs}),life:{...src},sourceNowMs:nowMs,visible:!src.carried&&!src.evacuated};
}

// Snapshot displacement is metres; src.speed is a source tiles/second setting.
export function measureNpcMotion(previous,position,time,{reentry=false,teleport=false}={}){
 const sample={position:{...position},time},dt=previous?time-previous.time:0;
 const distance=previous?Math.hypot(position.x-previous.position.x,position.z-previous.position.z):0;
 // A slow render/GLB-creation frame is still a valid source observation.
 // Reentry and discontinuous positions are rejected separately; elapsed
 // time itself must not turn a visibly moving actor into an idle pose.
 const valid=!reentry&&!teleport&&dt>=.025&&Number.isFinite(dt)&&distance<=8;
 const speed=valid?distance/dt:0;
 return {sample,speed:Number.isFinite(speed)?speed:0,valid:!!valid,dt,distance};
}

// Consumes the existing world snapshot. It never spawns gameplay entities,
// changes HP, invents identities, or runs a second NPC AI.
export async function createNpcPopulation({THREE,scene,loader,cloneSkeleton,bridge=null,groundHeight=()=>0,waterAt=()=>null,worldScale=4.1,originR=0,originC=0,maxActors=72,cacheSeconds=8,maxCachedActors=maxActors*2,interpolationSeconds=.1,getFocus=null,renderLOD=true,renderDistance=100,shadowDistance=35,getInspectId=()=>null,creationBudget=Infinity,getVehicle=null,onSnapshot=null,onBeforePose=null,profile=false}={}){
 if(!(renderDistance>0&&Number.isFinite(renderDistance))||!(shadowDistance>=0&&Number.isFinite(shadowDistance)))throw Error('Invalid NPC render distances');
 if(creationBudget!==Infinity&&(!Number.isInteger(creationBudget)||creationBudget<1))throw Error('Invalid NPC creation budget');
 if(!Number.isInteger(maxActors)||maxActors<1||!Number.isInteger(maxCachedActors)||maxCachedActors<maxActors||!(cacheSeconds>=0)||!(interpolationSeconds>=0&&Number.isFinite(interpolationSeconds)))throw Error('Invalid NPC cache/interpolation limits');
 const sources=await loadNpcSources({loader}),actors=new Map(),savedActors=new Map(),weaponTemplates=new Map();let disposed=false,lastSnapshotAt=-Infinity,nextTrimAt=-Infinity,latest=[],lastTime=0,sourceTimeOffsetMs=0,lodCounts={near:0,mid:0,far:0,posed:0,transformOnly:0};
 const cpu={samples:0,creationFrames:0,last:null,totals:{}};let poseProfile=null,lastUpdateAt=null;
 const sourceClock=(renderTime=lastTime)=>{const clock=bridge?.getWorldClock?.(),milliseconds=typeof clock==='number'?clock:clock?.now;return Number.isFinite(milliseconds)?milliseconds:renderTime*1000+sourceTimeOffsetMs;};
 const focusPoint=()=>{const point=getFocus?getFocus():bridge?.getPlayerState?.();if(Number.isFinite(point?.x)&&Number.isFinite(point?.z))return point;if(Number.isFinite(point?.r)&&Number.isFinite(point?.c))return {x:(point.c-originC)*worldScale,z:(point.r-originR)*worldScale};return null;};
 const normalize=(src,time,sourceNowMs=sourceClock())=>normalizeNpcSnapshot(src,{time,sourceNowMs,worldScale,originR,originC,groundHeight,waterAt});
 const template=id=>{
  if(!weaponTemplates.has(id)){
   const authored=createWeaponModel({THREE,id});
   try{weaponTemplates.set(id,createNpcWeaponBatch({THREE,template:authored}).object);}
   finally{const resources=new Set();authored.traverse(node=>{if(node.geometry)resources.add(node.geometry);for(const material of Array.isArray(node.material)?node.material:node.material?[node.material]:[])resources.add(material)});for(const resource of resources)resource.dispose();}
  }
  return weaponTemplates.get(id);
 };
 // Each actor owns this interpolation result. Reusing it avoids two short-lived
 // objects per actor per render frame without sharing state between actors.
 function renderTransform(record,time){const t=record.motion,out=record.renderTransform,duration=t.duration??interpolationSeconds,alpha=duration?Math.max(0,Math.min(1,(time-t.at)/duration)):1,p=out.position;p.x=t.from.x+(t.to.x-t.from.x)*alpha;p.y=t.from.y+(t.to.y-t.from.y)*alpha;p.z=t.from.z+(t.to.z-t.from.z)*alpha;const yawDuration=t.yawDuration??duration,yawAlpha=yawDuration?Math.max(0,Math.min(1,(time-(t.yawAt??t.at))/yawDuration)):1;out.yaw=t.yawFrom+Math.atan2(Math.sin(t.yawTo-t.yawFrom),Math.cos(t.yawTo-t.yawFrom))*yawAlpha;return out;}
 function make(src,sourceNowMs=sourceClock()){
  const saved=savedActors.get(src.id),descriptor=saved?.descriptor||npcAppearanceFromWorld(src),actor=createNpcActor({THREE,scene,source:sources[descriptor.sex],cloneSkeleton,getVehicle,id:src.id,sex:descriptor.sex,height:descriptor.height,build:descriptor.build,appearanceOwnsResources:true,applyAppearance:source=>applyNpcAppearance({THREE,scene:source,descriptor,cloneTextures:true})});
  // Opt-in diagnostics only: separate skeletal animation and surface effects
  // from normalization/other actor work without changing their call sequence.
  if(profile)for(const [owner,key] of [[actor.walker,'poseWalker'],[actor.surface,'poseSurface']]){const original=owner.update;owner.update=function(...args){if(!poseProfile)return original.apply(this,args);const at=performance.now();try{return original.apply(this,args);}finally{poseProfile[key]+=performance.now()-at;}};}
  try{if(saved)actor.restoreSurfaceState(saved.state,{time:lastTime,elapsedSeconds:Math.max(0,lastTime-saved.state.surface.time)});}catch(error){actor.dispose();throw error;}
  savedActors.delete(src.id);const initial=normalize(src,lastTime,sourceNowMs);
  const shotLatch=createNpcVisualShotLatch();shotLatch.observe(src,sourceNowMs,lastTime);if(src._visualShot)initial.aim.recoil=0;
  actor.update(0,initial);
  const shadowNodes=[];actor.object.traverse(node=>{if(node.isMesh)shadowNodes.push({node,cast:node.castShadow,receive:node.receiveShadow})});
  return {shotLatch,shadowNodes,shadowNear:null,gpuVisible:true,gaitSample:{x:initial.position.x,z:initial.position.z},gaitDistance:0,lastGaitDistance:0,motionSample:{position:{...initial.position},time:lastTime},motionSpeed:0,motionValid:false,actor,descriptor,source:src,lastSeen:lastTime,inSnapshot:true,poseElapsed:0,poseInterrupted:false,lastPoseAt:lastTime,visualYOffset:actor.object.position.y-initial.position.y,weaponId:null,deathKey:saved?.deathKey||null,renderTransform:{position:{...initial.position},yaw:initial.yaw},motion:{from:{...initial.position},to:{...initial.position},yawFrom:initial.yaw,yawTo:initial.yaw,at:lastTime}};
 }
 function evict(id,record){
  // Serialization must succeed before releasing the actor; never turn a failed save into healing.
  const state=record.actor.saveSurfaceState();savedActors.set(id,{state,descriptor:record.descriptor,deathKey:record.deathKey});record.actor.dispose();actors.delete(id);
 }
 function trim(time){
  const visible=new Set(latest.map(row=>row.id)),hidden=[...actors].filter(([id])=>!visible.has(id)).sort((a,b)=>a[1].lastSeen-b[1].lastSeen);let due=Infinity;
  for(const [id,record]of hidden){const expiresAt=record.lastSeen+cacheSeconds;if(time>=expiresAt||actors.size>maxCachedActors)evict(id,record);else due=Math.min(due,expiresAt)}
  // Actor membership cannot change between snapshots.  Retain the earliest
  // exact expiry so ordinary render frames do not rebuild and sort this list.
  nextTrimAt=due;
 }
 function configure(record,row,time,sourceNowMs=sourceClock()){
   record.shotLatch.observe(row,sourceNowMs,time);
   record.source=row;record.lastSeen=time;const weapon=npcWeaponId(npcVisibleWeapon(row));if(record.weaponId!==weapon){record.actor.mountWeapon(weapon==='none'?null:template(weapon));record.weaponId=weapon;const previous=new Map(record.shadowNodes.map(item=>[item.node,item]));record.shadowNodes=[];record.actor.object.traverse(node=>{if(node.isMesh)record.shadowNodes.push(previous.get(node)||{node,cast:node.castShadow,receive:node.receiveShadow})});record.shadowNear=null;}
   record.actor.syncSourceLifecycle(normalizeNpcLifecycle(row,{time,sourceNowMs}),time);
   record.deathKey=record.actor.saveSourceDeathKey();
   if(row.hitReceipt?.confirmed===true)record.actor.receive({...row.hitReceipt,targetId:row.id});
 }
 function sync(rows,time=lastTime,sourceNowMs=sourceClock(time)){
  if(disposed)return;if(!Number.isFinite(time))throw Error('Invalid NPC snapshot time');lastTime=time;if(Number.isFinite(sourceNowMs))sourceTimeOffsetMs=sourceNowMs-time*1000;const ids=new Set();latest=[];
  for(const row of rows||[]){if(!row||typeof row.id!=='string'||!row.id||ids.has(row.id)||!Number.isFinite(row.r)||!Number.isFinite(row.c))continue;ids.add(row.id);latest.push(row);if(latest.length>=maxActors)break;}
  for(const row of latest){
   let record=actors.get(row.id);
   if(!record){if(creationBudget!==Infinity)continue;record=make(row,sourceNowMs);actors.set(row.id,record);}else{
    if(!record.inSnapshot){record.shotLatch.reset();const state=record.actor.saveSurfaceState();record.actor.restoreSurfaceState(state,{time,elapsedSeconds:Math.max(0,time-state.surface.time)});record.poseInterrupted=false;}
    const current=renderTransform(record,time),next=normalize(row,time,sourceNowMs),teleport=!record.inSnapshot||Math.hypot(next.position.x-current.position.x,next.position.y-current.position.y,next.position.z-current.position.z)>8;
    if(!record.inSnapshot){record.gaitSample={x:current.position.x,z:current.position.z};record.gaitDistance=0;}
    const snapshotDt=Math.max(0,time-record.motionSample.time),anchor=record.motionStalled?record.motionSample:record.motionMeasureAnchor||record.motionSample,measured=measureNpcMotion(anchor,next.position,time,{reentry:!record.inSnapshot,teleport});
    const changedPosition=measured.distance>.000001,unchangedTarget=Math.hypot(next.position.x-record.motion.to.x,next.position.y-record.motion.to.y,next.position.z-record.motion.to.z)<.000001,changedYaw=Math.abs(Math.atan2(Math.sin(next.yaw-record.motion.yawTo),Math.cos(next.yaw-record.motion.yawTo)))>=.000001;
    if(!changedPosition&&measured.dt>.75)record.motionStalled=true;
    else if(changedPosition||teleport)record.motionStalled=false;
    // A250ms source tick appears in several100ms snapshots. Measure between
    // distinct positions; duplicate packets cannot compress that whole step
    // into100ms or repeatedly restart an unfinished interpolation.
    if(changedPosition||record.motionStalled||!record.inSnapshot||teleport||!(row.walking||row.moving))record.motionMeasureAnchor=measured.sample;
    else record.motionMeasureAnchor=anchor;
    record.motionSample=measured.sample;
    if(changedPosition||!record.inSnapshot||teleport||!(row.walking||row.moving)){record.motionSpeed=measured.speed;record.motionValid=measured.valid;}
    const measuredSourceNow=sourceNowMs,previousSourceNow=record.motionMeasurement?.sourceNowMs;record.motionMeasurement={dt:measured.dt,distance:measured.distance,sourceNowMs:measuredSourceNow,sourceDt:Number.isFinite(previousSourceNow)?(measuredSourceNow-previousSourceNow)/1000:null};
    // `current` is the actor's reusable per-frame interpolation buffer.  A
    // snapshot must own its `from` point: retaining that buffer here would
    // overwrite the source position on the following render frame and bend
    // the interpolation curve.  This allocates only on snapshot cadence,
    // while ordinary frames remain allocation-free.
    // Snapshots arrive at >=100ms, not exactly100ms. Never compress a200ms
    // source displacement into100ms of presentation after a slow frame.
    const remaining=Math.hypot(next.position.x-current.position.x,next.position.z-current.position.z);
    const catchupTime=measured.valid&&measured.speed>.04?remaining/measured.speed:0;
    const duration=interpolationSeconds?Math.max(interpolationSeconds,measured.dt>0?measured.dt:0,catchupTime):0;
    if(!unchangedTarget||teleport||!record.inSnapshot){const previous=record.motion;record.motion={from:teleport?{...next.position}:{...current.position},to:{...next.position},at:time,duration,yawFrom:previous.yawFrom,yawTo:previous.yawTo,yawAt:previous.yawAt??previous.at,yawDuration:previous.yawDuration??previous.duration??interpolationSeconds};}
    if(changedYaw||teleport){record.motion.yawFrom=teleport?next.yaw:current.yaw;record.motion.yawTo=next.yaw;record.motion.yawAt=time;record.motion.yawDuration=teleport?0:interpolationSeconds?Math.max(interpolationSeconds,Math.min(.25,snapshotDt)):0;}
    if(teleport){record.gaitSample={x:next.position.x,z:next.position.z};record.gaitDistance=0;record.actor.object.position.set(next.position.x,next.position.y,next.position.z);record.actor.object.rotation.y=next.yaw;}
   }
   configure(record,row,time,sourceNowMs);
  }
  for(const [id,record]of actors){record.inSnapshot=ids.has(id);const visible=record.inSnapshot&&!record.source.carried&&!record.source.evacuated;record.actor.object.visible=visible;record.actor.surface.particles.visible=visible;}
  trim(time);
 }
 function update(dt,time){
  if(disposed)return;if(!Number.isFinite(dt)||dt<0||!Number.isFinite(time))throw Error('Invalid NPC update clock');lastTime=time;
  // The host caps physics dt, while `time` is the presentation clock. LOD
  // cadence must follow that clock too: otherwise an ordinary slow frame
  // looks like an offscreen absence and serializes/restores every skin.
  // Keep dt as the fallback for the first tick and non-advancing test clocks.
  const poseDelta=lastUpdateAt===null?dt:Math.max(dt,time-lastUpdateAt);lastUpdateAt=time;
  const clock=profile?()=>performance.now():()=>0,start=clock(),timings=profile?{source:0,snapshot:0,creation:0,traffic:0,pose:0,poseRestore:0,poseRestores:0,poseNormalize:0,poseActor:0,poseWalker:0,poseSurface:0,poseActorOther:0,cache:0,total:0}:null;let stage=start,createdBefore=actors.size;
  let sampledSourceNow,sourceNow=()=>sampledSourceNow??=(sourceClock()),synced=false;if(bridge&&time-lastSnapshotAt>=.1){const snapshot=bridge.getDynamicEntities(65);if(profile){timings.source=clock()-stage;stage=clock();}onSnapshot?.(snapshot,{time,dt});sync(snapshot?.npcs||[],time,sourceNow());lastSnapshotAt=time;synced=true;}
  if(profile){timings.snapshot=clock()-stage;stage=clock();}
  if(creationBudget!==Infinity){let created=0;for(const row of latest){if(actors.has(row.id))continue;const record=make(row,sourceNow());configure(record,row,time,sourceNow());actors.set(row.id,record);if(++created>=creationBudget)break;}}
  if(profile){timings.creation=clock()-stage;stage=clock();}
  onBeforePose?.({dt,time});
  if(profile){timings.traffic=clock()-stage;stage=clock();}
  poseProfile=timings;
  const focus=renderLOD?focusPoint():null,inspectId=getInspectId?.();lodCounts={near:0,mid:0,far:0,culled:0,posed:0,transformOnly:0};
  for(const src of latest){
   const record=actors.get(src.id);if(!record)continue;const motion=renderTransform(record,time),distance=focus?Math.hypot(motion.position.x-focus.x,motion.position.z-focus.z):0,tier=src.id===inspectId||src.civilianTripRiding||distance<=15?'near':distance<=35?'mid':'far',interval=tier==='near'?0:tier==='mid'?.05:.1;
   const walked=Math.hypot(motion.position.x-record.gaitSample.x,motion.position.z-record.gaitSample.z);record.gaitSample.x=motion.position.x;record.gaitSample.z=motion.position.z;if(!src.civilianTripRiding&&!src.carried&&!src.evacuated&&walked<=8)record.gaitDistance+=walked;
   lodCounts[tier]++;record.poseElapsed=Math.min(.25,record.poseElapsed+poseDelta);const gpuVisible=!focus||distance<=renderDistance||src.id===inspectId,visible=gpuVisible&&!src.carried&&!src.evacuated;
   // A long continuous frame is not an offscreen absence. Integration dt is
   // bounded independently by the actor; absolute source/presentation clocks
   // stay intact. Only actually hidden poses need persistence catch-up.
   if(!visible)record.poseInterrupted=true;
   record.gpuVisible=gpuVisible;if(!gpuVisible){lodCounts.culled++;record.gaitDistance=0;}
   const shadowNear=!focus||distance<=shadowDistance||src.id===inspectId;if(record.shadowNear!==shadowNear){for(const item of record.shadowNodes){item.node.castShadow=shadowNear&&item.cast;item.node.receiveShadow=shadowNear&&item.receive}record.shadowNear=shadowNear;}
   if(visible&&(interval===0||record.poseElapsed+1e-9>=interval)){
    const stepDt=record.poseElapsed,gap=Math.max(0,time-record.lastPoseAt);
    if(record.poseInterrupted&&gap>stepDt+.001&&gap>.25){const restoreAt=profile?clock():0,saved=record.actor.saveSurfaceState();record.actor.restoreSurfaceState(saved,{time:time-stepDt,elapsedSeconds:Math.max(0,time-stepDt-saved.surface.time)});if(profile){timings.poseRestore+=clock()-restoreAt;timings.poseRestores++;}}
    const normalizeAt=profile?clock():0,normalized=normalize(src,time,sourceNow());
    // Animate the distance actually rendered over this pose interval. Source
    // snapshots can alternate zero/burst velocity at the distant AI cadence;
    // that is not a stop/run transition of the interpolated body.
    const motionElapsed=Math.max(stepDt,time-record.lastPoseAt,.001);
    normalized.motionSpeed=record.gaitDistance/motionElapsed;normalized.gaitDistance=record.gaitDistance;normalized.moving=record.gaitDistance>.00001;
    normalized.running=normalized.moving&&(normalized.running||normalized.motionSpeed>2.3);
    normalized.slowWalking=normalized.moving&&!normalized.running&&normalized.motionSpeed<.9;
    normalized.position=motion.position;normalized.yaw=motion.yaw;normalized.aim.aimYaw=motion.yaw;
    if(src._visualShot){const shotPose=record.shotLatch.sample(time);normalized.aim.recoil=shotPose?.recoil||0;if(shotPose&&Number.isFinite(shotPose.shot.angle))normalized.aim.aimYaw=Math.PI/2-shotPose.shot.angle;}
    if(profile)timings.poseNormalize+=clock()-normalizeAt;
    const actorAt=profile?clock():0;record.actor.update(stepDt,normalized);if(profile)timings.poseActor+=clock()-actorAt;record.lastPresentationSpeed=normalized.motionSpeed;record.lastGaitMode=!normalized.moving?'idle':normalized.running?'run':normalized.slowWalking?'slow':'walk';record.lastGaitDistance=record.gaitDistance;record.gaitDistance=0;record.visualYOffset=record.actor.object.position.y-motion.position.y;record.poseElapsed=0;record.lastPoseAt=time;record.poseInterrupted=false;lodCounts.posed++;
   }else{
    // Absolute base + last buoyancy offset, never add the previous frame's Y again.
    // Renderer/contact helpers refresh matrices; retain the last valid local skin pose.
    const object=record.actor.object,targetY=motion.position.y+record.visualYOffset;
    // Mid/far NPCs retain their last full skin pose between LOD ticks. When
    // their interpolated transform is unchanged, assigning the same Object3D
    // values again cannot affect rendering but needlessly dirties matrices.
    if(object.position.x!==motion.position.x||object.position.y!==targetY||object.position.z!==motion.position.z)object.position.set(motion.position.x,targetY,motion.position.z);
    if(object.rotation.y!==motion.yaw)object.rotation.y=motion.yaw;
    if(object.visible!==visible)object.visible=visible;lodCounts.transformOnly++;
   }
   const particlesVisible=visible&&record.actor.object.visible;if(record.actor.surface.particles.visible!==particlesVisible)record.actor.surface.particles.visible=particlesVisible;
  }
  // sync() already performed this exact cache pass. Direct update() still
  // evicts on the precise first frame at or after an expiry, without sorting
  // hidden actors on every intervening render frame.
  poseProfile=null;
  if(profile){timings.pose=clock()-stage;timings.poseActorOther=Math.max(0,timings.poseActor-timings.poseWalker-timings.poseSurface);stage=clock();}
  if(!synced&&time>=nextTrimAt)trim(time);
  if(profile){timings.cache=clock()-stage;timings.total=clock()-start;if(cpu.samples>=60){cpu.samples=0;cpu.creationFrames=0;cpu.totals={};}cpu.samples++;if(actors.size>createdBefore)cpu.creationFrames++;cpu.last=timings;for(const [key,value]of Object.entries(timings))cpu.totals[key]=(cpu.totals[key]||0)+value;}
 }
 function motionDiagnostics(){
  let moving=0,walking=0,running=0,riding=0,maxMetresPerSecond=0;const samples=[],invalidSamples=[];
  // This feeds a throttled inspection attribute. Keep the exact stable top-5
  // ordering that sort()+slice() produced, without allocating/sorting a full
  // roster of diagnostic records four times a second.
  const recordSample=sample=>{if(samples.length===5&&sample.speed<=samples[4].speed)return;let index=samples.length;while(index>0&&samples[index-1].speed<sample.speed)index--;samples.splice(index,0,sample);if(samples.length>5)samples.pop();};
  for(const row of latest){const record=actors.get(row.id);if(!record?.motionValid){if(record&&invalidSamples.length<5)invalidSamples.push({id:row.id,dt:record.motionMeasurement?.dt??null,distance:record.motionMeasurement?.distance??null,sourceDt:record.motionMeasurement?.sourceDt??null});continue;}const speed=lastTime-record.motionSample.time<=.5?record.motionSpeed:0;
   if(row.civilianTripRiding){riding++;continue;}
   maxMetresPerSecond=Math.max(maxMetresPerSecond,speed);if(speed>.04){moving++;if(row.running||row.panic||speed>2.3)running++;else walking++;}
   const roundedSpeed=Math.round(speed*1000)/1000;if(samples.length<5||roundedSpeed>samples[4].speed)recordSample({id:row.id,speed:roundedSpeed,role:row.role||row.visualRole||(row.police?'police':'civilian'),dt:record.motionMeasurement?.dt??null,distance:record.motionMeasurement?.distance??null,sourceNowMs:record.motionMeasurement?.sourceNowMs??null,sourceDt:record.motionMeasurement?.sourceDt??null,sampleAge:Math.max(0,lastTime-record.motionSample.time)});
  }
  return {moving,walking,running,riding,maxMetresPerSecond:Math.round(maxMetresPerSecond*1000)/1000,samples:samples.map(sample=>{const record=actors.get(sample.id),pose=record.actor.walker.diagnostics();return {...sample,presentationSpeed:record.lastPresentationSpeed,gaitMode:record.lastGaitMode,gaitDistance:record.lastGaitDistance,gait:pose.gait,phase:pose.phase,reaction:record.actor.surface.state.kind}}),invalidSamples};
 }
 // Host visibility/explicit render-only QA may stop update() altogether. Mark
 // that real interruption without inferring it from a long ordinary frame.
 function markPoseInterrupted(){if(disposed)return;for(const record of actors.values())record.poseInterrupted=true;}
 function receive(id,receipt){return actors.get(String(id))?.actor.receive({...receipt,targetId:String(id)})||false;}
 function dispose(){if(disposed)return;disposed=true;for(const {actor}of actors.values())actor.dispose();actors.clear();savedActors.clear();for(const t of weaponTemplates.values())t.traverse(o=>{o.geometry?.dispose();for(const m of Array.isArray(o.material)?o.material:o.material?[o.material]:[])m.dispose();});for(const source of Object.values(sources))source.traverse(o=>{o.geometry?.dispose();for(const m of Array.isArray(o.material)?o.material:o.material?[o.material]:[])m.dispose();});weaponTemplates.clear();latest=[];}
 function getActorObjects(){const objects=[];for(const src of latest)if(actors.has(src.id))objects.push(actors.get(src.id)?.actor.object);return objects;}
 return {sync,update,getActorObjects,receive,dispose,markPoseInterrupted,attach(next){bridge=next;lastSnapshotAt=-Infinity;},getActors:()=>latest.filter(src=>actors.has(src.id)).map(src=>({id:src.id,name:src.name,role:src.role,object:actors.get(src.id)?.actor.object,source:src})),getActor:id=>actors.get(String(id))?.actor,diagnostics:()=>({visible:latest.filter(row=>actors.get(row.id)?.actor.object.visible).length,seen:latest.filter(row=>actors.has(row.id)).length,pending:latest.filter(row=>!actors.has(row.id)).length,requested:latest.length,creationBudget,cached:actors.size,serialized:savedActors.size,source:bridge?'world-runtime':'external-snapshot',maxActors,maxCachedActors,cacheSeconds,renderLOD,renderDistance,shadowDistance,motion:motionDiagnostics(),lod:{...lodCounts},...(profile?{cpu:{samples:cpu.samples,creationFrames:cpu.creationFrames,last:cpu.last,meanMs:Object.fromEntries(Object.entries(cpu.totals).map(([key,value])=>[key,Math.round(value/Math.max(1,cpu.samples)*100)/100]))}}:{})})};
}
