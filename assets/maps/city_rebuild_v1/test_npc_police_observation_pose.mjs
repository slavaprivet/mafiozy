import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {performance} from 'node:perf_hooks';
import {clone} from './test_npc_death_offline_setup.mjs';
import {createNpcActor,NPC_ASSETS} from './npc_actor.mjs';
import {createNpcPoliceObservationPose} from './npc_police_observation_pose.mjs';
import {createWeaponModel} from './hero_arsenal.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const THREE=await import(pathToFileURL(vendor+'build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const source=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8').replace(/\r\n/g,'\n'),begin=source.indexOf('function _threeNpcPoliceObservation('),end=source.indexOf('\n}',begin)+2;
const scope={Math,Number};vm.runInNewContext(source.slice(begin,end),scope);
const observation={since:1000,until:6500},cop={kind:'patrol',alive:true,_civilianSuspicion:{arrivedAt:1000,until:10000}};
assert.equal(JSON.stringify(scope._threeNpcPoliceObservation(cop,2000)),JSON.stringify(observation));
assert.equal(JSON.stringify(scope._threeNpcPoliceObservation({_actionRef:cop},2000)),JSON.stringify(observation),'snapshot uses actual canonical cop');
for(const extra of [{alive:false},{dead:true},{kind:'murder_response'},{_pursuing:true},{_casePhase:'arrest_cuffing'},{_transportBoarded:true},{walking:true}])assert.equal(scope._threeNpcPoliceObservation({...cop,...extra},2000),null);
assert.equal(scope._threeNpcPoliceObservation({...cop,_civilianSuspicion:{arrivedAt:0,until:10000}},2000),null,'route approach is not inspection');
assert.equal(scope._threeNpcPoliceObservation(cop,7000),null,'source deadline expires even if snapshot stale');
const report={rigs:[],limits:'CPU actual GLB and source observation contract only; no loaded-game FPS or visual LIVE acceptance.'};
for(const sex of ['male','female']){
 const b=fs.readFileSync(new URL(NPC_ASSETS[sex].url)),template=(await new GLTFLoader().parseAsync(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),'')).scene;
 const actor=createNpcActor({THREE,scene:new THREE.Scene(),source:template,cloneSkeleton:clone,id:`observer_${sex}`,sex}),c=actor.walker.artistContext();
 const weapon=createWeaponModel(THREE,'tt_pistol');actor.mountWeapon(weapon);
 const tick=(life={},extra={})=>actor.update(.05,{time:2,position:{x:4,y:0,z:7},yaw:.3,life,...extra});
 const head=()=>c.bones.head.matrix.elements.slice(),changed=(a,b)=>a.some((n,i)=>Math.abs(n-b[i])>1e-6);
 tick();const neutralHead=head(),hands=['socket_hand_l','socket_hand_r'].map(n=>c.worldPosition(n)),root=actor.object.matrixWorld.elements.slice();
 tick({policeObservation:observation});assert(changed(neutralHead,head()),'arrived patrol scans');
 for(let i=0;i<2;i++)assert(c.worldPosition(['socket_hand_l','socket_hand_r'][i]).distanceTo(hands[i])<1e-7,'inspection preserves gun grip');
 assert.deepEqual(actor.object.matrixWorld.elements,root,'no AI position/yaw override');
 for(const [life,extra] of [[{panic:true},{}],[{}, {moving:true}],[{}, {action:{type:'shoot',progress:.4}}],[{}, {vehicle:{seated:1}}],[{}, {stun:{active:true,age:.5}}]]){
  tick(life,extra);const blockedHead=head();tick({...life,policeObservation:observation},extra);assert(!changed(blockedHead,head()),'higher priority action blocks observation');
 }
 // Keep the benchmark focused on the new overlay, with a real rig context.
 let constructions=0;const counted={...THREE};for(const key of ['Vector3','Quaternion','Euler'])counted[key]=new Proxy(THREE[key],{construct(target,args){constructions++;return Reflect.construct(target,args);}});
 const overlay=createNpcPoliceObservationPose({THREE:counted,walker:actor.walker}),timings=[],idle=[],builds=constructions;
 for(let i=0;i<140;i++){
  actor.walker.reset();let start=performance.now();overlay.apply(null,2);const a=performance.now()-start;
  start=performance.now();overlay.apply(observation,2);const b=performance.now()-start;
  if(i>=40){idle.push(a);timings.push(b);}
 }
 const stats=a=>{a.sort((x,y)=>x-y);return {p50Ms:a[50],p95Ms:a[95]};};
 assert.equal(constructions,builds,'no THREE allocations during warmed observation');
 report.rigs.push({sex,idle:stats(idle),active:stats(timings),warmThreeConstructions:constructions-builds,extraMeshes:0,extraMaterials:0});actor.dispose();
 const resources=new Set();weapon.traverse(n=>{if(n.geometry)resources.add(n.geometry);if(n.material)resources.add(n.material);});for(const r of resources)r.dispose();
}
fs.writeFileSync(new URL('../../../outputs/npc_police_observation_20260919.json',import.meta.url),JSON.stringify(report,null,2));
console.log(JSON.stringify(report,null,2));console.log('PASS actual patrol observation: arrival/deadline, identity, head scan, preserved grip/root and action priority');
