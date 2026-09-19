import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import {installNativeTerrainRaycastIndex} from './native_terrain_raycast_index.mjs';
const THREE=await import(pathToFileURL('D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js'));
const original=THREE.Mesh.prototype._computeIntersections;
let comparisons=0,hitCount=0,candidateTotal=0;
const ray=(o,d,near=0,far=Infinity)=>new THREE.Raycaster(new THREE.Vector3(...o),new THREE.Vector3(...d).normalize(),near,far);
function parity(meshes,r){
 const expected=[],actual=[];
 for(const mesh of meshes){const hook=mesh._computeIntersections;mesh._computeIntersections=original;mesh.raycast(r,expected);mesh._computeIntersections=hook;mesh.raycast(r,actual);}
 assert.equal(actual.length,expected.length);
 for(let i=0;i<actual.length;i++){assert.equal(actual[i].object,expected[i].object);assert.deepEqual({...actual[i],object:null},{...expected[i],object:null});}
 // Actual Raycaster also sorts the original insertion order for equal distances.
 const hooks=meshes.map(m=>m._computeIntersections);meshes.forEach(m=>m._computeIntersections=original);
 const sortedExpected=r.intersectObjects(meshes,false);meshes.forEach((m,i)=>m._computeIntersections=hooks[i]);
 const sortedActual=r.intersectObjects(meshes,false);
 assert.deepEqual(sortedActual.map(h=>({...h,object:h.object.uuid})),sortedExpected.map(h=>({...h,object:h.object.uuid})));
 comparisons++;hitCount+=actual.length;return actual;
}
const source=readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8');
const first=source.indexOf('function terrain(grid,protectedMask,asphalt){'),last=source.indexOf('function inPolygon(',first);
assert(first>=0&&last>first);
const terrain=new Function('THREE','content','M',source.slice(first,last)+';return terrain;');
const topology=JSON.parse(readFileSync(new URL('./topology_for_placement.json',import.meta.url))),content=new THREE.Group();
terrain(THREE,content,4.1)(topology.grid,topology.protectedMask);
const meshes=content.children;content.updateMatrixWorld(true);
for(const m of meshes)if(m.userData.nativeTerrainKind==='water'){m.material.transparent=true;m.material.opacity=.92;}
const bytes=meshes.map(m=>Buffer.from(m.geometry.attributes.position.array.buffer).toString('base64'));
const ids=meshes.map(m=>[m.geometry.uuid,m.material.uuid,m.geometry.attributes.position,m.geometry.index,m.parent]);
const start=performance.now(),handles=meshes.map(mesh=>installNativeTerrainRaycastIndex({THREE,mesh}));
assert(handles.every(Boolean));const buildMs=performance.now()-start;
assert.equal(handles.reduce((n,h)=>n+h.stats.triangles,0),72000);
let seed=17;const random=()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/2**32);
for(let i=0;i<180;i++){
 const x=random()*180*4.1,z=random()*200*4.1;
 handles.forEach(h=>h.stats.lastCandidates=0);
 parity(meshes,ray([x,1+random()*50,z],[random()*.2-.1,-1,random()*.2-.1]));
 candidateTotal+=handles.reduce((n,h)=>n+h.stats.lastCandidates,0);
}
for(const [x,z]of [[0,0],[4.1,4.1],[4.1/2,4.1/2],[738,820],[328,41],[333.15,43.05],[-1,-1]]){
 for(const y of [0,-.18,10,-10])for(const d of [[0,-1,0],[0,1,0],[1,0,0],[1,-1e-12,0],[-0,-1,-0]])parity(meshes,ray([x,y,z],d));
}
// Actual source geometry is unchanged; lazy native boundingSphere is allowed.
meshes.forEach((m,i)=>{assert.equal(Buffer.from(m.geometry.attributes.position.array.buffer).toString('base64'),bytes[i]);assert.deepEqual([m.geometry.uuid,m.material.uuid,m.geometry.attributes.position,m.geometry.index,m.parent],ids[i]);});
function fixture(indexed=true){
 const g=new THREE.BufferGeometry();
 g.setAttribute('position',new THREE.Float32BufferAttribute([0,0,0,2,0,2,2,0,0,0,0,2],3));
 g.setIndex([0,1,2,0,3,1]);
 g.setAttribute('uv',new THREE.Float32BufferAttribute([0,0,1,1,1,0,0,1],2));
 g.setAttribute('uv1',new THREE.Float32BufferAttribute([.1,.2,.3,.4,.5,.6,.7,.8],2));
 g.computeVertexNormals();g.addGroup(0,3,99); // Single material ignores groups.
 const mesh=new THREE.Mesh(indexed?g:g.toNonIndexed(),new THREE.MeshStandardMaterial());
 mesh.userData.nativeTerrainKind='water';mesh.material.transparent=true;mesh.updateMatrixWorld(true);return mesh;
}
for(const indexed of [true,false]){
 const m=fixture(indexed),h=installNativeTerrainRaycastIndex({THREE,mesh:m});assert(h);
 for(const side of [THREE.FrontSide,THREE.BackSide,THREE.DoubleSide]){
  m.material.side=side;
  for(const [x,z]of [[1,1],[0,0],[2,2],[1,.5],[1,1+1e-14]])for(const y of [0,2,-2])for(const d of [[0,-1,0],[0,1,0],[1,0,0],[1,-1e-14,0]]){
   parity([m],ray([x,y,z],d));
  }
 }
 m.material.side=THREE.DoubleSide;
 for(const [near,far]of [[0,Infinity],[2,2],[0,2],[2,Infinity],[2+1e-12,Infinity],[0,2-1e-12]])parity([m],ray([1,2,1],[0,-1,0],near,far));
 assert.equal(parity([m],ray([1,2,1],[0,-1,0])).length,2,'shared diagonal keeps both hits');
 for(const [start,count]of [[0,1],[3,1],[0,4],[3,Infinity],[-3,7],[0,0],[6,3]]){m.geometry.setDrawRange(start,count);parity([m],ray([1,2,1],[0,-1,0]));}
 m.geometry.setDrawRange(0,Infinity);
 for(let i=0;i<250;i++){
  const exponent=i%12,dy=10**(-exponent),x=random()*2,z=random()*2;
  parity([m],ray([x-1,dy,z],[1,-dy,0]));
 }
 for(const height of [1e4,1e8,1e12,1e16])for(const x of [0,1,2])parity([m],ray([x,height,x],[0,-1,0]));
 const parent=new THREE.Group();parent.position.set(31,-7,13);parent.rotation.set(.2,.8,.3);parent.scale.set(2,3,.7);parent.add(m);parent.updateMatrixWorld(true);
 const origin=new THREE.Vector3(1,2,1).applyMatrix4(m.matrixWorld),direction=new THREE.Vector3(0,-1,0).transformDirection(m.matrixWorld);
 parity([m],new THREE.Raycaster(origin,direction));
 parent.scale.x=-2;parent.updateMatrixWorld(true);
 parity([m],new THREE.Raycaster(new THREE.Vector3(1,2,1).applyMatrix4(m.matrixWorld),new THREE.Vector3(0,-1,0).transformDirection(m.matrixWorld)));
 // Dynamic normal/UV/material do not invalidate positional bounds.
 m.geometry.attributes.uv.setXY(0,.9,.6);m.geometry.attributes.normal.setXYZ(0,.1,.8,.2);parity([m],new THREE.Raycaster(origin,direction));
 assert.equal(h.stats.fallbacks,0);h.dispose();assert.equal(m._computeIntersections,original);assert(!Object.hasOwn(m,'_computeIntersections'));
}
// Every supported invalidation goes through the original method, never stale BVH.
const mutations=[
 m=>m.geometry=m.geometry.clone(),
 m=>m.geometry.setAttribute('position',m.geometry.attributes.position.clone()),
 m=>m.geometry.attributes.position.needsUpdate=true,
 m=>m.geometry.attributes.position.array=m.geometry.attributes.position.array.slice(),
 m=>m.geometry.attributes.position.itemSize=4,
 m=>m.geometry.setIndex(m.geometry.index.clone()),
 m=>m.geometry.index.needsUpdate=true,
 m=>m.geometry.index.array=m.geometry.index.array.slice(),
 m=>m.geometry.setDrawRange(1,3),
 m=>{m.material=[m.material];m.geometry.groups[0].materialIndex=0;},
 m=>{m.geometry.morphAttributes.position=[m.geometry.attributes.position.clone()];m.updateMorphTargets();},
 m=>m.getVertexPosition=function(i,v){return THREE.Mesh.prototype.getVertexPosition.call(this,i,v);},
 m=>m.geometry.attributes.position.getX=function(i){return this.array[i*3];},
];
for(const mutate of mutations){
 const m=fixture(),h=installNativeTerrainRaycastIndex({THREE,mesh:m});mutate(m);
 // Direct compute also tests invalid layout cases whose broad sphere may reject.
 const r=ray([1,2,1],[0,-1,0]),expected=[],actual=[];original.call(m,r,expected,r.ray);m._computeIntersections(r,actual,r.ray);
 assert.deepEqual(actual.map(x=>({...x,object:null})),expected.map(x=>({...x,object:null})));assert.equal(h.stats.fallbacks,1);h.dispose();
}
for(const mutate of [m=>m.isInstancedMesh=true,m=>m.isSkinnedMesh=true,m=>m.material=[m.material],m=>m._computeIntersections=()=>{},m=>m.raycast=()=>{},m=>m.userData.nativeTerrainKind='other',m=>m.geometry.setDrawRange(1,3)]){
 const m=fixture();mutate(m);assert.equal(installNativeTerrainRaycastIndex({THREE,mesh:m}),null);
}
const owned=fixture(),ownedOriginal=owned._computeIntersections;owned._computeIntersections=ownedOriginal;
const ownedIndex=installNativeTerrainRaycastIndex({THREE,mesh:owned});ownedIndex.dispose();assert(Object.hasOwn(owned,'_computeIntersections'));assert.equal(owned._computeIntersections,ownedOriginal);
const replaced=fixture(),replacedIndex=installNativeTerrainRaycastIndex({THREE,mesh:replaced}),replacement=()=>{};replaced._computeIntersections=replacement;replacedIndex.dispose();assert.equal(replaced._computeIntersections,replacement);
// QA wrappers deliberately use fallback: do not measure the fast path with one.
const wrapped=fixture(),wrappedIndex=installNativeTerrainRaycastIndex({THREE,mesh:wrapped});wrapped.raycast=function(...args){return THREE.Mesh.prototype.raycast.apply(this,args);};
parity([wrapped],ray([1,2,1],[0,-1,0]));assert(wrappedIndex.stats.fallbacks>0);wrappedIndex.dispose();
const toggled=fixture(),toggledIndex=installNativeTerrainRaycastIndex({THREE,mesh:toggled}),nodeCount=toggledIndex.stats.nodes;
toggledIndex.setEnabled(false);parity([toggled],ray([1,2,1],[0,-1,0]));assert.equal(toggledIndex.stats.queries,0);assert(toggledIndex.stats.disabledQueries>0);
toggledIndex.setEnabled(true);parity([toggled],ray([1,2,1],[0,-1,0]));assert(toggledIndex.stats.queries>0);assert.equal(toggledIndex.stats.nodes,nodeCount);toggledIndex.dispose();assert.equal(toggledIndex.setEnabled(true),false);
for(const mode of ['uv','push']){
 const m=fixture(),h=installNativeTerrainRaycastIndex({THREE,mesh:m}),failure=new Error('expected '+mode),r=ray([1,2,1],[0,-1,0]);
 const attr=m.geometry.attributes.uv,getX=attr.getX;let reads=0;
 if(mode==='uv')attr.getX=function(i){if(++reads===4)throw failure;return getX.call(this,i);};
 function collect(method){
  reads=0;const prior={object:'existing'},hits=[prior];
  if(mode==='push')hits.push=function(hit){Array.prototype.push.call(this,hit);throw failure;};
  assert.throws(()=>method.call(m,r,hits,r.ray),error=>error===failure);
  assert.equal(hits[0],prior);assert.equal(hits.length,2);assert.equal(hits[1].object,m);return {...hits[1],object:null};
 }
 assert.deepEqual(collect(m._computeIntersections),collect(original));h.dispose();
}
if(process.argv.includes('--bench')){
 const rays=Array.from({length:120},()=>ray([random()*738,20,random()*820],[random()*.6-.3,-1,random()*.6-.3]));
 const hooks=meshes.map(m=>m._computeIntersections),baseline=[],accelerated=[],candidateCounts=[];
 function run(r,fast){
  meshes.forEach((m,i)=>m._computeIntersections=fast?hooks[i]:original);
  handles.forEach(h=>h.stats.lastCandidates=0);
  const before=performance.now(),hits=r.intersectObjects(meshes,false),elapsed=performance.now()-before;
  return {elapsed,hits:hits.length,candidates:handles.reduce((n,h)=>n+h.stats.lastCandidates,0)};
 }
 for(let i=0;i<30;i++){run(rays[i],false);run(rays[i],true);}
 for(let i=0;i<rays.length;i++){
  const results=i%2?[run(rays[i],true),run(rays[i],false)].reverse():[run(rays[i],false),run(rays[i],true)];
  assert.equal(results[0].hits,results[1].hits);baseline.push(results[0].elapsed);accelerated.push(results[1].elapsed);candidateCounts.push(results[1].candidates);
 }
 meshes.forEach((m,i)=>m._computeIntersections=hooks[i]);
 const quantile=(values,p)=>[...values].sort((a,b)=>a-b)[Math.ceil(values.length*p)-1];
 const timings=values=>({p50:+quantile(values,.5).toFixed(4),p95:+quantile(values,.95).toFixed(4)});
 console.log(JSON.stringify({benchmark:'CPU actual terrain only, same 120 seeded rays and 6 roots, 30 warm pairs, alternating order',baselineMs:timings(baseline),indexedMs:timings(accelerated),candidates:{mean:+(candidateCounts.reduce((a,b)=>a+b,0)/120).toFixed(2),p95:quantile(candidateCounts,.95),max:Math.max(...candidateCounts)},totalTriangles:72000}));
}
handles.forEach(h=>h.dispose());
const protectedGroup=new THREE.Group();terrain(THREE,protectedGroup,4.1)([[16,8],[0,9]],[[true,false],[false,false]]);
protectedGroup.updateMatrixWorld(true);
const protectedHandles=protectedGroup.children.map(mesh=>installNativeTerrainRaycastIndex({THREE,mesh}));assert(protectedHandles.every(Boolean));
parity(protectedGroup.children,ray([1,5,1],[0,-1,0]));assert.equal(parity(protectedGroup.children,ray([1,5,1],[0,-1,0]))[0].point.y,Math.fround(-.18));
protectedHandles.forEach(h=>h.dispose());
// Execute the actual startup/API/clear prefix without constructing the renderer.
const apiStart=source.indexOf('const nativeTerrainPickingRequested='),apiEnd=source.indexOf('\n};',apiStart)+3;
const buildLine=source.split('\n').find(line=>line.includes('if(nativeTerrainPickingRequested){const started='));
const clearPrefix=source.match(/function clearContent\(\{recreate=true\}=\{\}\)\{(.*?)cityRoadNavigation/)[1];
assert(apiStart>=0&&buildLine&&clearPrefix);
for(const [search,optIn]of [['',true],['?nativepick=1',true],['?nativepick=0',false]]){
 const shell={document:{body:{dataset:{}}},window:{},location:{search}},group=new THREE.Group(),mesh=fixture();group.add(mesh);
 const runtime=new Function('THREE','content','installNativeTerrainRaycastIndex','window','document','location',source.slice(apiStart,apiEnd)+';return {api:window.MafioziNativeTerrainPicking,build(){'+buildLine+'},clear(){'+clearPrefix+'}};')(THREE,group,installNativeTerrainRaycastIndex,shell.window,shell.document,shell.location);
 assert.equal(runtime.api.ready,false);assert.equal(runtime.api.enabled,false);runtime.build();assert.equal(runtime.api.ready,optIn);assert.equal(runtime.api.enabled,optIn);
 const generation=runtime.api.generation;runtime.api.setEnabled(false);assert.equal(runtime.api.enabled,false);runtime.api.setEnabled(true);assert.equal(runtime.api.enabled,optIn);assert.equal(runtime.api.generation,generation);
 runtime.clear();assert.equal(runtime.api.ready,false);assert.equal(runtime.api.enabled,false);assert.equal(runtime.api.generation,generation+1);assert.equal(mesh._computeIntersections,original);
 if(optIn){runtime.build();assert.equal(runtime.api.generation,generation+2);assert.equal(runtime.api.ready,true);runtime.clear();}
}
console.log(JSON.stringify({status:'PASS',comparisons,hits:hitCount,actualTerrainTriangles:72000,meshes:meshes.length,buildMs:+buildMs.toFixed(2),meanCandidatesPerNaturalRay:+(candidateTotal/180).toFixed(2),fallbackCases:mutations.length}));
