import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createWorldWalkCombat} from './world_walk_combat.mjs';
import {createWeaponFireState} from './hero_weapon_fire.mjs';
const THREE=await import(pathToFileURL('D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js'));
let accept=false,calls=0,reloads=0,source={magazine:4,reserve:19,reloading:false},lastContact;
const bridge={getPlayerState:()=>source,reloadWalkWeapon(){reloads++;source={...source,reloading:true,reloadProgress:.5};},fireWalkShot(request){calls++;lastContact=request.resolveContact({angle:0,range:8,weapon:'pistol'});if(accept)source={...source,magazine:source.magazine-1};return {accepted:accept,shotId:'source:123',state:source};}};
const combat=createWorldWalkCombat({THREE,bridge,getActors:()=>[],obstacles:()=>[]}),geometry={origin:new THREE.Vector3(),forward:new THREE.Vector3(1,0,0)};
let state=createWeaponFireState('tt_pistol');
let result=combat.step(state,{triggerPressed:true},.016,geometry);
assert.equal(result.shots.length,0);assert.equal(result.state.magazine,4);assert.equal(lastContact,null);
accept=true;result=combat.step(result.state,{triggerPressed:true},.016,geometry);
assert.equal(result.shots.length,1);assert.equal(result.shots[0].shotId,'source:123');assert.equal(result.state.magazine,3);assert.equal(result.state.reserveAmmo,19);
assert.equal(result.shots[0].worldTarget.x,32.8);assert(result.shots[0].projectiles.every(p=>p.yawOffset===0&&p.pitchOffset===0));
const before=calls;result=combat.step(result.state,{triggerHeld:true},.016,geometry);assert.equal(calls,before,'Semi auto never repeats while held');
result=combat.step(result.state,{reload:true},.016,geometry);assert.equal(reloads,1);assert(result.state.reloadRemaining>0);
assert.equal(result.state.magazine,3,'Renderer cannot refill source ammo');
console.log('PASS world combat: source rejection, ammo, one accepted receipt, physical miss, authoritative trajectory, semi-auto and reload');

let contactVectors=0;
class CountedVector3 extends THREE.Vector3{constructor(...args){super(...args);contactVectors++;}}
const measuredThree={...THREE,Vector3:CountedVector3};let measuredAccept=false,measuredSource={magazine:2,reserve:0,reloading:false};
const measured=createWorldWalkCombat({THREE:measuredThree,bridge:{getPlayerState:()=>measuredSource,fireWalkShot(request){request.resolveContact({angle:0,range:8});if(measuredAccept)measuredSource={...measuredSource,magazine:measuredSource.magazine-1};return {accepted:measuredAccept,shotId:'alloc',state:measuredSource};}},getActors:()=>[],obstacles:()=>[]});
let measuredState=createWeaponFireState('tt_pistol'),measuredGeometry={origin:new CountedVector3(),forward:new CountedVector3(1,0,0)};contactVectors=0;
let measuredResult=measured.step(measuredState,{triggerPressed:true},.016,measuredGeometry);assert.equal(contactVectors,0,'a source-rejected contact does not allocate temporary direction/target vectors');
measuredAccept=true;contactVectors=0;measuredResult=measured.step(measuredResult.state,{triggerPressed:true},.016,measuredGeometry);assert.equal(contactVectors,1,'an accepted shot owns exactly its returned target vector');
const preserved=measuredResult.shots[0].worldTarget.clone();contactVectors=0;measured.step(measuredResult.state,{triggerPressed:true},.016,measuredGeometry);assert.deepEqual(measuredResult.shots[0].worldTarget.toArray(),preserved.toArray(),'later source contacts cannot overwrite a returned shot target');
measured.dispose();
console.log('PASS world combat: rejected contacts allocate 0 temporary vectors; accepted target remains independent');

let idleClockReads=0;
const idleCombat=createWorldWalkCombat({THREE,bridge:{getPlayerState:()=>({magazine:2,reserve:0,reloading:false}),fireWalkShot:()=>({accepted:false,state:{magazine:2,reserve:0,reloading:false}})},getActors:()=>[],obstacles:()=>[],now:()=>{idleClockReads++;return 0;}});
for(let i=0;i<120;i++)idleCombat.step(createWeaponFireState('tt_pistol'),{},1/60,geometry);
assert.equal(idleClockReads,0,'without a deferred NPC receipt, idle combat frames do not query a clock or scan the receipt map');
idleCombat.dispose();
console.log('PASS world combat: 120 idle frames skip empty receipt expiry work');

// Exercise the public method called by Walk intimidation, not only firing.
// One skinned plane is enough to prove identity, visibility and wall ordering.
const aimRoot=new THREE.Group(),aimBone=new THREE.Bone();aimRoot.add(aimBone);
const aimGeometry=new THREE.PlaneGeometry(2,2);
aimGeometry.setAttribute('skinIndex',new THREE.Uint16BufferAttribute(new Uint16Array(16),4));
aimGeometry.setAttribute('skinWeight',new THREE.Float32BufferAttribute([1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0],4));
const aimMaterial=new THREE.MeshBasicMaterial({side:THREE.DoubleSide});
const aimSkin=new THREE.SkinnedMesh(aimGeometry,aimMaterial);aimRoot.add(aimSkin);aimSkin.bind(new THREE.Skeleton([aimBone]));aimRoot.updateMatrixWorld(true);
let aimObstacles=[];
const noAuthority=new Proxy({}, {get(){throw Error('Aim must never call source damage/ammo authority');}});
const aimCombat=createWorldWalkCombat({THREE,bridge:noAuthority,getActors:()=>[{id:'aim-resident',object:aimRoot}],obstacles:()=>aimObstacles});
const aimInput={origin:new THREE.Vector3(0,0,3),direction:new THREE.Vector3(0,0,-1),range:5};
const aimed=aimCombat.aim(aimInput);assert.equal(aimed.npcId,'aim-resident');assert.equal(aimed.anchor,undefined);assert.equal(aimed.distance,3);
const aimWall=new THREE.Mesh(new THREE.PlaneGeometry(2,2),aimMaterial);aimWall.position.z=1;aimObstacles=[aimWall];assert.equal(aimCombat.aim(aimInput),null,'wall hides NPC from intimidation');
aimObstacles=[];aimRoot.visible=false;assert.equal(aimCombat.aim(aimInput),null);aimRoot.visible=true;
assert.equal(aimCombat.aim({...aimInput,range:2}),null);assert.equal(aimCombat.aim({...aimInput,direction:new THREE.Vector3()}),null);
aimCombat.dispose();aimGeometry.dispose();aimWall.geometry.dispose();aimMaterial.dispose();
console.log('PASS world combat: public aim identifies visible skin without firing; walls/range/hidden/invalid direction reject');
