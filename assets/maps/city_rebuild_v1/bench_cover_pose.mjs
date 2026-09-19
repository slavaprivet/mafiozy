import fs from 'node:fs';
import {performance} from 'node:perf_hooks';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createHeroWalker} from './hero_walk.mjs';
import {createHeroCover} from './hero_cover_host.mjs';
import {createWeaponModel} from './hero_arsenal.mjs';
const vendor=process.env.MAFIOZI_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c)}});
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js'));const{GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const b=fs.readFileSync(new URL('./hero_models/player_male.8130dfb1f7eb.glb',import.meta.url));const scene=(await new GLTFLoader().parseAsync(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),'')).scene;
const weaponId=process.env.COVER_BENCH_WEAPON||'uzi';
const hero=createHeroWalker({THREE,scene}),weapon=createWeaponModel(THREE,weaponId);hero.mountWeapon(weapon);const posture={target:'crouch',value:1};
const body={id:'bench-cover',minY:0,maxY:1.1,vehicle:true,valid:true,polygon:[{x:0,z:0},{x:6,z:0},{x:6,z:2},{x:0,z:2}]};const document={body:{dataset:{},append(){}},createElement:()=>({style:{},setAttribute(){}})};
const cover=createHeroCover({THREE,document,getHero:()=>hero,getWeapon:()=>weapon,getBodies:()=>[body],canOccupy:()=>true,allowed:()=>true,requestPosture:t=>posture.target=t,getPosture:()=>posture,onMove(){},onEnter(){},obstacles:()=>[],groundHeight:()=>0});
const costs=[];let max=0;
for(let run=0;run<5;run++){
 hero.reset();hero.object.position.set(3,0,-.6);cover.toggle({x:0,z:1});
 for(const mode of ['hidden','blind','aimed','blind','hidden'])for(let i=0;i<86;i++){
  const dt=1/144;cover.update(dt,{direction:{x:0,z:1},aiming:mode==='aimed',firing:mode==='blind'});posture.value+=Math.max(-2.1*dt,Math.min(2.1*dt,(posture.target==='crouch'?1:0)-posture.value));
  hero.update(0,false,false,weapon,{aimYaw:hero.object.rotation.y,aimPitch:0},{posture});const start=performance.now();cover.pose({aimYaw:0,aimPitch:0});const ms=performance.now()-start;if(run>0)costs.push(ms);
 }
 cover.leave();
}
costs.sort((a,b)=>a-b);console.log(JSON.stringify({scenario:`warm actual-host male ${weaponId} 144Hz hidden-blind-aimed-blind-hidden; pose only, no GPU`,samples:costs.length,p50:costs[Math.floor(costs.length*.5)],p95:costs[Math.floor(costs.length*.95)],max:costs.at(-1)}));
