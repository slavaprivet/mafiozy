import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {subtractBoxFromGeometry} from './building_entry.mjs';
const T=await import(pathToFileURL((process.env.THREE_VENDOR_ROOT||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/')+'build/three.module.js'));
let checked=0;
for(const mode of ['ordered','reversed','gaps','overlap'])for(const keepInside of [false,true]){
 const source=new T.BoxGeometry(4,4,4).toNonIndexed();
 const tags=Float32Array.from({length:source.attributes.position.count},(_,i)=>Math.floor(i/3));
 source.setAttribute('sourceTriangle',new T.BufferAttribute(tags,1));
 if(mode==='reversed')source.groups.reverse();
 if(mode==='gaps')source.groups.splice(2,1);
 if(mode==='overlap')source.groups.unshift({start:3,count:18,materialIndex:12});
 const groupsBefore=JSON.stringify(source.groups),verticesBefore=source.attributes.position.array.slice();
 const cut=new T.Box3(new T.Vector3(-1,-3,-3),new T.Vector3(3,1,3));
 const geometry=subtractBoxFromGeometry(T,source,new T.Matrix4(),cut,keepInside);
 assert(geometry.attributes.position.count>0);
 for(let i=0;i<geometry.attributes.position.count;i++){
  const tag=geometry.attributes.sourceTriangle.getX(i),sourceOffset=tag*3;
  assert.equal(tag,Math.round(tag),'triangle provenance survives interpolation');
  const expected=source.groups.find(g=>sourceOffset>=g.start&&sourceOffset<g.start+g.count)?.materialIndex??0;
  const actual=geometry.groups.find(g=>i>=g.start&&i<g.start+g.count)?.materialIndex??0;
  assert.equal(actual,expected,`${mode}: cut face retains authored material`);checked++;
 }
 assert.equal(JSON.stringify(source.groups),groupsBefore);
 assert.deepEqual(source.attributes.position.array,verticesBefore);
 geometry.dispose();source.dispose();
}
console.log(`PASS ${checked} clipped vertices preserve source materials, including unordered/overlapping ranges and gaps`);
