import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import {createWeaponEffects} from './weapon_effects.mjs';
import {createWeaponFireState,stepWeaponFire} from './hero_weapon_fire.mjs';
const T=await import(pathToFileURL((process.env.THREE_VENDOR_ROOT||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/')+'build/three.module.js'));
// Reference keeps the former unconditional update and scan-based diagnostics.
let reference=readFileSync(new URL('./weapon_effects.mjs',import.meta.url),'utf8');
const guard='if(activeEffects===0&&pending.length===0)return;';assert(reference.includes(guard));
reference=reference.replace(guard,'');
for(const [a,b]of [
 ['active:activeEffects','active:[projectilePool,casingPool,flashPool,impactPool,markPool,explosionPool].reduce((n,p)=>n+p.filter(e=>e.active).length,0)'],
 ...['projectilePool','casingPool','markPool','explosionPool'].map(pool=>[`poolCounts.get(${pool}).active`,`${pool}.filter(e=>e.active).length`]),
])reference=reference.replace(a,b);
const {createWeaponEffects:createReference}=await import('data:text/javascript;base64,'+Buffer.from(reference).toString('base64'));
function setup(create){
 const scene=new T.Scene(),events=[];
 const effects=create(T,scene,{worldScale:1,onImpact:p=>events.push([p.weaponId,p.shotId,p.point.toArray(),p.normal.toArray(),p.explosive]),limits:{projectiles:9,casings:3,flashes:2,impacts:3,marks:4,explosions:2,pendingCasings:3}});
 const roots=scene.children.slice(),wall=new T.Mesh(new T.BoxGeometry(4,4,.2),new T.MeshBasicMaterial());wall.position.set(0,1,2);scene.add(wall);scene.updateMatrixWorld(true);
 return{scene,effects,events,roots,wall};
}
function snapshot(runtime){
 const nodes=[];
 for(const root of runtime.roots)root.traverse(n=>nodes.push([n.visible,n.position.toArray(),n.quaternion.toArray(),n.scale.toArray(),n.material?.opacity,n.material?.color?.getHex()]));
 return nodes;
}
const actual=setup(createWeaponEffects),expected=setup(createReference),origin=new T.Vector3(0,1,0),aim=new T.Vector3(0,1,10);
let checked=0;
function compare(){
 assert.deepEqual(actual.effects.stats(),expected.effects.stats());
 assert.equal(actual.effects.stats().active,actual.roots.filter(n=>n.visible).length,'counter agrees with visible pool roots');
 assert.deepEqual(actual.events,expected.events,'same ordered impact callbacks');
 assert.deepEqual(snapshot(actual),snapshot(expected),'same effect geometry transforms, visibility and materials');checked++;
}
function update(dt){actual.effects.update(dt);expected.effects.update(dt);compare()}
function shoot(shot,obstacles=true){for(const r of [actual,expected])r.effects.shoot(shot,origin,aim,obstacles?[r.wall]:[])}
for(let i=0;i<15;i++)update(.016);
const shots=['tt_pistol','shotgun','rpg','m16'].map(id=>stepWeaponFire(createWeaponFireState(id),{triggerPressed:true},0).shots[0]);
for(let frame=0;frame<360;frame++){
 if(frame<80){shoot(shots[frame%4]);if(frame%7===0)shoot(shots[2])}
 if(frame===95){actual.wall.position.x=expected.wall.position.x=.4;actual.scene.updateMatrixWorld(true);expected.scene.updateMatrixWorld(true)}
 update(frame===130?6:frame%3===0?.04:.02);
}
assert.equal(actual.effects.stats().active,0,'all recycled slots expire');
// Pending ejection must wake up even after projectile and flash have expired.
const delayed={...shots[0],casing:{...shots[0].casing,delay:1},projectiles:shots[0].projectiles.map(p=>({...p,range:.2,speed:100}))};
shoot(delayed,false);update(.1);
assert.equal(actual.effects.stats().active,0);assert.equal(actual.effects.stats().pendingCasings,1);
const before=actual.effects.stats().totalCases;
for(let i=0;i<12;i++)update(.1);
assert.equal(actual.effects.stats().totalCases,before+1);
for(let i=0;i<50;i++)update(.1);
shoot(shots[2]);update(.1);actual.effects.dispose();expected.effects.dispose();compare();
assert.equal(actual.effects.stats().active,0);assert.equal(actual.effects.shoot(shots[0],null,null),false);
console.log(`PASS ${checked} effect frames match unconditional updates and scan-based counters, including recycling, pending ejection and dispose`);
