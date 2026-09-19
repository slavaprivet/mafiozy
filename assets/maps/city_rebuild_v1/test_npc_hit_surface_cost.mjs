// CPU comparison only. No browser scene or whole-game FPS claim.
import fs from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {clone} from './test_npc_death_offline_setup.mjs';
const baseline=process.env.NPC_HIT_SURFACE_BASELINE==='1',deps='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(deps+'/build/three.module.js').href:s,c);},load(url,c,next){
 const result=next(url,c);if(!baseline||!url.endsWith('/artist14/bullet_wounds.mjs'))return result;
 const source=String(result.source).replace("event.clothing??!(/SKIN/i.test(contactMaterial?.name||'')||/head|neck|hand/i.test(event.boneName||'')||event.zone==='head')","event.clothing??!(/head|neck|hand/i.test(event.boneName||''))")
  .replace('const query=contactQuery(state);','const query={surfaces:state.surfaces,dispose(){}};')
  .replace('if(contactAnchors.has(key))return contactAnchors.get(key);','');
 return {...result,source};
}});
const THREE=await import(pathToFileURL(deps+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(deps+'/addons/loaders/GLTFLoader.js'));
const {createNpcActor,NPC_ASSETS}=await import('./npc_actor.mjs');
const {createNpcContactRay}=await import('./npc_contact_ray.mjs');
const summary=s=>{s.sort((a,b)=>a-b);return {p50:+s[Math.floor(s.length*.5)].toFixed(3),p95:+s[Math.floor(s.length*.95)].toFixed(3)}};
const result={mode:baseline?'previous clothing classification':'actual contact material',milliseconds:{}};
for(const sex of ['male','female']){
 const bytes=fs.readFileSync(new URL(NPC_ASSETS[sex].url)),source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 const actor=createNpcActor({THREE,scene:new THREE.Scene(),source,cloneSkeleton:clone,id:sex,sex});actor.update(.1,{time:1});
 const ctx=actor.walker.artistContext(),ray=createNpcContactRay({THREE,getActors:()=>[actor]});
 for(const zone of ['head','chest']){
  const y=ctx.bones[zone].getWorldPosition(new THREE.Vector3()).y+(zone==='head'?.32:0),hit=ray({origin:new THREE.Vector3(0,y,5),direction:new THREE.Vector3(0,0,-1),range:10}),samples=[];
  for(let i=0;i<12;i++){actor.surface.reset();const at=performance.now();actor.receive({...hit,id:'bench'+i,confirmed:true,kind:'bullet'});const cost=performance.now()-at;if(i>=4)samples.push(cost);}
  result.milliseconds[sex+' '+zone+' receipt']=summary(samples);
 }
 actor.dispose();
}
console.log(JSON.stringify(result));
