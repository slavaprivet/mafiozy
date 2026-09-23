import fs from 'node:fs';
import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {clone} from './test_npc_death_offline_setup.mjs';
import {createNpcActor,NPC_ASSETS} from './npc_actor.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c);}});
const T=await import(pathToFileURL(vendor+'build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const rows=[];
for(const sex of ['male','female']){
 const bytes=fs.readFileSync(new URL(NPC_ASSETS[sex].url)),source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 for(const mode of ['stand','crouch','slow','walk111','walk','fastwalk','run','sprint']){
  const speed=({stand:0,crouch:1.2,slow:.65,walk111:1.206,walk:1.5,fastwalk:1.82,run:2.6,sprint:7.8})[mode];
  const a=createNpcActor({THREE:T,scene:new T.Scene(),source,cloneSkeleton:clone,id:'npc_resident_111',sex}),c=a.walker.artistContext();
  a.update(0,{time:0,life:{},posture:{target:'stand',value:0}});const neutralHip=c.worldPosition('thigh_l').y,neutralHead=c.worldPosition('head').y;
  let maxHipDrop=0,maxHeadDrop=0,minHipDrop=Infinity,maxKneeFlex=0,minFoot=Infinity;
  for(let i=0;i<300;i++){
   const dt=1/60,time=i*dt,life={id:'npc_resident_111',activity:null,gesture:'work',routine:'work',routinePlan:{phase:'seek_shop'},seat:null,civilianTripPhase:null,cowering:false,downed:false,forcedCrawl:false};
   a.update(dt,{time,position:{x:0,y:0,z:time*speed},yaw:0,moving:speed>0,running:mode==='run'||mode==='sprint',slowWalking:mode==='slow',motionSpeed:speed,gaitDistance:speed*dt,posture:{target:mode==='crouch'?'crouch':'stand',value:mode==='crouch'?1:0},life});
   if(i<120)continue;
   const hip=c.worldPosition('thigh_l'),knee=c.worldPosition('shin_l'),foot=c.worldPosition('foot_l');
   maxHipDrop=Math.max(maxHipDrop,neutralHip-hip.y);minHipDrop=Math.min(minHipDrop,neutralHip-hip.y);maxHeadDrop=Math.max(maxHeadDrop,neutralHead-c.worldPosition('head').y);minFoot=Math.min(minFoot,foot.y);
   const v=hip.clone().sub(knee).normalize(),w=foot.clone().sub(knee).normalize();maxKneeFlex=Math.max(maxKneeFlex,180-Math.acos(Math.max(-1,Math.min(1,v.dot(w))))*180/Math.PI);
  }
  rows.push({sex,mode,speed,maxHipDrop,minHipDrop,maxHeadDrop,maxKneeFlex,minFoot,locomotion:a.diagnostics().locomotion});a.dispose();
 }
}
const baseline=process.argv.includes('--baseline');fs.writeFileSync(new URL('../../../outputs/npc_upright_walk23_'+(baseline?'baseline':'production')+'.json',import.meta.url),JSON.stringify({rows,limits:'Actual male/female rigs and reported resident111 life flags. CPU pose measurements, not LIVE visual/FPS.'},null,2)+'\n');
console.log(JSON.stringify(rows.map(({locomotion,...r})=>r),null,2));
if(!baseline)for(const r of rows){
 if(['slow','walk111','walk','fastwalk'].includes(r.mode)){
  assert(r.maxHipDrop<.08,'standing gait stays near neutral '+JSON.stringify(r));
  assert(r.minHipDrop<.015,'body rises over planted leg instead of fixed squat');assert(r.maxKneeFlex<80,'ordinary swing does not fold the knee as deeply as old walk');
  assert(r.minFoot>0,'ankles remain above floor');
 }
 if(r.mode==='crouch')assert(r.maxHipDrop>.2,'intentional crouch retained');
 if(r.mode==='run'||r.mode==='sprint')assert(r.maxHipDrop>.08&&r.maxHipDrop<.11,'running retains its separate stride/drop');
}
