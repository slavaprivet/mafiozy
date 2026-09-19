// Opt-in CPU microbenchmark. No renderer, GPU, browser or general-game FPS claim.
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {createHeroWalker} from './hero_walk.mjs';
import {createDemoCar,CAR} from './car_drive.mjs';
import {createArtistVehicle,ARTIST_VEHICLE_PROFILES} from './vehicle_fleet_models.mjs';
import {createWeaponModel} from './hero_arsenal.mjs';
import {applyCoverPose} from './hero_cover_pose.mjs';
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c);}});
const T=await import(pathToFileURL(vendor+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const {RoundedBoxGeometry}=await import('../../../tools/vehicle_fleet_qa/RoundedBoxGeometry.mjs');
const {vehicleCoverContact}=await import(process.env.COVER_CONTACT_MODULE?pathToFileURL(process.env.COVER_CONTACT_MODULE):new URL('./hero_cover_contact.mjs',import.meta.url));
const {weaponHeadClearance,findClearWeaponMount}=await import(process.env.COVER_CLEARANCE_MODULE?pathToFileURL(process.env.COVER_CLEARANCE_MODULE):new URL('./hero_weapon_clearance.mjs',import.meta.url));
async function glb(relative){const b=fs.readFileSync(new URL(relative,import.meta.url));return new GLTFLoader().parseAsync(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),'');}
const hero=createHeroWalker({THREE:T,scene:(await glb('./hero_models/player_male.8130dfb1f7eb.glb')).scene}),c=hero.artistContext();
const stats=a=>{const v=a.toSorted((a,b)=>a-b),q=p=>v[Math.min(v.length-1,Math.floor((v.length-1)*p))];return {samples:v.length,p50Ms:q(.50),p95Ms:q(.95),meanMs:v.reduce((s,x)=>s+x,0)/v.length,maxMs:v.at(-1)};};
function bench(fn,{warm=40,samples=120,prepare=()=>{}}={}){for(let i=0;i<warm;i++){prepare(i);fn(i);}const timings=[];for(let i=0;i<samples;i++){prepare(i);const t=performance.now();fn(i);timings.push(performance.now()-t);}return stats(timings);}
const dt=1/60,posture={value:1,target:'crouch'},aim={aimYaw:Math.PI,aimPitch:0};
let weapon=createWeaponModel(T,'shotgun');hero.mountWeapon(weapon);hero.object.rotation.y=Math.PI;
const update=()=>hero.update(dt,false,false,weapon,aim,{posture});
const report={kind:'CPU-only; no GPU/browser/general-game FPS',node:process.version,warmupFrames:40,normalUpdate:bench(update),contact:[],clearance:[],coverPose:[]};
report.inactiveContact=bench(()=>{for(let i=0;i<1000;i++)vehicleCoverContact(T,null,null,null);},{samples:100});
report.inactiveContact.units='1000 inactive calls per sample';
const cars=[{id:'kingswell',car:createDemoCar(T,RoundedBoxGeometry),profile:CAR}];
for(const profile of ARTIST_VEHICLE_PROFILES){const car=createArtistVehicle(T,RoundedBoxGeometry,await glb('./models/artist_vehicle_pack/'+profile.modelFile),profile);cars.push({id:profile.id,car,profile:car.profile});}
for(const {id,car,profile}of cars){
  hero.object.rotation.y=Math.PI/2;aim.aimYaw=Math.PI/2;hero.object.position.set(profile.halfWidth+.37,0,0);car.object.updateMatrixWorld(true);
  let last;update();const coldStart=performance.now();last=vehicleCoverContact(T,c,car.object,{x:1,z:0});const coldMs=performance.now()-coldStart;
  const cost=bench(()=>{last=vehicleCoverContact(T,c,car.object,{x:1,z:0});},{warm:10,samples:40,prepare:update});
  report.contact.push({id,coldMs,...cost,rays:last.rays,shift:last.distance,meanAmortized10HzMs:cost.meanMs/6});
}
hero.object.position.set(0,0,0);hero.object.rotation.y=Math.PI;aim.aimYaw=Math.PI;
for(const id of ['tt_pistol','shotgun','ak74','rpg']){
  weapon=createWeaponModel(T,id);hero.mountWeapon(weapon);update();
  const quaternion=new T.Quaternion().setFromEuler(new T.Euler(0,Math.PI,0,'YXZ'));
  const origin=weapon.getWorldPosition(new T.Vector3());
  const coldStart=performance.now();weaponHeadClearance(T,c,weapon,{origin,quaternion});const coldMs=performance.now()-coldStart;
  const clear=bench(()=>weaponHeadClearance(T,c,weapon,{origin,quaternion}),{prepare:update});
  const bad=c.worldPosition('head').add(new T.Vector3(0,.08,0));let solved;
  const solver=bench(()=>{solved=findClearWeaponMount(T,c,weapon,{origin:bad,quaternion,constraints:[{center:bad,radius:.8}],preferredSide:1});},{samples:80,prepare:update});
  report.clearance.push({id,coldMs,clear,blockedSolver:solver,candidates:solved.candidates});
  for(const mode of ['hidden','aimed','blind']){
    const sample={mode,low:true,normal:{x:0,z:-1},coverHeight:1.1,side:1,blend:1,weapon,aimYaw:0,aimPitch:0,attachmentId:'perf-'+id+'-'+mode,dt};
    const run=()=>{update();const q=new T.Quaternion();sample.gunPosition=mode==='hidden'?null:new T.Vector3(0,1.32,.30).sub(new T.Vector3(...weapon.userData.muzzle).multiply(weapon.getWorldScale(new T.Vector3())).applyQuaternion(q));applyCoverPose(T,c,sample);};
    report.coverPose.push({id,mode,totalHeroUpdateAndPose:bench(run)});
  }
}
const text=JSON.stringify(report,null,2);if(process.env.COVER_BENCH_OUTPUT)fs.writeFileSync(process.env.COVER_BENCH_OUTPUT,text);console.log(text);
