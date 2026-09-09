import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createVehicleDamage} from './vehicle_damage.mjs';
const T=await import(pathToFileURL('D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js'));
const object=new T.Group(),panel=new T.Mesh(new T.BoxGeometry(.12,1,2),new T.MeshStandardMaterial());object.add(panel);const original=panel.geometry,car={object,shell:[panel],doors:new Map(),wheels:[]},damage=createVehicleDamage(T,car,{profile:{maxHp:10000}}),point=new T.Vector3(.06,0,0),normal=new T.Vector3(1,0,0);
function shot(energy,id=energy){return damage.impact({object:panel,point,normal,damage:energy,shotId:id})}
const metrics=[];
for(const energy of [24,72,132]){
 damage.reset();assert(shot(energy));assert.equal(damage.state.hp,10000-energy);const p=panel.geometry.attributes.position;let min=0;for(let i=0;i<p.count;i++)min=Math.min(min,p.getX(i));
 const mark=panel.children.find(n=>n.visible);assert(mark);assert(mark.geometry.attributes.color,'single material dark crater and metal rim');assert(mark.material.vertexColors);metrics.push({energy,min,scale:mark.scale.x});
 assert(mark.position.x<.065,'mark follows dent surface instead of hovering over original panel');
}
assert(metrics[1].min<metrics[0].min&&metrics[2].min<metrics[1].min,'depth grows TT < Deagle < sniper');assert(metrics[1].scale>metrics[0].scale&&metrics[2].scale>metrics[1].scale);
damage.reset();for(let i=0;i<100;i++)shot(4,i);assert(panel.children.length<=32);assert(damage.stats().marks<=32);const mark=panel.children[0];let freed=0;mark.geometry.addEventListener('dispose',()=>freed++);damage.reset();assert.equal(panel.geometry,original);assert.equal(panel.children.length,0);damage.dispose();assert.equal(freed,1);assert(!damage.object.parent);console.log('PASS bullet energy crater size/depth/HP, bounded pool and reset/resources',JSON.stringify(metrics));
