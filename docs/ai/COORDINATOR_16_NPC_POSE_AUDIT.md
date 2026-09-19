# Coordinator 16 — NPC pose CPU audit, 2026-09-12

Read-only investigation requested by Coordinator 16. No game source was changed. No browser/GPU measurement was performed. **Производительность общей сцены не проверена.** The candidate optimization is NOT applied and is not accepted for production.

## Finding

`assets/maps/city_rebuild_v1/hero_walk.mjs`, `worldRotation(name,q)` (line 329 at audit): after changing one bone's local matrix, the function calls `object.updateMatrixWorld(true)` on the entire actor. `reachPalm()` calls this through two `pointBone()` calls and a final wrist rotation; feet/head also use it. The actor hierarchy is therefore revisited repeatedly during one pose. The NPC surface and actor update then perform further complete matrix refreshes.

Candidate, to be coordinated with the Artist owner and tested more broadly: change only this refresh to `bone.updateMatrixWorld(true)`, updating the changed bone and its descendants. Parent world quaternion is obtained immediately before the change. Other branches have no local change from this operation. This remains a hypothesis for general behavior until all relevant pose, weapon, vehicle, reaction and landing tests pass.

## Actual CPU measurement

Node, real male/female GLBs, 24 NPCs, 8 with pistol, some talking, renderLOD=false; 100 warmup frames followed by 300 measured frames at fixed 1/60 dt. Source snapshots remain static, so this is an idle/talk/weapon sample, not a locomotion stress test. The temporary Node load hook changed the imported module in memory only.

| Metric | Baseline | Candidate |
|---|---:|---:|
| update p50, ms | 2.8392 | 2.6159 |
| update p95, ms | 3.3148 | 3.8820 |
| update mean, ms | 3.2282 | 3.1129 |
| Object3D.updateMatrixWorld visits/frame | 11858 | 8834 |

Visits fell 25.5%. **p95 worsened**, so there is no demonstrated stable overall speedup. CPU timings are a single noisy pair, not FPS evidence. Both runs exported 26336 matrixWorld elements at the final pose; maximum absolute difference was exactly 0. This proves equality only for that final sampled state, not all intermediate states or gameplay scenarios. Geometry, materials, and game logic were not changed by the candidate.

## Exact reproduction

Run from the repository root on the same Windows environment. Save the following as `$env:TEMP/npc-matrix-audit.mjs`. Run baseline and candidate sequentially:

```powershell
node "$env:TEMP/npc-matrix-audit.mjs"
node "$env:TEMP/npc-matrix-audit.mjs" --opt
node -e "const fs=require('fs'),p=process.env.TEMP;const a=JSON.parse(fs.readFileSync(p+'/npc-audit-base.json')),b=JSON.parse(fs.readFileSync(p+'/npc-audit-opt.json'));console.log({a:a.length,b:b.length,maxDifference:Math.max(...a.map((v,i)=>Math.abs(v-b[i])))})"
```

The script requires the existing local Three vendor path and the repository's vendored SkeletonUtils. It makes no network requests and writes only two temporary matrix snapshots. The global matrix-method wrapper counts visits and adds overhead to both runs. No production file is patched.

