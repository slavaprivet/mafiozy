// Actual GLBs, authored limb pose, swept skinned contact and source damage bridge.
// No browser/GPU and no optimistic damage stub at the bridge boundary.
import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';import {performance} from 'node:perf_hooks';import {registerHooks} from 'node:module';import {pathToFileURL} from 'node:url';
import {clone} from './assets/maps/city_rebuild_v1/test_npc_death_offline_setup.mjs';import {createHeroWalker} from './assets/maps/city_rebuild_v1/hero_walk.mjs';import {NPC_ASSETS} from './assets/maps/city_rebuild_v1/npc_actor.mjs';import {createWorldWalkMeleeHost} from './assets/maps/city_rebuild_v1/world_walk_melee_host.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const THREE=await import(pathToFileURL(vendor+'build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const source=fs.readFileSync('world.html','utf8'),block=source.slice(source.indexOf('const PUNCH_CD_MS'),source.indexOf('let _policeBatonAnim')),punch=source.slice(source.indexOf('function punch(force,'),source.indexOf('// ── Бандит/враждебный NPC')),methods=source.slice(source.indexOf('  setWalkMeleeCharge(active)'),source.indexOf('  getWalkWeaponOptions(){')),confirm=source.slice(source.indexOf('function _walkConfirmDamage('),source.indexOf('function _walkConfirmServerHit('));
const program=new vm.Script(block+'\n'+punch+'\n'+confirm+'\nglobalThis.bridge={'+methods+'};');
function bridgeFixture(type,z,blocked=false){
 let now=10000,hits=0;const npc={r:z/4.1,c:0,hp:100},events=[];
 const c={performance:{now:()=>now},Math:Object.create(Math),document:{documentElement:{dataset:{}}},window:{dispatchEvent:e=>events.push(e)},CustomEvent:class{constructor(type,data){this.type=type;Object.assign(this,data)}},_UP:new URLSearchParams(),_LOCAL_PREVIEW:false,myMode:'pvp',myDead:false,_meleeStunnedIn:0,_murderPoliceArrest:null,_onlinePoliceArrest:null,myDrivingCarId:null,myJetSkiId:null,_playerSwimmingDeep:false,_inBus:false,chatOpen:false,_gameMenuOpen:false,armed:false,player:{r:0,c:0,ang:Math.PI/2},lockedTargets:new Set(),ws:{readyState:1,send(){}},_walkRendererActive:()=>true,_effectivePlayerStance:()=> 'stand',_isArmed:()=>c.armed,_findLaserTarget:()=>assert.fail('2D targeting forbidden'),getActiveTarget:()=>assert.fail('2D targeting forbidden'),_findNearestMeleeTarget:()=>assert.fail('2D targeting forbidden'),_meleeTargetIsProne:()=>false,_meleeTargetNpcRef:t=>t?._ref||null,_npcConsiderMeleeBlock:()=>{},_meleeLineClear:()=>true,_fireBtn:{classList:{add(){},remove(){}}},addKick(){},_renewAllLocks(){},setTimeout:()=>{},NPCS:[npc],cityCops:[],_bankInt:null,beachgoers:new Map(),_busRiders:[],_busWaiters:[],_parkingNpcs:[],_walkShotNativeRef:id=>id==='npc1'?npc:null,_threeNpcActionRefs:new Map([['npc1',{view:npc}]]),_walkShotContext:null,_walkPendingShots:new Map(),hitNpc:(ref,y,x,weapon,dmg)=>{hits++;ref.hp-=dmg;c._walkConfirmDamage(ref,dmg)},spawnFloatText(){},triggerHitStop(){},addShake(){},hapticHit(){},_alertNearbyCops(){},_npcTriggerFight(){},triggerWitnessChain(){}};
 vm.createContext(c);program.runInContext(c);c.Math.random=()=>type==='kick'?0:.8;
 if(type==='heavy'){c.bridge.setWalkMeleeCharge(true);now+=1210;}
 const admitted=c.bridge.beginWalkMelee({angle:Math.PI/2,heavy:type==='heavy',airborne:type==='dropkick'});assert(admitted.accepted&&admitted.type===type);if(blocked)npc._meleeBlockUntil=now+2000;
 return {c,npc,events,start:{id:admitted.seq,seq:admitted.seq,type,side:admitted.side,sourceStartAt:admitted.startAt,duration:admitted.duration,contactWindow:admitted.contactWindow},now:()=>now,setAge:age=>now=admitted.startAt+age,get hits(){return hits;}};
}
const templates={};for(const sex of ['male','female']){const bytes=fs.readFileSync(new URL(NPC_ASSETS[sex].url));templates[sex]=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;}
const costs={legacy:[],sampled:[]};
function scenario({sex='male',type='punch',fps=5,z=.7,posture='stand',blocked=false,wall=false,legacy=false,armedAtContact=false,lateGap=false,heroY=0}={}){
 const hero=createHeroWalker({THREE,scene:clone(templates[sex]),targetHeight:1.9}),target=createHeroWalker({THREE,scene:clone(templates[sex]),targetHeight:1.9}),world=new THREE.Scene();world.add(hero.object,target.object);hero.object.position.y=heroY;target.object.position.z=z;target.object.rotation.y=Math.PI;target.update(.1,false,false,null,{}, {posture:{target:posture,value:posture==='crouch'?1:posture==='prone'?2:0}});
 if(legacy)hero.sampleMeleeContactPose=undefined;
 const f=bridgeFixture(type,z,blocked),receipts=[],obstacles=[];if(wall){const mesh=new THREE.Mesh(new THREE.BoxGeometry(4,4,.08),new THREE.MeshBasicMaterial());mesh.position.set(0,1,.35);world.add(mesh);obstacles.push(mesh);}
 let vertexCalls=0,vertexCount=0;target.object.traverse(mesh=>{if(mesh.isSkinnedMesh){vertexCount+=mesh.geometry.attributes.position.count;const get=mesh.getVertexPosition;mesh.getVertexPosition=function(...args){vertexCalls++;return get.apply(this,args);};}});
 const host=createWorldWalkMeleeHost({THREE,bridge:{resolveWalkMelee:r=>{const answer=f.c.bridge.resolveWalkMelee(r);receipts.push({age:f.now()-f.start.sourceStartAt,request:r,answer});return answer;}},getHero:()=>hero,getActors:()=>[{id:'npc1',object:target.object}],obstacles:()=>obstacles,now:f.now});
 let samples=0;const originalSample=hero.sampleMeleeContactPose;if(originalSample)hero.sampleMeleeContactPose=(...args)=>{samples++;return originalSample(...args);};
 const ages=lateGap?[0,800]:Array.from({length:Math.ceil((f.start.duration+.25)*fps)+1},(_,i)=>1000*i/fps);
 for(const age of ages){f.setAge(age);hero.update(1/fps,false,false,null,{}, {action:{type,side:f.start.side,progress:Math.min(.999999,age/(f.start.duration*1000))}});if(armedAtContact&&age>=f.start.contactWindow[0])f.c.armed=true;
  const ctx=hero.artistContext(),matrices=Object.values(ctx.bones).map(b=>[b,b.matrix.elements.slice()]),pivot=ctx.visualPivot.matrix.elements.slice(),before=hero.diagnostics(),presentation=hero.meleePresentation(),root=hero.object.position.clone(),q=hero.object.quaternion.clone(),sampleBefore=samples,callsBefore=vertexCalls,at=performance.now();
  host.update({start:f.start});costs[legacy?'legacy':'sampled'].push(performance.now()-at);
  assert(samples-sampleBefore<=13,'bounded pose work');assert(vertexCalls-callsBefore<=vertexCount+12,'one posed target vertex batch per frame');
  assert(hero.object.position.equals(root)&&hero.object.quaternion.equals(q),'sampler preserves authoritative root');assert.deepEqual(hero.diagnostics(),before,'sampler never advances animation clocks');assert.equal(hero.meleePresentation(),presentation,'sampler preserves visible action result');
  for(const [bone,matrix]of matrices)assert.deepEqual(bone.matrix.elements,matrix,'sampled pose restored '+bone.name);assert.deepEqual(ctx.visualPivot.matrix.elements,pivot,'pivot restored');
  if(receipts.length)break;
 }
 const result={sex,type,fps,z,posture,blocked,wall,legacy,hit:f.hits>0,damage:100-f.npc.hp,samples,age:receipts[0]?.age,reason:receipts[0]?.answer.reason,events:f.events.map(e=>e.detail)};
 host.dispose();hero.dispose();target.dispose();for(const o of obstacles){o.geometry.dispose();o.material.dispose();}return result;
}
export {scenario,costs};
if(!process.env.MELEE_BENCH){
const results=[];
for(const sex of ['male','female'])for(const type of ['punch','kick','heavy','dropkick'])for(const fps of [5,8,15,60]){const r=scenario({sex,type,fps});assert(r.hit,JSON.stringify(r));assert.equal(r.events.length,1,'one confirmed source receipt');results.push({sex,type,fps,hit:r.hit,age:r.age,samples:r.samples});}
for(const type of ['punch','kick','heavy','dropkick']){const old=scenario({type,legacy:true});assert(!old.hit,'reproduces legacy 5-FPS miss '+type);}
for(const sex of ['male','female'])for(const fps of [5,8,15,60]){
 for(const type of ['punch','kick','heavy','dropkick']){assert(!scenario({sex,type,fps,z:2}).hit,'out of reach');assert(!scenario({sex,type,fps,posture:'prone'}).hit,'prone dodge '+type);}
 assert(scenario({sex,type:'kick',fps,heroY:.4}).hit,'elevated kick contacts standing target');
 assert(!scenario({sex,type:'kick',fps,heroY:.4,posture:'crouch'}).hit,'same elevated kick passes above crouching target');
 const blocked=scenario({sex,type:'dropkick',fps,blocked:true});assert(blocked.hit&&blocked.events[0].blocked);assert.equal(blocked.events[0].knockdown,false,'block prevents dropkick fall');
}
for(const type of ['punch','kick','heavy','dropkick']){assert(!scenario({type,armedAtContact:true}).hit,'arming cancels source admission');assert(!scenario({type,lateGap:true}).hit,'no unbounded stalled-frame catch-up');}
for(const type of ['punch','kick','heavy','dropkick']){const wall=scenario({type,wall:true});assert(!wall.hit,'wall still blocks '+type);}
const stats=xs=>{xs.sort((a,b)=>a-b);return{samples:xs.length,p50:xs[Math.floor(xs.length*.5)],p95:xs[Math.floor(xs.length*.95)],max:xs.at(-1)};};
console.log(JSON.stringify({pass:true,results,hostCpuMs:{legacy:stats(costs.legacy),sampled:stats(costs.sampled)},scope:'actual male/female GLBs, authored poses, source bridge/damage/confirmed receipts; static targets; CPU only, no full-scene FPS'},null,2));
}
