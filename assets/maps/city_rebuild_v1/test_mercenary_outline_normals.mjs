import test from 'node:test';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {smoothOutlineNormals} from './mercenary_outline_normals.mjs';
const THREE=await import(pathToFileURL((process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor')+'/build/three.module.js'));
const run=g=>{const it=smoothOutlineNormals(THREE,g);let next;do{next=it.next();}while(!next.done);return next.value;};
test('hard box seams share rounded outward extrusion without changing authored lighting',()=>{
 const g=new THREE.BoxGeometry(2,2,2),original=g.attributes.normal.array.slice(),n=run(g),p=g.attributes.position,seen=new Map();
 for(let i=0;i<p.count;i++){const key=[p.getX(i),p.getY(i),p.getZ(i)].join(','),v=new THREE.Vector3().fromBufferAttribute(n,i);assert(Math.abs(v.length()-1)<1e-6);assert(v.dot(new THREE.Vector3().fromBufferAttribute(p,i))>1.7);if(seen.has(key))assert(v.distanceTo(seen.get(key))<1e-7);else seen.set(key,v);}
 assert.deepEqual(g.attributes.normal.array,original);assert.equal(run(g),n,'reselect reuses derived normals');g.attributes.normal.needsUpdate=true;assert.notEqual(run(g),n,'changed geometry invalidates cache');g.dispose();
});
test('large smoothing yields and missing normals leave original geometry untouched',()=>{
 const g=new THREE.SphereGeometry(1,64,48);g.deleteAttribute('normal');const it=smoothOutlineNormals(THREE,g);let yields=0,next;do{next=it.next();if(!next.done)yields++;}while(!next.done);assert(yields>=2);assert.equal(g.attributes.normal,undefined);for(const v of next.value.array)assert(Number.isFinite(v));g.dispose();
});