```javascript
import fs from 'node:fs';import {registerHooks} from 'node:module';import {pathToFileURL} from 'node:url';
const root=process.cwd()+'/assets/maps/city_rebuild_v1/',deps='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(deps+'/build/three.module.js').href:s,c)},load(u,c,n){let r=n(u,c);if(process.argv.includes('--opt')&&u.endsWith('/hero_walk.mjs'))r={...r,source:String(r.source).replace('bone.matrixWorldNeedsUpdate=true;object.updateMatrixWorld(true);','bone.matrixWorldNeedsUpdate=true;bone.updateMatrixWorld(true);')};return r;}});
const THREE=await import(pathToFileURL(deps+'/build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(deps+'/addons/loaders/GLTFLoader.js')),{clone}=await import(pathToFileURL(root+'vendor/three_skeleton_utils.mjs'));
globalThis.fetch=async(u)=>({ok:true,arrayBuffer:async()=>{const b=fs.readFileSync(new URL(u));return b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength)}});
const {createNpcPopulation}=await import(pathToFileURL(root+'npc_population.mjs'));
const scene=new THREE.Scene(),pop=await createNpcPopulation({THREE,scene,loader:new GLTFLoader(),cloneSkeleton:clone,maxActors:24,renderLOD:false});
const rows=Array.from({length:24},(_,i)=>({id:'audit_'+i,r:i/4.1,c:1,look:{gender:i%2},walking:true,weapon:i%3===0?'pistol':'fists',talking:i%7===0}));pop.sync(rows,1);
let wu=THREE.Object3D.prototype.updateMatrixWorld,calls=0;THREE.Object3D.prototype.updateMatrixWorld=function(...args){calls++;return wu.apply(this,args)};
for(let f=0;f<100;f++)pop.update(1/60,1+f/60);calls=0;let values=[];for(let f=0;f<300;f++){let t=performance.now();pop.update(1/60,3+f/60);values.push(performance.now()-t)}values.sort((a,b)=>a-b);
let matrices=[];for(const row of rows)pop.getActor(row.id).object.traverse(o=>matrices.push(...o.matrixWorld.elements));fs.writeFileSync(process.env.TEMP+'/npc-audit-'+(process.argv.includes('--opt')?'opt':'base')+'.json',JSON.stringify(matrices));console.log(JSON.stringify({opt:process.argv.includes('--opt'),p50:values[150],p95:values[285],mean:values.reduce((a,b)=>a+b)/300,matrixVisitsPerFrame:calls/300}));pop.dispose();

```


## Follow-up: LIVE discrepancy isolation

The coordinator observed a later ~43 ms NPC median in the browser, whereas the CPU sample above was ~2.8 ms. Source inspection found no full-scene sibling traversal from NPC updateWorldMatrix: ancestor updates use updateChildren=false. This does not rule out expensive descendant traversal within the actor or expensive ground/water callbacks.

Added diagnostics only to npc_population.mjs when profile=true: poseNormalize, poseActor, poseWalker, poseSurface and poseActorOther in cpu.last/meanMs. These are nested inside pose and must not be summed with pose or total. poseActorOther is poseActor minus walker and surface. This separates world ground/water sampling, skeletal posing, surface/wetness, and activity/vehicle/other actor work. Default mode installs no wrappers and invokes no additional clock reads.

Validation: node --check passed; real-GLB CPU reproduction ran with profile=false and profile=true. Both retained exactly 11858 Object3D matrix visits/frame. Sample profile=true mean: pose 2.77 ms, normalize .01, actor 2.74, walker 1.62, surface .65, actorOther .47. This is not a LIVE result. Browser reload and measurement are owned by the coordinator to avoid concurrent browser/GPU activity.

## Confirmed root cause and applied population fix

Coordinator LIVE follow-up: pose mean 28.45 ms, actor 1.39 ms, normalize .05 ms, walker .42 ms, surface .80 ms, actorOther .17 ms; another steady sample pose 34.4 ms versus actor .97 ms. Thus skeletal animation was not the dominant cost. Those LIVE values are coordinator-provided measurements, not this subagent's browser run.

The host passes physics dt capped at .04 s while presentation `time` advances with the real frame clock. Mid/far NPC poseElapsed previously accumulated that capped dt. At 160 ms real frames, a far NPC posed only once per three frames: wall gap .48 s versus pose step .12 s. The catch-up branch misclassified continuous visibility as a long absence, then serialized and restored all clothing/wounds (including byte encoding, validation, reset and resource rebuild) repeatedly.

Applied only in npc_population.mjs: accumulate pose cadence from max(dt, presentation time since last population update), still capped at .25 s. First/non-advancing-clock ticks retain dt fallback. Genuine long gaps/offscreen reentry retain existing persistent-state restoration. No Artist files changed. Opt-in counters poseRestore and poseRestores expose restoration milliseconds and count; these are nested within pose, not additive frame stages.

Validation:
- node --check: PASS.
- test_npc_pose_clock.mjs: real GLB far NPC at 6.25 FPS with physics dt .04; 20 frames produce zero restoration. Wet clothing becomes wet, dries, confirmed death remains dead, offscreen return restores exactly once then resumes without repetition.
- Red/green: temporary in-memory load hook restored only old poseElapsed+dt. The new test failed with 7 restorations versus expected 0. The production source was not changed during that negative test.
- test_npc_population.mjs: all 21 checks passed, including wounds, serialization/eviction, death, gait, interpolation and source clocks.

LIVE post-fix measurement remains with coordinator; CPU regression tests alone are not a claim of global FPS improvement.
