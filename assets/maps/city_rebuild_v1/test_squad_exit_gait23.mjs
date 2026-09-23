// Read-only actual source-decorator -> actual GLB actor regression. No browser/GPU.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
const root=new URL('../../../',import.meta.url),asset=new URL('assets/maps/city_rebuild_v1/',root);
const vendor=process.env.MAFIOZI_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const threeUrl=pathToFileURL(vendor+'/build/three.module.js').href;
registerHooks({resolve(s,c,next){return next(s==='three'?threeUrl:s,c);}});
const THREE=await import(threeUrl),{GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const {clone}=await import(new URL('test_npc_death_offline_setup.mjs',asset));
const {createNpcActor}=await import(new URL('npc_actor.mjs',asset));
const source=fs.readFileSync(new URL('mercenary_world.js',asset),'utf8');
const decorator=source.slice(source.indexOf(' function decorateEntities(value)'),source.indexOf(' const api='));
assert(decorator.includes('function decorateEntities(value)'),'source decorator anchor changed');
function exportedLife(stage){
 const member={id:'m0',hp:100,_mercenaryVehicleSeat:'front_right',_mercenaryVehicleId:'fleet:a',_mercenaryVehiclePhase:'exit',_mercenaryVehicleProgress:1,_mercenaryVehicleExitPlan:{stage}};
 const ctx={ready:true,record:id=>id==='m0'?{status:'active',profession:'engineer',level:1}:null,raw:()=>member,candidates:new Map(),squadPosture:()=> 'stand',weaponDrawn:()=>false,getVehicleFireIntent:()=>null};
 vm.createContext(ctx);vm.runInContext(decorator+';globalThis.decorate=decorateEntities;',ctx);
 return ctx.decorate([{id:'npc_crew_m0',hp:100,weapon:'none'}])[0];
}
const door=exportedLife('door'),body=exportedLife('body');
assert.equal(door.civilianTripPhase,'exit','door crossing must retain its actual vehicle transition');
const rows=[];
for(const [sex,file]of [['male','player_male.8130dfb1f7eb.glb'],['female','player_female.298d50e6244a.glb']]){
 const bytes=fs.readFileSync(new URL('hero_models/'+file,asset));
 const model=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 for(const [mode,life]of [['source-exit-body',body],['ordinary-walk',{}]]){
  const scene=new THREE.Scene(),car=new THREE.Group();scene.add(car);
  const vehicle={object:car,yaw:0,getSeat:()=>({side:1,canDrive:false}),getSeatRootWorld:()=>new THREE.Vector3(0,.65,0),poseOccupant:(walker,seat,o)=>walker.vehiclePose(o.fold,o.reach,o)};
  const actor=createNpcActor({THREE,scene,source:model,cloneSkeleton:clone,id:sex+'-'+mode,sex,getVehicle:()=>vehicle}),samples=[];
  for(let i=0;i<20;i++){
   actor.update(.05,{time:i*.05,position:{x:i*.15,y:0,z:0},yaw:0,moving:true,motionSpeed:3,gaitDistance:.15,posture:{target:'stand',value:0},life});
   samples.push(actor.walker.artistContext().bones.thigh_l.matrix.elements.slice());
  }
  let variation=0;for(const sample of samples)for(let i=0;i<16;i++)variation=Math.max(variation,Math.abs(sample[i]-samples[0][i]));
  rows.push({sex,mode,sourcePhase:life.civilianTripPhase||null,sourceRiding:life.civilianTripRiding??null,rootTravelM:2.85,thighVariation:variation});actor.dispose();
 }
}
const fixed=rows.filter(r=>r.mode==='source-exit-body').every(r=>r.thighVariation>.1);
console.log(JSON.stringify({fixed,rows,limits:'Actual decorator and actor/GLBs; binding supplies a minimal seat fixture. No full-scene FPS/LIVE claim.'},null,2));
if(process.argv.includes('--expect-fixed'))assert(fixed,'source exit body must animate ordinary walking legs');
