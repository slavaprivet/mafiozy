import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import {runInNewContext} from 'node:vm';
import {createMercenaryTargets} from './mercenary_targets.mjs';
const THREE=await import(pathToFileURL((process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor')+'/build/three.module.js'));
const source=readFileSync(new URL('./mercenary_walk.mjs',import.meta.url),'utf8');
const helpers=source.slice(source.indexOf(' function target(id'),source.indexOf(' const charges='));
function setup(host={}){
 const scene=new THREE.Scene(),camera=new THREE.PerspectiveCamera(50,1,.1,100);
 camera.position.set(0,1,8);camera.lookAt(0,1,0);camera.updateMatrixWorld();
 const car=new THREE.Mesh(new THREE.BoxGeometry(2,2,2),new THREE.MeshBasicMaterial());car.position.y=1;scene.add(car);scene.updateMatrixWorld(true);
 const fleet={records:[{id:'one',car:{object:car}}]};let reads=0;
 const targets=createMercenaryTargets({THREE,camera,getRoots:()=>[scene],getFleet:()=>{reads++;return fleet;}}),context={host,targets,pickingProbe:null};
 runInNewContext(helpers,context);
 return {car,fleet,targets,context,get reads(){return reads;},reset(){reads=0;}};
}
test('successful adapter pick refreshes registry once and preserves descriptor shape/metadata',()=>{
 const f=setup();f.car.userData.mercenaryTarget={distance:777,hitPoint:'authored',instanceId:91};
 const expected=f.targets.get('fleet:one');f.reset();const picked=f.context.pick();
 assert.equal(f.reads,1,'one registry snapshot for immediate pick resolution');
 assert.deepEqual(picked,expected,'fresh describe retains authored metadata, rather than pick-only hit fields');
 f.targets.dispose();
});
test('source member then direct source target retain precedence over presentation',()=>{
 const member={id:'member-authority'},owner={id:'source-authority'},calls=[];
 const f=setup({getMember:id=>{calls.push('member:'+id);return member;},getTarget:id=>{calls.push('source:'+id);return owner;}});
 assert.equal(f.context.pick(),member);assert.deepEqual(calls,['member:fleet:one']);assert.equal(f.reads,1);
 f.context.host.getMember=()=>null;assert.equal(f.context.pick(),owner);assert.equal(f.reads,2);f.targets.dispose();
});
test('ordinary get remains fresh after replacement, movement and removal',()=>{
 const f=setup();f.context.pick();f.car.position.x=3;
 assert.equal(f.targets.get('fleet:one').center.x,3,'describe reads current transform');
 const replacement=f.car.clone();replacement.position.x=5;f.fleet.records=[{id:'one',car:{object:replacement}}];
 assert.equal(f.targets.get('fleet:one').object,replacement,'default get rebuilds identity map');
 assert.equal(f.targets.get('fleet:one').center.x,5);f.fleet.records=[];
 assert.equal(f.targets.get('fleet:one'),null,'default get rejects removed registration');f.targets.dispose();
});
test('NPC merge keeps presentation id and exact legacy descriptor fields',()=>{
 const descriptor={id:'npc:7',kind:'npc',sourceId:7,label:'render'},sourceNpc={id:7,label:'source',hp:80};
 const context={pickingProbe:null,host:{getMember:()=>null,getTarget:id=>id===7?sourceNpc:null},targets:{pick:()=>({...descriptor,distance:8,hitPoint:{x:0,y:0,z:0}}),get:()=>descriptor}};
 runInNewContext(helpers,context);const result=context.pick();
 assert.equal(JSON.stringify(result),JSON.stringify({...descriptor,...sourceNpc,id:descriptor.id}));
});
