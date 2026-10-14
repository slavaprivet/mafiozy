// Unimported owner-slot fixture for a future hero_walk IK scratch-pool patch.
// Run: node --expose-gc benchmark_hero_walk_ik_allocations.mjs
// Candidate: HERO_WALK_CANDIDATE=/absolute/path/hero_walk.mjs node --expose-gc ...
// Gate candidate sampled allocation with HERO_WALK_ENFORCE_ZERO=1.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import inspector from 'node:inspector';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {performance} from 'node:perf_hooks';
import {createHeroMotionPoseApplicator,createHeroMotionPoseOrchestrator} from './hero_motion_pose_orchestrator.mjs';
import {sampleHeroLadderMotion} from './hero_ladder_motion_pose.mjs';

const here=path.dirname(fileURLToPath(import.meta.url));
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(path.join(vendor,'build/three.module.js')).href:s,c)}});
const THREE=await import(pathToFileURL(path.join(vendor,'build/three.module.js')));
const {GLTFLoader}=await import(pathToFileURL(path.join(vendor,'addons/loaders/GLTFLoader.js')));
const baselineUrl=new URL('./hero_walk.mjs?ik-allocation-baseline',import.meta.url);
const candidatePath=process.env.HERO_WALK_CANDIDATE;
const candidateUrl=candidatePath?pathToFileURL(path.resolve(candidatePath)):new URL('./hero_walk.mjs?ik-allocation-candidate',import.meta.url);
const baselineFactory=(await import(baselineUrl)).createHeroWalker,candidateFactory=(await import(candidateUrl)).createHeroWalker;
const models=['player_male.8130dfb1f7eb.glb','player_female.298d50e6244a.glb'];
const ladder={lower:{x:4,y:0,z:-2},upper:{x:4,y:5,z:-2},normal:{x:0,z:-1},right:{x:-1,z:0},rungSpacing:.28,width:.8,yaw:0};

function rpc(session,method,params={}){return new Promise((resolve,reject)=>session.post(method,params,(error,result)=>error?reject(error):resolve(result)))}
function sampledBytes(node,ownerSeen=false){const frame=node.callFrame||{},owner=ownerSeen||String(frame.url||'').includes('hero_walk.mjs');let bytes=owner?(node.selfSize||0):0;for(const child of node.children||[])bytes+=sampledBytes(child,owner);return bytes}
function totalBytes(node){let bytes=node.selfSize||0;for(const child of node.children||[])bytes+=totalBytes(child);return bytes}
function maxDistance(a,b){let max=0;for(let i=0;i<a.length;i+=3)max=Math.max(max,Math.hypot(a[i]-b[i],a[i+1]-b[i+1],a[i+2]-b[i+2]));return max}

async function load(factory,bytes){const scene=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene,hero=factory({THREE,scene});hero.object.position.set(4,1.4,-2);return {scene,hero,context:hero.artistContext()}}
function snapshot(record){const {scene,hero}=record,meshes=[];scene.traverse(node=>{if(node.isSkinnedMesh)meshes.push(node)});hero.object.updateMatrixWorld(true);const inverse=hero.object.matrixWorld.clone().invert(),point=new THREE.Vector3(),values=[];for(const mesh of meshes){mesh.skeleton.update();const positions=mesh.geometry.attributes.position;for(let i=0;i<positions.count;i++){point.fromBufferAttribute(positions,i);mesh.applyBoneTransform(i,point);point.applyMatrix4(mesh.matrixWorld).applyMatrix4(inverse);values.push(point.x,point.y,point.z)}}return values}
function makeLoop(record){const orchestrator=createHeroMotionPoseOrchestrator(),applicator=createHeroMotionPoseApplicator(THREE,record.context),sample=sampleHeroLadderMotion(ladder,{x:4,y:1.4,z:-2},{travelled:.84,direction:1}),input={ladder:{active:true,sample,contacts:{handLVerified:true,handRVerified:true}}};let frameResult=null;return {step(){record.hero.update(1/60,true,false,null,{},{});frameResult=applicator.apply(orchestrator.update(1/60,input));return frameResult},get result(){return frameResult}}}

const reports=[];
for(const model of models){
 const bytes=fs.readFileSync(path.join(here,'hero_models',model)),baseline=await load(baselineFactory,bytes),candidate=await load(candidateFactory,bytes),baselineLoop=makeLoop(baseline),candidateLoop=makeLoop(candidate);
 let maxSkinDelta=0;for(let i=0;i<180;i++){baselineLoop.step();candidateLoop.step();if(i%15===0)maxSkinDelta=Math.max(maxSkinDelta,maxDistance(snapshot(baseline),snapshot(candidate)))}assert.ok(maxSkinDelta<1e-7,`${model} candidate skin delta ${maxSkinDelta}`);
 for(let i=0;i<500;i++)candidateLoop.step();const stableResult=candidateLoop.result;for(let i=0;i<20;i++){candidateLoop.step();assert.strictEqual(candidateLoop.result,stableResult,'applicator result must be pooled')}
 global.gc?.();const heapBefore=process.memoryUsage().heapUsed,session=new inspector.Session();session.connect();await rpc(session,'HeapProfiler.enable');await rpc(session,'HeapProfiler.startSampling',{samplingInterval:512,includeObjectsCollectedByMajorGC:true,includeObjectsCollectedByMinorGC:true});
 const iterations=5000,start=performance.now();for(let i=0;i<iterations;i++)candidateLoop.step();const elapsedMs=performance.now()-start,{profile}=await rpc(session,'HeapProfiler.stopSampling');session.disconnect();global.gc?.();const heapAfter=process.memoryUsage().heapUsed,heroWalkSampledBytes=sampledBytes(profile.head),allSampledBytes=totalBytes(profile.head);
 if(process.env.HERO_WALK_ENFORCE_ZERO==='1')assert.equal(heroWalkSampledBytes,0,`steady hero_walk allocation sampled: ${heroWalkSampledBytes} bytes`);
 reports.push({model,maxSkinDelta,iterations,elapsedMs,msPerFrame:elapsedMs/iterations,retainedHeapDelta:heapAfter-heapBefore,heroWalkSampledBytes,allSampledBytes});baseline.hero.dispose();candidate.hero.dispose();
}
console.log(JSON.stringify({passed:true,candidate:String(candidateUrl),gcExposed:typeof global.gc==='function',reports,visualTolerance:1e-7,enforcedZero:process.env.HERO_WALK_ENFORCE_ZERO==='1'}));
