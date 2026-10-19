// Paired CPU-only comparison. Production files are never modified. No renderer.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {registerHooks} from 'node:module';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {performance} from 'node:perf_hooks';
import path from 'node:path';
import os from 'node:os';
const hash=value=>createHash('sha256').update(value).digest('hex');
const file=fileURLToPath(import.meta.url),mode=process.argv[2];
if(!['current','baseline'].includes(mode)){
 const runs=[],directory=path.dirname(file),frozen={};
 for(const relative of fs.readdirSync(directory,{recursive:true}))if(/\.(mjs|js)$/.test(relative)){
  const absolute=path.join(directory,relative);frozen[pathToFileURL(absolute).href]=fs.readFileSync(absolute,'utf8');
 }
 const snapshotFile=path.join(os.tmpdir(),'mafiosi-bleed-benchmark-'+process.pid+'.json');
 fs.writeFileSync(snapshotFile,JSON.stringify(frozen));
 try{for(const variant of ['baseline','current','current','baseline']){
   const result=JSON.parse(execFileSync(process.execPath,[file,variant],{cwd:process.cwd(),encoding:'utf8',env:{...process.env,WOUND_BENCH_SOURCE_SNAPSHOT:snapshotFile},maxBuffer:5*1024*1024}));
   runs.push(result);console.error(variant+': '+JSON.stringify(result.frameMs));
  }}finally{fs.unlinkSync(snapshotFile);}
 // Both modes fingerprint ORIGINAL modules; the in-memory surface substitution
 // is excluded from this comparison, and the current-only helper is separate.
 for(const run of runs)assert.equal(run.commonModuleHash,runs[0].commonModuleHash,'production changed during paired benchmark');
 const summary={};
 for(const variant of ['baseline','current']){
  const group=runs.filter(r=>r.mode===variant);
  summary[variant]={p50:group.reduce((s,r)=>s+r.frameMs.p50,0)/group.length,p95:group.reduce((s,r)=>s+r.frameMs.p95,0)/group.length,peakParticles:Math.max(...group.map(r=>r.peakParticles)),peakPerActor:Math.max(...group.map(r=>r.peakPerActor)),drops:group.map(r=>r.emittedDrops)};
 }
 console.log(JSON.stringify({pass:true,scenario:'32 actual GLB actors: 16 wounded with four contacts each, 16 unwounded; alternating male/female; dt1/60,120 warmup+240 measured frames; ABBA fresh-process order',summary,deltaPercent:{p50:(summary.current.p50/summary.baseline.p50-1)*100,p95:(summary.current.p95/summary.baseline.p95-1)*100},runs,limits:'CPU actor.update only, real skeleton/surface/wound/particle instance updates. No renderer, GPU, camera, city simulation or whole-scene FPS. Receipt setup and asset loading excluded. Peak particle count includes warmup, while p50/p95 are warmed frames.'},null,2));
}else{
 const deps='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor',moduleHashes=new Map();
 const frozen=process.env.WOUND_BENCH_SOURCE_SNAPSHOT?JSON.parse(fs.readFileSync(process.env.WOUND_BENCH_SOURCE_SNAPSHOT,'utf8')):{};
 const baselineRef=process.env.WOUND_BASELINE_REF||'7370157';
 const oldSurface=execFileSync('git',['show',baselineRef+':assets/maps/city_rebuild_v1/hero_artist14_surface.mjs'],{encoding:'utf8'});
 const previousEmitter=oldSurface.split('\n').find(line=>line.includes('function emit('))?.trimEnd();
 const previousBurst=oldSurface.split('\n').find(line=>line.includes('emit(point,false,'))?.trimEnd();
 assert(previousEmitter&&previousBurst&&previousBurst.includes('18:10'),'baseline revision must predate wound bleeding');
 function baselineSurface(input){
  let source=input;
  const replace=(from,to='')=>{assert(source.includes(from),'missing baseline substitution: '+from);source=source.replace(from,to);};
  replace("import {createWoundBleeding} from './artist14/wound_bleeding.mjs';");
  replace(' const bleed=createWoundBleeding(THREE,{root:context.object,bones:context.bones,unit,height:context.targetHeight});');
  replace(source.split('\n').find(line=>line.includes('function emit(')),previousEmitter);
  replace(source.split('\n').find(line=>line.includes('emit(point,false,event.heavy?')),previousBurst);
  replace('   bleed.add({...event,point},time);');
  replace('  const bleeding=bleed.update(time,point=>emit(point,false,1,null,true));');
  replace('  if(bleeding.teleported)for(const p of particles)p.life=0;');
  replace('bleed.reset();');
  replace(',bleed:bleed.snapshot(time)');
  replace('bleed.validateSnapshot(data.bleed,data.receipts);');
  replace('  bleed.restore(data.bleed,{now:time,elapsedSeconds,receipts:data.receipts});');
  replace('bleedingStats:()=>({activeWounds:bleed.count,emittedDrops:bleed.emittedDrops}),');
  assert(!source.includes('bleed.')&&!source.includes('createWoundBleeding'));
  return source;
 }
 registerHooks({
  resolve(s,c,next){return next(s==='three'?pathToFileURL(deps+'/build/three.module.js').href:s,c);},
  load(url,c,next){
   const loaded=next(url,c),result=Object.hasOwn(frozen,url)?{...loaded,source:frozen[url]}:loaded;
   if(url.includes('/assets/maps/city_rebuild_v1/')&&!url.endsWith('/artist14/wound_bleeding.mjs')&&result.source!==undefined)moduleHashes.set(url,hash(String(result.source)));
   if(mode==='baseline'&&url.endsWith('/hero_artist14_surface.mjs'))return {...result,source:baselineSurface(String(result.source))};
   return result;
  }
 });
 const {clone}=await import('./test_npc_death_offline_setup.mjs');
 const {createNpcActor,NPC_ASSETS}=await import('./npc_actor.mjs');
 const {createNpcContactRay}=await import('./npc_contact_ray.mjs');
 const THREE=await import(pathToFileURL(deps+'/build/three.module.js'));
 const {GLTFLoader}=await import(pathToFileURL(deps+'/addons/loaders/GLTFLoader.js'));
 const sources={};
 for(const sex of ['male','female']){const bytes=fs.readFileSync(new URL(NPC_ASSETS[sex].url));sources[sex]=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;}
 const scene=new THREE.Scene(),actors=[],snapshots=[];
 for(let i=0;i<32;i++){
  const sex=i%2?'female':'male',actor=createNpcActor({THREE,scene,source:sources[sex],cloneSkeleton:clone,id:'cpu'+i,sex}),position={x:i%8*3,y:0,z:Math.floor(i/8)*3};
  const snapshot={time:0,position,yaw:0,moving:i<16,motionSpeed:i<16?1.3:0,groundWorldY:0};actor.update(0,snapshot);
  actors.push(actor);snapshots.push(snapshot);
  if(i<16){
   const ray=createNpcContactRay({THREE,getActors:()=>[actor]}),context=actor.walker.artistContext(),y=context.bones.chest.getWorldPosition(new THREE.Vector3()).y;
   for(let wound=0;wound<4;wound++){
    const hit=ray({origin:new THREE.Vector3(position.x+(wound%2?-.02:.02),y+(wound>1?.025:-.025),position.z+5),direction:new THREE.Vector3(0,0,-1),range:10});
    assert(hit,sex+' actual chest contact');assert(actor.receive({...hit,id:'wound'+wound,confirmed:true,kind:'bullet'}));
   }
  }
 }
 const samples=[],dt=1/60;let peakParticles=0,peakPerActor=0;
 for(let frame=0;frame<360;frame++){
  const now=(frame+1)*dt;
  for(let i=0;i<32;i++){snapshots[i].time=now;snapshots[i].position.x=i%8*3+(i<16?Math.sin(now*.4)*.2:0);snapshots[i].yaw=i<16?Math.sin(now*.3)*.15:0;}
  const started=performance.now();for(let i=0;i<32;i++)actors[i].update(dt,snapshots[i]);const elapsed=performance.now()-started;
  if(frame>=120)samples.push(elapsed);
  let particles=0;for(const actor of actors){particles+=actor.surface.particles.count;peakPerActor=Math.max(peakPerActor,actor.surface.particles.count);assert(actor.surface.particles.count<=112);}
  peakParticles=Math.max(peakParticles,particles);
 }
 samples.sort((a,b)=>a-b);
 const emittedDrops=actors.reduce((sum,actor)=>sum+(actor.surface.bleedingStats?.().emittedDrops||0),0);
 if(mode==='current'){assert(emittedDrops>0);assert(actors.slice(0,16).every(actor=>actor.surface.bleedingStats().activeWounds===4));}
 const report={mode,baselineRef,commonModuleHash:hash(JSON.stringify([...moduleHashes].sort(([a],[b])=>a.localeCompare(b)))),moduleCount:moduleHashes.size,frameMs:{p50:samples[Math.floor(samples.length*.5)],p95:samples[Math.floor(samples.length*.95)]},peakParticles,peakPerActor,emittedDrops};
 for(const actor of actors)actor.dispose();assert.equal(scene.children.length,0);console.log(JSON.stringify(report));
}
