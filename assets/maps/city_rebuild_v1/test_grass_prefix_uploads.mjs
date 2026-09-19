import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import {createEnvironmentGrass} from './environment_grass.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/';
const THREE=await import(pathToFileURL(vendor+'three.module.js'));
// Execute the installed renderer's actual buffer uploader with in-memory GL
// buffers. This checks initial allocation and pending-range semantics, no GPU.
const code=readFileSync(vendor+'three.module.js','utf8'),start=code.indexOf('function WebGLAttributes( gl )'),tail=code.slice(start),end=tail.match(/\r?\n}\r?\n/);
assert(start>=0&&end);
const WebGLAttributes=new Function(tail.slice(0,end.index+end[0].length)+';return WebGLAttributes;')();
let bound;const storage=new Map(),writes=[];
const gl={FLOAT:1,ARRAY_BUFFER:2,createBuffer:()=>({}),bindBuffer(type,buffer){bound=buffer;},
 bufferData(type,array){storage.set(bound,array.slice());writes.push({kind:'allocation',buffer:bound,offset:0,count:array.length,bytes:array.byteLength});},
 bufferSubData(type,offset,array,sourceOffset=0,count=array.length){storage.get(bound).set(array.subarray(sourceOffset,sourceOffset+count),offset/array.BYTES_PER_ELEMENT);writes.push({kind:'update',buffer:bound,offset,count,bytes:count*array.BYTES_PER_ELEMENT});},
};
const manager=WebGLAttributes(gl),tufts=[];
for(let i=0;i<3000;i++)tufts.push({id:'near-'+i,x:(i%60)*.5,z:Math.floor(i/60)*.5,y:0,height:.8,width:1,yaw:i*.01,style:'reed',color:i%2?0x70824c:0x849259,radius:1,slopeX:(i%7)*.01,slopeZ:-(i%11)*.01});
for(let i=0;i<150;i++)tufts.push({...tufts[i],id:'far-'+i,x:256+(i%15)*.5,z:Math.floor(i/15)*.5,style:'grass'});
const grass=createEnvironmentGrass({THREE,plan:{stats:{tufts:tufts.length},tufts}}),allMeshes=grass.object.children.flatMap(c=>c.children),byId=new Map(tufts.map(t=>[t.id,t]));
const attributes=mesh=>[{attribute:mesh.instanceMatrix,size:16},{attribute:mesh.instanceColor,size:3},{attribute:mesh.geometry.attributes.grassSlope,size:2}];
const active=()=>allMeshes.filter(m=>m.visible);
function upload(){for(const mesh of active())for(const {attribute}of attributes(mesh))manager.update(attribute,gl.ARRAY_BUFFER);}
function verify(focus){
 let triangles=0,count=0;const actual=[];
 for(const mesh of active()){
  triangles+=mesh.count*mesh.geometry.index.count/3;count+=mesh.count;
  assert.equal(mesh.count,mesh.userData.tuftIds.length);
  for(let i=0;i<mesh.count;i++){
   const id=mesh.userData.tuftIds[i],t=byId.get(id);actual.push(id);
   const matrix=new THREE.Matrix4();mesh.getMatrixAt(i,matrix);
   assert.equal(matrix.elements[12],Math.fround(t.x));assert.equal(matrix.elements[14],Math.fround(t.z));
   const color=new THREE.Color(t.color),read=new THREE.Color();mesh.getColorAt(i,read);
   for(const k of ['r','g','b'])assert.equal(read[k],Math.fround(color[k]));
   assert.equal(mesh.geometry.attributes.grassSlope.getX(i),Math.fround(t.slopeX||0));assert.equal(mesh.geometry.attributes.grassSlope.getY(i),Math.fround(t.slopeZ||0));
  }
  for(const {attribute,size}of attributes(mesh))assert.deepEqual(storage.get(manager.get(attribute).buffer).subarray(0,mesh.count*size),attribute.array.subarray(0,mesh.count*size),'GPU prefix equals actual matrix/color/slope data');
 }
 const sorted=tufts.map((t,i)=>({t,i,d:Math.hypot(t.x-focus.x,t.z-focus.z)})).filter(v=>v.d<105).sort((a,b)=>a.d-b.d||a.i-b.i),expected=[];let expectedTriangles=0;
 for(const {t}of sorted){const n=t.style==='reed'?108:84;if(expected.length>=1200||expectedTriangles+n>90000)break;expected.push(t.id);expectedTriangles+=n;}
 assert.deepEqual(actual,expected,'selected tuft order unchanged');assert.equal(count,grass.stats.visibleTufts);assert.equal(triangles,grass.stats.visibleTriangles);assert.equal(triangles,expectedTriangles);
}
grass.update({time:1,focus:{x:15,z:12},force:true});const mesh=active()[0];assert.equal(mesh.count,833);upload();verify({x:15,z:12});
assert(writes.every(w=>w.kind==='allocation'),'first upload allocates full buffers');const firstBytes=writes.reduce((n,w)=>n+w.bytes,0);assert.equal(firstBytes,3000*84);
grass.update({time:2,focus:{x:-100,z:0},force:true});const smallerCount=mesh.count;assert(smallerCount>0&&smallerCount<833);
const cpuBefore=attributes(mesh).map(({attribute})=>attribute.array.slice());
// Two more selections before rendering must retain all pending changed ranges.
grass.update({time:3,focus:{x:15,z:12},force:true});grass.update({time:4,focus:{x:-100,z:0},force:true});
for(const {attribute,size}of attributes(mesh))assert(attribute.updateRanges.some(r=>r.start===0&&r.count>=833*size),'pending union retains the larger selection before count decreases');
const gpuBefore=attributes(mesh).map(({attribute})=>storage.get(manager.get(attribute).buffer).slice());writes.length=0;upload();verify({x:-100,z:0});
const unionBytes=writes.reduce((n,w)=>n+w.bytes,0);assert.equal(unionBytes,833*84);assert.equal(writes.length,3);
for(let i=0;i<attributes(mesh).length;i++){
 const {attribute,size}=attributes(mesh)[i],gpu=storage.get(manager.get(attribute).buffer);
 assert.deepEqual(gpu.subarray(833*size),gpuBefore[i].subarray(833*size),'GPU bytes outside pending prefix unchanged');
 assert.deepEqual(attribute.array.subarray(833*size),cpuBefore[i].subarray(833*size),'CPU bytes outside all written prefixes unchanged');assert.equal(attribute.updateRanges.length,0,'actual Three uploader clears consumed ranges');
}
writes.length=0;grass.update({time:5,focus:{x:-100,z:0},force:true});upload();assert.equal(writes.reduce((n,w)=>n+w.bytes,0),smallerCount*84,'after consumption only the current smaller prefix uploads');
const versions=attributes(mesh).map(({attribute})=>attribute.version);grass.update({time:5.016,focus:{x:-100,z:0}});assert.deepEqual(attributes(mesh).map(({attribute})=>attribute.version),versions,'ordinary frame changes uniforms only');
grass.update({time:6,focus:{x:1e6,z:1e6},force:true});assert.equal(active().length,0);assert.equal(grass.stats.visibleTufts,0);
grass.update({time:7,focus:{x:260,z:2},force:true});writes.length=0;upload();verify({x:260,z:2});assert(writes.every(w=>w.kind==='allocation'),'previously hidden chunk gets full first upload');
grass.update({time:8,focus:{x:15,z:12},force:true});writes.length=0;upload();verify({x:15,z:12});assert.equal(writes.reduce((n,w)=>n+w.bytes,0),833*84,'hidden-to-visible old chunk uploads its new active prefix');
assert.equal(grass.limits.maxVisibleTriangles,90000);assert.equal(grass.limits.maxVisibleTufts,1200);assert.equal(grass.limits.maxVisibleBatches,24);assert.equal(grass.limits.viewDistance,105);
// Offscreen selections may not flush for a long time. Keep one prefix range
// and preserve unrelated pending tail ranges instead of accumulating records.
const pending=createEnvironmentGrass({THREE,plan:{stats:{tufts:50},tufts:tufts.slice(0,50)},limits:{maxVisibleTufts:10,maxVisibleTriangles:1080}});
pending.update({time:1,focus:{x:3,z:0},force:true});const pendingMesh=pending.object.children.flatMap(c=>c.children).find(m=>m.visible),foreign=[];
for(const {attribute}of attributes(pendingMesh)){
 manager.update(attribute,gl.ARRAY_BUFFER);const start=attribute.array.length-2;attribute.array[start]=123;attribute.array[start+1]=456;attribute.addUpdateRange(start,2);foreign.push(attribute.updateRanges.at(-1));
}
for(let i=0;i<1000;i++)pending.update({time:2+i*.3,focus:{x:i%2?3:12,z:0},force:true});
for(const [i,{attribute,size}]of attributes(pendingMesh).entries()){
 assert.equal(attribute.updateRanges.length,2,'1000 unflushed selections retain only one prefix plus foreign range');
 assert(attribute.updateRanges.includes(foreign[i]),'unrelated pending range object survives');
 assert.equal(attribute.updateRanges.find(r=>r.start===0).count,10*size);
 manager.update(attribute,gl.ARRAY_BUFFER);const actual=storage.get(manager.get(attribute).buffer);
 assert.deepEqual(actual.subarray(0,pendingMesh.count*size),attribute.array.subarray(0,pendingMesh.count*size));
 assert.deepEqual(Array.from(actual.subarray(-2)),[123,456],'foreign pending bytes are still uploaded');assert.equal(attribute.updateRanges.length,0);
}
pending.dispose();
console.log(JSON.stringify({status:'PASS',firstBytes,fullSubsequentBytes:3000*84,prefixBytes:unionBytes,smallerCount,unflushedSelections:1000,pendingRangesWithForeign:2,checks:'actual Three initial allocation, bounded pending union with foreign ranges, count shrink/grow, hidden/reappear, order/matrices/colors/slopes, untouched tail, consumed ranges, uniforms-only frame, unchanged budgets'}));grass.dispose();
