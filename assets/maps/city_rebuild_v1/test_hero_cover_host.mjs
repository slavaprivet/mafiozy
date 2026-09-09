import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {createHeroWalker} from './hero_walk.mjs';
import {createWeaponModel} from './hero_arsenal.mjs';
import {createHeroCover} from './hero_cover_host.mjs';

const here=path.dirname(fileURLToPath(import.meta.url));
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(path.join(vendor,'build/three.module.js')).href:s,c);}});
const THREE=await import(pathToFileURL(path.join(vendor,'build/three.module.js')));
const {GLTFLoader}=await import(pathToFileURL(path.join(vendor,'addons/loaders/GLTFLoader.js')));
const bytes=fs.readFileSync(path.join(here,'hero_models','player_male.8130dfb1f7eb.glb'));
const source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
const hero=createHeroWalker({THREE,scene:source}),weapon=createWeaponModel(THREE,'tt_pistol');
hero.mountWeapon(weapon);
const document={body:{dataset:{},children:[],append(element){this.children.push(element);}},createElement(){return {style:{},hidden:false,textContent:'',setAttribute(){}};}};
const scene=new THREE.Scene();scene.add(hero.object);
const wall=new THREE.Mesh(new THREE.BoxGeometry(6,3,2),new THREE.MeshBasicMaterial());wall.position.set(3,1.5,1);scene.add(wall);
const car=new THREE.Mesh(new THREE.BoxGeometry(6,1.1,2),new THREE.MeshBasicMaterial());car.position.set(3,.55,1);
const polygon=[{x:0,z:0},{x:6,z:0},{x:6,z:2},{x:0,z:2}];
let body,allow=true,posture={target:'stand',value:0},onEnterCount=0,movement=0;
let physicalObstacles=[wall];
const canOccupy=(p,height)=>p.y===0&&(p.z<=-.25||p.z>=2.25||p.x<=-.25||p.x>=6.25)&&height<=1.9;
const controller=createHeroCover({THREE,document,getHero:()=>hero,getWeapon:()=>weapon,getBodies:()=>[body],canOccupy,allowed:()=>allow,
  requestPosture(target){posture={target,value:target==='crouch'?1:0};},getPosture:()=>posture,
  onMove(delta){movement+=delta.length();},onEnter(){onEnterCount++;},obstacles:()=>physicalObstacles,groundHeight:()=>0});
const direction={x:0,z:1};
let cases=0;
function test(name,fn){fn();cases++;console.log(`PASS ${name}`);}
function reset({low=false,x=3,valid=()=>true}={}){
  controller.leave();hero.reset();hero.object.position.set(x,0,-1);allow=true;posture={target:'stand',value:0};
  body={id:low?'test-car':'test-wall',polygon,minY:0,maxY:low?1.1:3,vehicle:low,valid};
  physicalObstacles=low?[car]:[wall];scene.remove(wall,car);scene.add(...physicalObstacles);scene.updateMatrixWorld(true);
}
function frame({aiming=false,firing=false,dt=1/30}={}){
  controller.update(dt,{direction,aiming,firing});
  hero.update(dt,false,false,weapon,{aimYaw:0,aimPitch:0},{posture});
  controller.pose({aimYaw:0,aimPitch:0});scene.updateMatrixWorld(true);
}
function settle(input={}){for(let i=0;i<18;i++)frame(input);}
const from=(x,z)=>({sourceC:x/4.1,sourceR:z/4.1});

test('actual host attaches and reports hidden state using real GLB pose',()=>{
  reset();const entered=onEnterCount;
  assert.equal(controller.active,false);assert.equal(controller.canFire,true);
  assert.equal(controller.toggle(direction),true);assert.equal(onEnterCount,entered+1);
  assert.equal(controller.active,true);assert.equal(posture.target,'stand');assert.ok(Math.abs(hero.object.position.z+.48)<1e-8);
  settle();const snapshot=JSON.parse(document.body.dataset.heroCover);
  assert.equal(controller.mode,'hidden');assert.equal(controller.canFire,false);assert.equal(snapshot.poseReady,true);
  assert.equal(document.body.children[0].hidden,false);assert.equal(snapshot.id,'test-wall');
});

test('actual host clamps lateral motion at edge and leaving away releases cover',()=>{
  reset();controller.toggle(direction);const before=movement;
  assert.equal(controller.move(new THREE.Vector3(10,0,0)),true);
  assert.ok(Math.abs(hero.object.position.x-5.86)<1e-8);assert.ok(movement>before);
  assert.equal(controller.move(new THREE.Vector3(10,0,0)),false);
  assert.equal(controller.move(new THREE.Vector3(0,0,-.2)),null);
  assert.equal(controller.active,false);assert.equal(controller.canFire,true);assert.equal(document.body.children[0].hidden,true);
});

