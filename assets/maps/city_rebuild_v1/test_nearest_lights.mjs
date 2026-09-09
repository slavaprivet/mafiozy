import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {selectNearestLightFixtures,createStreetLighting,STREET_LAMP_PROFILES} from './street_lighting.mjs';
const T=await import(pathToFileURL((process.env.THREE_VENDOR_ROOT||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/')+'build/three.module.js'));
let seed=127,measurements=0;
const random=()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/4294967296);
const fixtures=Array.from({length:192},()=>({active:true,world:new T.Vector3(random()*500,random()*15,random()*500)}));
const original=(rows,focus,limit)=>rows.filter(row=>row.active).sort((a,b)=>a.world.distanceToSquared(focus)-b.world.distanceToSquared(focus)).slice(0,limit);
const selected=[],distances=[];
for(let i=0;i<2500;i++){
 const focus=new T.Vector3(random()*700-100,random()*20,random()*700-100),limit=1+i%16;
 const row=fixtures[i%fixtures.length];row.active=i%7!==0;
 if(i%3===0)row.world.copy(fixtures[(i+1)%fixtures.length].world); // exact ties
 assert.deepEqual(selectNearestLightFixtures(fixtures,focus,limit,selected,distances),original(fixtures,focus,limit));
 assert.deepEqual(distances,selected.map(row=>row.world.distanceToSquared(focus)));
 measurements++;
}
assert.deepEqual(selectNearestLightFixtures([],new T.Vector3(),8,selected,distances),[]);
assert.deepEqual(distances,[]);

// Verify actual light positions/intensities, including fixed placement,
// day/night changes, removal, movement and reused pool slots.
const scene=new T.Scene(),manager=createStreetLighting({THREE:T,scene,staticPlacement:true,maxLights:8,maxFixtures:192});
const geometry=new T.BoxGeometry(.2,.2,.2),material=new T.MeshBasicMaterial(),apps=[];
function add(x,z){
 const visual=new T.Group(),glow=new T.Mesh(geometry,material);glow.name='Glow_test';glow.position.y=5;visual.position.set(x,0,z);visual.add(glow);scene.add(visual);
 apps.push(manager.prepare(visual,{assetId:'lamp_pine_v1',binding:{sha256:STREET_LAMP_PROFILES.lamp_pine_v1.sha256,lod:0}}));
}
for(let i=0;i<176;i++)add((i%16)*8,Math.floor(i/16)*8);
for(let i=0;i<120;i++){
 if(i===30){apps[3].dispose();add(1,1)}
 if(i===60){apps[10].visual.position.x+=20;manager.invalidatePlacement()}
 const focus=new T.Vector3(i-10,0,35+20*Math.sin(i)),night=(i%4)/3;
 manager.update({focus,night});
 const expected=original(apps.flatMap(app=>app.fixtures),focus,8);
 // At exactly zero intensity the lamp positions cannot change the frame. The
 // manager intentionally skips the nearest-fixture scan until night resumes.
 if(night===0)assert(manager.lights.every(light=>light.intensity===0));
 else expected.forEach((entry,j)=>{
  assert.deepEqual(manager.lights[j].position.toArray(),entry.world.clone().add(new T.Vector3(0,-.08,0)).toArray());
  const distance=Math.sqrt(entry.world.distanceToSquared(focus)),falloff=distance<34?1-Math.pow(distance/34,2):0;
  assert.equal(manager.lights[j].intensity,18*night*Math.max(0,falloff));
 });
}
manager.dispose();geometry.dispose();material.dispose();

// A microbenchmark of selection only, not whole-frame FPS.
fixtures.forEach(row=>row.active=true);
const focus=new T.Vector3(35,0,55);
for(let i=0;i<3000;i++){original(fixtures,focus,8);selectNearestLightFixtures(fixtures,focus,8,selected,distances)}
const times={};
for(const [name,run]of [['sort',()=>original(fixtures,focus,8)],['select',()=>selectNearestLightFixtures(fixtures,focus,8,selected,distances)]]){
 const begin=performance.now();for(let i=0;i<20000;i++)run();times[name]=+(performance.now()-begin).toFixed(2);
}
console.log('PASS exact nearest-light equivalence',JSON.stringify({comparisons:measurements,liveManagerFrames:120,selectionOnlyMs:times}));
