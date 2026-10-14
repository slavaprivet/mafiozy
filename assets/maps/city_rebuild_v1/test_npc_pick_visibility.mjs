import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createNpcPickVisibility} from './npc_pick_visibility.mjs';
const vendor=process.env.MAFIOZI_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const T=await import(pathToFileURL(vendor+'/build/three.module.js'));
const geometry=new T.BoxGeometry(),material=new T.MeshBasicMaterial();let passed=0;
const visible=o=>{for(let n=o;n;n=n.parent)if(n.visible===false)return false;return true;};
const sig=hits=>hits.filter(h=>visible(h.object)&&!h.object.userData.mercenaryPickIgnore).map(h=>[h.object.uuid,h.distance,h.faceIndex,h.instanceId,h.point.toArray()]);
function fixture(){
 const hidden=new T.Group(),visibleNpc=new T.Group(),outside=new T.Group();hidden.visible=false;
 for(const root of [hidden,visibleNpc,outside]){root.add(new T.Mesh(geometry,material));root.updateMatrixWorld(true);}
 const npcRoots=[hidden,visibleNpc],roots=[hidden,visibleNpc,outside],ray=new T.Raycaster(new T.Vector3(0,0,5),new T.Vector3(0,0,-1),0,80),trusted=new WeakSet();
 const helper=createNpcPickVisibility({THREE:T,getNpcRoots:()=>npcRoots,trustedRaycasts:trusted});helper.setEnabled(true);
 return{hidden,visibleNpc,outside,npcRoots,roots,ray,helper,trusted};
}
function check(name,run){run();passed++;}
check('root duplicates, accepted hit order, hidden child, material hidden and layers',()=>{
 const f=fixture();f.roots.push(f.visibleNpc);f.visibleNpc.children[0].material=material.clone();f.visibleNpc.children[0].material.visible=false;
 const hiddenChild=new T.Mesh(geometry,material);hiddenChild.visible=false;f.visibleNpc.add(hiddenChild);f.visibleNpc.layers.set(1);f.visibleNpc.updateMatrixWorld(true);
 const expected=sig(f.ray.intersectObjects(f.roots,true));assert.deepEqual(sig(f.helper.intersect(f.ray,f.roots)),expected);assert.equal(f.helper.stats.optimizedQueries,1);assert.equal(f.helper.stats.skippedRoots,1);f.visibleNpc.children[0].material.dispose();
});
check('nested NPC root and invisible ancestor',()=>{
 const f=fixture(),parent=new T.Group();parent.visible=false;f.hidden.visible=true;parent.add(f.hidden);f.roots=[parent,f.visibleNpc];
 assert.deepEqual(sig(f.helper.intersect(f.ray,f.roots)),sig(f.ray.intersectObjects(f.roots,true)));assert.equal(f.helper.stats.skippedRoots,1);
});
check('unknown preceding/later callback can unhide skipped actor: whole query falls back',()=>{
 for(const before of [false,true]){const f=fixture(),custom=new T.Group();custom.raycast=()=>{f.hidden.visible=true;};f.roots=before?[custom,f.hidden]:[f.hidden,custom];
  const expected=sig(f.ray.intersectObjects(f.roots,true));f.hidden.visible=false;
  assert.deepEqual(sig(f.helper.intersect(f.ray,f.roots)),expected);assert.equal(f.helper.stats.lastReason,'custom-raycast');assert.equal(f.helper.stats.skippedRoots,0);
 }
});
check('custom external emitted hit retained by native fallback',()=>{
 const f=fixture();f.hidden.raycast=(_ray,hits)=>hits.push({object:f.outside,distance:0,point:new T.Vector3()});
 assert.deepEqual(sig(f.helper.intersect(f.ray,f.roots)),sig(f.ray.intersectObjects(f.roots,true)));assert.equal(f.helper.stats.lastReason,'custom-raycast');
});
check('explicit owner-trusted pure propagate=false and layer mismatch preserve semantics',()=>{
 const f=fixture(),stop=()=>false;f.outside.raycast=stop;f.trusted.add(stop);
 for(const layer of [0,1]){f.outside.layers.set(layer);assert.deepEqual(sig(f.helper.intersect(f.ray,f.roots)),sig(f.ray.intersectObjects(f.roots,true)));assert.equal(f.helper.stats.lastReason,'optimized');}
});
check('fresh custom method/geometry override fallback; no stale trust cache',()=>{
 for(const key of ['raycast','getVertexPosition','_computeIntersections']){const f=fixture();f.helper.intersect(f.ray,f.roots);const mesh=f.hidden.children[0],old=mesh[key];mesh[key]=function(...args){return old.apply(this,args)};
  f.helper.intersect(f.ray,f.roots);assert.match(f.helper.stats.lastReason,/custom-/);assert.equal(f.helper.stats.optimizedQueries,1);
 }
 const f=fixture(),geo=geometry.clone();f.hidden.children[0].geometry=geo;const old=geo.computeBoundingSphere;geo.computeBoundingSphere=function(){return old.call(this)};f.helper.intersect(f.ray,f.roots);assert.equal(f.helper.stats.lastReason,'custom-geometry');geo.dispose();
});
check('SkinnedMesh bone override and InstancedMesh matrix override fallback',()=>{
 for(const kind of ['skin','instance']){const f=fixture();const mesh=kind==='skin'?new T.SkinnedMesh(geometry,material):new T.InstancedMesh(geometry,material,0);const key=kind==='skin'?'applyBoneTransform':'getMatrixAt',old=mesh[key];mesh[key]=function(...args){return old.apply(this,args)};
  // Own callback still canonical; override is caught without entering unbound skin.
  mesh.layers.set(1);f.hidden.add(mesh);f.helper.intersect(f.ray,f.roots);assert.equal(f.helper.stats.lastReason,kind==='skin'?'custom-skin':'custom-instances');
 }
});
check('unknown LOD fallback, disabled/version/overridden raycaster native path',()=>{
 const f=fixture();f.outside.add(new T.LOD());f.helper.intersect(f.ray,f.roots);assert.equal(f.helper.stats.lastReason,'unsupported-node');
 f.helper.setEnabled(false);f.helper.intersect(f.ray,f.roots);assert.equal(f.helper.stats.lastReason,'disabled');
 const revision=createNpcPickVisibility({THREE:{...T,REVISION:'181'},getNpcRoots:()=>f.npcRoots});revision.setEnabled(true);revision.intersect(f.ray,f.roots);assert.equal(revision.stats.lastReason,'three-version');
 const g=fixture(),native=g.ray.intersectObjects;g.ray.intersectObjects=function(...args){return native.apply(this,args)};g.helper.intersect(g.ray,g.roots);assert.equal(g.helper.stats.lastReason,'custom-raycaster');
});
check('fresh visible state and original stale matrix semantics preserved',()=>{
 const f=fixture();f.hidden.visible=true;f.helper.intersect(f.ray,f.roots);assert.equal(f.helper.stats.lastReason,'no-hidden-npcs');f.hidden.visible=false;f.visibleNpc.position.x=100;
 assert.deepEqual(sig(f.helper.intersect(f.ray,f.roots)),sig(f.ray.intersectObjects(f.roots,true)));assert.equal(f.visibleNpc.matrixWorld.elements[12],0);
});
// Small deterministic CPU comparison only; no live-scene performance assertion.
const f=fixture();f.roots.length=0;f.npcRoots.length=0;
for(let i=0;i<72;i++){const root=new T.Group();root.visible=i<12;for(let j=0;j<2;j++)root.add(new T.Mesh(geometry,material));root.updateMatrixWorld(true);f.roots.push(root);f.npcRoots.push(root);}
const expected=sig(f.ray.intersectObjects(f.roots,true));assert.deepEqual(sig(f.helper.intersect(f.ray,f.roots)),expected);assert.equal(f.helper.stats.skippedRoots,60);
const timings={};for(const mode of ['native','candidate']){const values=[];for(let i=0;i<30;i++){const start=performance.now();mode==='native'?f.ray.intersectObjects(f.roots,true):f.helper.intersect(f.ray,f.roots);values.push(performance.now()-start);}values.sort((a,b)=>a-b);timings[mode]={p50Ms:values[14],p95Ms:values[28]};}
geometry.dispose();material.dispose();console.log(JSON.stringify({passed,synthetic72Roots:timings,scope:'CPU fixture only; candidate default OFF; world custom callbacks fallback'}));
