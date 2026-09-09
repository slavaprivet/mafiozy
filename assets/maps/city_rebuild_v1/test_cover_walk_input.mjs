import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {createWeaponFireState,stepWeaponFire,sampleWeaponRecoil,weaponFireProfile} from './hero_weapon_fire.mjs';
const source=fs.readFileSync(new URL('walk_preview.mjs',import.meta.url),'utf8');
const update=source.slice(source.indexOf('function updateCombat(dt,'),source.indexOf('function staticShotRoots()'));
let time=1000,seen=[],cross=[];
const ctx={performance:{now:()=>time},syncWorldWeapon(){},combatAllowed:()=>true,releaseWeapon(){ctx.triggerPressed=ctx.triggerHeld=false;},
 occupiedSeat:null,vehicleWindowFire:{pending:0,result:null},currentWeapon:{id:'tt_pistol'},heroPosture:{value:1},heroCover:{active:true,canFire:false,mode:'blind'},jump:null,
 triggerHeld:true,triggerPressed:true,pendingCoverShotUntil:0,reloadPressed:false,aiming:false,
 fireStates:new Map([['tt_pistol',createWeaponFireState('tt_pistol')]]),fireState:()=>ctx.fireStates.get('tt_pistol'),
 worldWalkCombat:{step(state,input,dt){seen.push({...input});return stepWeaponFire(state,{...input,triggerHeld:false},dt);}},
 THREE:{Vector3:class{},MathUtils:{clamp:(x,a,b)=>Math.max(a,Math.min(b,x))}},camera:{getWorldDirection:()=>({x:0,y:0,z:1}),fov:45},
 weaponModel:null,weaponHud:null,npcBridge:null,renderer:{domElement:{clientHeight:720}},innerHeight:720,weaponInteractionAllowed:()=>true,
 effects:{update(){},stats:()=>({})},weaponCrosshair:{update(state,input){cross.push({...input});}},sampleWeaponRecoil,weaponFireProfile,
 $:()=>({style:{}}),fireDiagnosticsAt:Infinity,walking:true,busy:false,arsenalOpen:()=>false,document:{body:{dataset:{}}}};
vm.createContext(ctx);vm.runInContext(update,ctx);
const frame=()=>{time+=16;return vm.runInContext('updateCombat(.016)',ctx);};
assert.equal(frame().result.shots.length,0);assert.equal(ctx.fireState().magazine,12);assert.equal(seen.at(-1).triggerPressed,false);
assert.equal(ctx.triggerPressed,true,'short click stays queued while the arm is moving');
ctx.triggerHeld=false;frame();assert.equal(ctx.triggerPressed,true,'releasing click does not discard an admitted pending shot');
ctx.heroCover.canFire=true;assert.equal(frame().result.shots.length,1);assert.equal(ctx.fireState().magazine,11);
assert.equal(seen.at(-1).coverFire,'blind');assert.equal(cross.at(-1).coverFire,'blind');assert.equal(ctx.triggerPressed,false);
assert.equal(frame().result.shots.length,0,'semi-auto emits only one buffered round');
ctx.triggerPressed=true;ctx.heroCover.canFire=false;ctx.heroCover.mode='blocked';frame();assert.equal(ctx.triggerPressed,false);assert.equal(ctx.fireState().magazine,11,'wall blocks round admission');
ctx.heroCover.mode='blind';ctx.triggerPressed=true;frame();time+=700;vm.runInContext('updateCombat(.7)',ctx);assert.equal(ctx.triggerPressed,false,'unreachable pose cannot hold a shot forever');
ctx.heroCover.active=false;ctx.heroCover.canFire=true;ctx.triggerPressed=true;ctx.aiming=true;time+=1000;vm.runInContext('updateCombat(1)',ctx);
assert.equal(seen.at(-1).coverFire,null,'ordinary aiming retains normal handling');
console.log('PASS actual walk combat input: buffered cover click, arm clearance, blocked wall consumes no ammo, bounded queue, single source round, real crosshair cone, normal aim');
