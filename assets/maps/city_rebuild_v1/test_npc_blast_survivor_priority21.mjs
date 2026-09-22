// Actual-source/GLB production regression. The baseline reverses only the two
// medical-crawl priority gates in memory; no production file is rewritten.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {normalizeNpcSnapshot} from './npc_population.mjs';

const world=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8').replaceAll('\r','');
const actorUrl=new URL('./npc_actor.mjs',import.meta.url),candidate=fs.readFileSync(actorUrl,'utf8');
const replaceOnce=(text,from,to)=>{assert.equal(text.split(from).length,2,'review concurrent actor change');return text.replace(from,to);};
let baseline=replaceOnce(candidate,'  const busyLife=medicalCrawl||locked||','  const busyLife=locked||');
baseline=replaceOnce(baseline,'  const visualAllowed=!medicalCrawl&&!locked&&','  const visualAllowed=!locked&&');
const beforeUrl=actorUrl.href+'?blast-survivor21-before',afterUrl=actorUrl.href+'?blast-survivor21-candidate';
const vendor=process.env.THREE_VENDOR_ROOT||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c)},load(u,c,next){const value=next(u,c);return u===beforeUrl?{...value,source:baseline}:u===afterUrl?{...value,source:candidate}:value;}});
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const {clone}=await import('./vendor/three_skeleton_utils.mjs');
const {createNpcActor:createBefore,NPC_ASSETS}=await import(beforeUrl),{createNpcActor:createAfter}=await import(afterUrl);
function actual(name){const start=world.indexOf('function '+name+'(');assert(start>=0,name);return world.slice(start,world.indexOf('\n}',start)+2);}
function hitFixture(extra={}){
 const noop=()=>{},ctx={performance:{now:()=>5000},Math:Object.create(Math),QP:{uid:'test'},player:{r:0,c:0},_walkConfirmDamage:noop,_markCombatBleeding:noop,_npcPathPassable:()=>true,_npcRememberAggression:noop,_npcSpreadRumor:noop,npcCivilianUnarmed:()=>false,_npcTrySurrenderAfterHit:()=>false,spawnFloatText:noop};
 ctx.Math.random=()=>.1;vm.createContext(ctx);vm.runInContext(actual('hitNpc'),ctx);
 const npc={id:'resident306',hp:60,r:3,c:2,walking:true,_arcKey:'worker',...extra};ctx.hitNpc(npc,0,1,'rpg',180);
 assert.equal(npc.hp,1);assert.equal(npc._medicalDowned,true);assert.equal(npc._forcedCrawl,true);assert.equal(npc.dead,undefined);assert.equal(npc._deathRecord20,undefined);
 return npc;
}
// Extract the actual fields that select posture/gesture, rather than replacing
// the source's medical state with invented animation flags in the fixture.
const viewStart=world.indexOf('const npcs=[];for(let i=0;i<npcSelected.length;i++)'),viewEnd=world.indexOf('};_threeNpcActionRefs.set',viewStart),view=world.slice(viewStart,viewEnd);
assert(viewStart>=0&&viewEnd>viewStart);
function expression(start,end){const a=view.indexOf(start);assert(a>=0,start);const b=view.indexOf(end,a+start.length);assert(b>a,end);return view.slice(a+start.length,b);}
const fields={downed:expression('downed:',',deadAt:'),forcedCrawl:expression('forcedCrawl:',',\n'),downedAt:expression('downedAt:',',downedUntil:'),downedUntil:expression('downedUntil:',',cuffed:'),cowering:expression('cowering=',',helping=')};
function row(npc,extra={}){const ctx={x:npc,fxNow:5000,death:{dead:false},lifeState:npc._lifeState||''},result={id:'npc_'+npc.id,r:npc.r,c:npc.c,dead:false,deathConfirmed:false,hp:npc.hp,walking:!!npc.walking,lifeState:ctx.lifeState,...extra};for(const [key,value]of Object.entries(fields))result[key]=vm.runInNewContext(value,ctx);return result;}
const signature=a=>Object.values(a.walker.artistContext().bones).flatMap(b=>b.matrixWorld.elements);
const difference=(a,b)=>Math.max(...signature(a).map((v,i)=>Math.abs(v-signature(b)[i])));
const reports=[],controls=[],cost=[[],[]];
for(const sex of ['male','female']){
 const bytes=fs.readFileSync(new URL(NPC_ASSETS[sex].url)),source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 const make=create=>create({THREE,scene:new THREE.Scene(),source,cloneSkeleton:clone,id:'npc_resident306',sex});
 const scenarios=[['clean',{},{}],['stale-cower',{_lifeState:'cower',_panicCowerUntil:9000},{}],['stale-seat',{}, {seat:{id:'bench',phase:'sit',height:.46,since:1000}}],['stale-phone',{}, {phoneCalling:true,phoneCallStartedAt:1000,phoneCallEndsAt:9000}],['stale-surrender',{}, {surrendering:true}],['stale-read',{}, {activity:{kind:'read',phase:'active',since:1000,until:9000}}]];
 for(const [name,sourceExtra,viewExtra]of scenarios){
  const npc=hitFixture(sourceExtra),snapshot=row(npc,viewExtra),pair=[make(createBefore),make(createAfter)],clean=make(createAfter);
  for(let i=0;i<16;i++){
   const time=5+i/20,snap=normalizeNpcSnapshot(snapshot,{time,sourceNowMs:time*1000});snap.gaitDistance=.015;
   pair.forEach((a,index)=>{const start=performance.now();a.update(.05,snap);cost[index].push(performance.now()-start);});
   const plain=normalizeNpcSnapshot(row(npc),{time,sourceNowMs:time*1000});plain.life.cowering=false;plain.life.lifeState='injured';plain.gaitDistance=.015;clean.update(.05,plain);
  }
  const heights=pair.map(a=>a.walker.artistContext().worldPosition('head').y),differences=pair.map(a=>difference(a,clean));
  assert.equal(pair[0].diagnostics().sourceDown,false);assert.equal(pair[0].surface.state.kind,'idle');
  assert.equal(pair[1].diagnostics().sourceDown,false);assert.equal(pair[1].surface.state.kind,'idle');
  assert(heights[1]<.8,'medical survivor stays prone');assert(differences[1]<1e-8,name+' candidate equals clean medical crawl');
  if(name==='stale-cower')assert(heights[0]>1.05,'actual stale cower overrides medical prone in baseline');
  if(name==='clean')assert(differences[0]<1e-8,'plain HP1 idle-surface crawl already works');
  reports.push({sex,name,baselineHeadM:heights[0],candidateHeadM:heights[1],baselineBoneDifference: differences[0],candidateBoneDifference:differences[1],sourceDown:false,reaction:'idle'});
  pair.forEach(a=>a.dispose());clean.dispose();
 }
 // No change for healthy civilians, a source-owned stun, a true fatal event,
 // or ambulance-owned hidden presentation. This proposal never changes HP.
 for(const [name,extra]of [['healthy-cower',{cowering:true}],['healthy-phone',{phoneCalling:true}],['healthy-seat',{seat:{id:'bench',phase:'sit',height:.46,since:1000}}],['melee-stun',{downed:true,meleeStunned:true,downedAt:4000}],['confirmed-death',{dead:true,deathConfirmed:true,deadAt:4500}],['carried-medical',{downed:true,forcedCrawl:true,carried:true}]]){
  const pair=[make(createBefore),make(createAfter)],baseRow={id:'npc_resident306',r:0,c:0,hp:60,dead:false,...extra};
  for(let i=0;i<6;i++)pair.forEach(a=>a.update(.1,normalizeNpcSnapshot(baseRow,{time:5+i*.1,sourceNowMs:5000+i*100})));
  assert(difference(...pair)<1e-8,name+' untouched');assert.equal(pair[0].object.visible,pair[1].object.visible);controls.push({sex,name,unchanged:true});pair.forEach(a=>a.dispose());
 }
}
const stats=a=>{a.sort((x,y)=>x-y);return {p50:a[Math.floor(a.length*.5)],p95:a[Math.floor(a.length*.95)],samples:a.length};};
console.log(JSON.stringify({pass:true,integrated:true,reports,controls,cpuMs:{before:stats(cost[0]),candidate:stats(cost[1])},limits:'Actual hitNpc and medical snapshot expressions with actual male/female GLB; source/physics recipients, survival balance, blood wounds and vehicle medical ownership unchanged. No LIVE/FPS claim.'},null,2));