test('middle tall wall blocks fire while a corner enters aimed mode',()=>{
  reset();controller.toggle(direction);settle({aiming:true});
  assert.equal(controller.mode,'blocked');assert.equal(controller.canFire,false);
  controller.move(new THREE.Vector3(-10,0,0));settle({aiming:true});
  assert.equal(controller.mode,'aimed');assert.ok(controller.offset.x<-.3);
  assert.equal(JSON.parse(document.body.dataset.heroCover).poseReady,true);
  // Always keep authorization consistent with actual grip reach and muzzle rays.
  const snapshot=JSON.parse(document.body.dataset.heroCover);
  if(snapshot.reach===false)assert.equal(controller.canFire,false);
  assert.equal(controller.canFire,true,`corner aimed fire ready: ${JSON.stringify(snapshot)}`);
  settle();assert.equal(controller.mode,'hidden');assert.equal(controller.canFire,false);
});

test('standing blind corner can fire while exposing less body than aimed peek',()=>{
  for(const x of [.14,.18]){
    reset({x});controller.toggle(direction);settle();
    const damage=()=>{const hit=controller.resolveDamage(from(-.6,8));return hit.blocked?0:hit.multiplier;};
    const hidden=damage();
    settle({aiming:true});const aimed=damage();
    assert.equal(controller.canFire,true,`standing corner ${x} aimed: ${document.body.dataset.heroCover}`);
    settle({firing:true});const blind=damage();
    assert.equal(controller.mode,'blind');assert.ok(controller.offset.length()<.001);
    assert.equal(controller.canFire,true,`standing corner ${x} blind: ${document.body.dataset.heroCover}; damage hidden=${hidden}, aimed=${aimed}, blind=${blind}`);
    // Bone rays are discrete: changing hand positions can lower the sampled
    // blind fraction slightly even though the weapon itself is more exposed.
    assert.ok(hidden<aimed&&hidden<=.25,`hidden ${hidden} < aimed ${aimed}`);
    assert.ok(blind<aimed,`blind ${blind} < aimed ${aimed}`);
    assert.ok(aimed>=.55&&aimed<=1&&blind<=.45);
  }
});

test('a low car crouches hidden, aims standing and blind-fires without body offset',()=>{
  reset({low:true});controller.toggle(direction);settle();
  assert.equal(posture.target,'crouch');assert.equal(controller.mode,'hidden');
  settle({aiming:true});assert.equal(posture.target,'stand');assert.equal(controller.mode,'aimed');
  assert.equal(controller.canFire,true,`low aimed fire ready: ${document.body.dataset.heroCover}`);
  settle({firing:true});assert.equal(posture.target,'crouch');assert.equal(controller.mode,'blind');
  assert.equal(controller.canFire,true,`low blind fire ready: ${document.body.dataset.heroCover}`);
  assert.ok(controller.offset.length()<1e-7);
  settle();assert.equal(controller.mode,'hidden');assert.equal(controller.canFire,false);
});

test('moved dynamic cover and changed game eligibility release attachment',()=>{
  let valid=true;reset({valid:()=>valid});controller.toggle(direction);valid=false;frame();assert.equal(controller.active,false);
  reset();controller.toggle(direction);allow=false;frame();assert.equal(controller.active,false);
});

test('damage rays use solid world geometry and do not protect against flanking',()=>{
  reset();controller.toggle(direction);settle();
  assert.deepEqual(controller.resolveDamage(from(3,6)),{blocked:true});
  const flank=controller.resolveDamage(from(-5,-3));
  assert.ok(Math.abs(flank.multiplier-1)<1e-8);
  assert.equal(controller.resolveDamage({sourceR:NaN,sourceC:2}),null);
  controller.leave();assert.equal(controller.resolveDamage(from(3,6)),null);
});

test('invisible and transparent geometry do not create phantom cover protection',()=>{
  reset();controller.toggle(direction);settle();
  wall.visible=false;assert.ok(Math.abs(controller.resolveDamage(from(3,6)).multiplier-1)<1e-8);wall.visible=true;
  wall.material.transparent=true;wall.material.opacity=.2;
  assert.ok(Math.abs(controller.resolveDamage(from(3,6)).multiplier-1)<1e-8);
  wall.material.transparent=false;wall.material.opacity=1;
});

test('boolean validity supported by pure cover also remains valid in host update',()=>{
  reset({valid:true});controller.toggle(direction);assert.doesNotThrow(()=>frame());assert.equal(controller.active,true);
});

controller.leave();
console.log(JSON.stringify({passed:true,cases,checks:['real_GLB_pose','actual_host_controller','wall_and_car_Three_meshes','capsule_slide','corner_modes','moving_cover_validity','real_damage_raycast','flanking','hidden_geometry','ordinary_damage_passthrough']}));
