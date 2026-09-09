import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createWeaponEffects,classifyImpactSurface} from './weapon_effects.mjs';
const vendor=process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const THREE=await import(pathToFileURL(`${vendor}/build/three.module.js`));
const scene=new THREE.Scene(),hits=[],floor=2;
const fx=createWeaponEffects(THREE,scene,{worldScale:1,groundHeight:()=>floor,onImpact:hit=>hits.push(hit),limits:{projectiles:8,casings:3,flashes:2,impacts:3,marks:5,explosions:1,pendingCasings:3}});
const origin=new THREE.Vector3(0,3,0),target=new THREE.Vector3(0,3,10);
const shot=(id='tt_pistol',kind='round')=>({weaponId:id,shotId:`${id}:test`,damage:24,casing:{delay:0,velocity:{right:1.65,up:2.2,forward:-.4}},projectiles:[{visualId:id,speed:25,range:10,visual:{kind,caliber:.007,length:.07,trail:.09,color:'#c7aa70'}}]});
const resources=()=>{const geometry=new Set(),materials=new Set();let nodes=0;scene.traverse(node=>{nodes++;if(node.geometry)geometry.add(node.geometry);for(const material of Array.isArray(node.material)?node.material:[node.material])if(material)materials.add(material)});return {nodes,geometry,materials}};
fx.shoot(shot(),{origin,ejectionOrigin:new THREE.Vector3(.2,3,0)},target,[]);fx.update(.02);
let casing=fx.debugCasings()[0];assert(casing.velocity.x>1.5,'+Z aim ejects through the authored +X/right port, never left through the receiver');assert.equal(casing.kind,'pistol-brass');assert(casing.spin.length()>10);
const spent=scene.getObjectByName('spent-casing');assert(spent.isGroup);assert(spent.getObjectByName('casing-hollow-body').geometry.parameters.openEnded);assert(spent.getObjectByName('casing-spent-primer'));assert(spent.getObjectByName('casing-extractor-rim'));
for(let i=0;i<100;i++)fx.update(.02);
casing=fx.debugCasings()[0];assert(casing.settled&&casing.bounces>=1,'casing tumbles, bounces and settles instead of spinning forever');assert.equal(casing.spin.length(),0);assert.equal(casing.velocity.length(),0);assert(casing.position.y>floor&&casing.position.y<floor+.04,'case respects the sampled raised floor');
fx.shoot(shot('shotgun','pellet'),origin,target,[]);fx.update(.02);assert(fx.debugCasings().some(x=>x.kind==='shotgun-shell'));
fx.shoot(shot('m16','rifle'),origin,target,[]);fx.update(.02);assert(fx.debugCasings().some(x=>x.kind==='rifle-brass'));
const flash=scene.getObjectByName('muzzle-flash');assert.equal(flash.children.filter(x=>x.name==='muzzle-pressure-petal').length,3);

const wall=new THREE.Mesh(new THREE.BoxGeometry(2,2,.2),new THREE.MeshStandardMaterial({metalness:.9}));wall.position.set(0,3,4);scene.add(wall);scene.updateMatrixWorld(true);
for(const surface of ['glass','metal','wood','masonry','soft']){
  wall.userData.impactSurface=surface;assert.equal(classifyImpactSurface(wall),surface,'authored material tag overrides a shared metallic material');
  const before=hits.length;fx.shoot(shot(),origin,target,[wall]);
  for(let i=0;i<20&&hits.length===before;i++)fx.update(.02);
  assert.equal(hits.length,before+1,'exactly one confirmed swept cosmetic hit callback per projectile');assert.equal(hits.at(-1).damage,24);assert.equal(hits.at(-1).shotId,'tt_pistol:test');assert.equal(hits.at(-1).object,wall);
  if(surface==='glass'){const mark=fx.debugMarks().find(x=>x.kind==='glass-chip');assert(mark);assert(wall.children.some(x=>x.getObjectByName('impact-glass-radial-cracks')?.visible));}
}
const beforeStress=resources();
for(let i=0;i<1500;i++){fx.shoot(shot(i%2?'m16':'shotgun',i%2?'rifle':'pellet'),origin,target,[]);fx.update(.016);assert(fx.stats().active<=fx.stats().poolCapacity);assert(fx.stats().activeCasings<=3);assert(fx.stats().pendingCasings<=3)}
const afterStress=resources();assert.equal(afterStress.nodes,beforeStress.nodes);assert.deepEqual(afterStress.geometry,beforeStress.geometry,'sustained fire allocates no additional geometries');assert.deepEqual(afterStress.materials,beforeStress.materials,'sustained fire allocates no additional materials');
for(let i=0;i<80;i++)fx.update(.1);assert.equal(fx.stats().active,0,'all transient effects expire');assert.equal(fx.stats().pendingCasings,0);
const counts=new Map();for(const resource of [...afterStress.geometry,...afterStress.materials])resource.addEventListener('dispose',()=>counts.set(resource,(counts.get(resource)||0)+1));
fx.dispose();fx.dispose();assert.equal(scene.children.length,1,'effect teardown preserves the host wall');assert.equal(scene.children[0],wall);assert([...counts.values()].every(n=>n===1),'shared geometry/material is disposed only once');assert.equal(fx.stats().active,0);
console.log(JSON.stringify({passed:true,stressShots:1500,checks:['right_port_ejection','detailed_hollow_cases','three_casing_families','bounce_and_settle','sampled_floor','pressure_petal_flash','authored_surface_precedence','glass_radial_cracks','same_authoritative_hit_payload','bounded_pool_and_gpu_resources','expiry','dispose_once']}));
