import fs from 'node:fs';
// Offline equivalent of SkeletonUtils.clone's hierarchy/skeleton remapping.
// Kept in test scope; production continues using the host's SkeletonUtils.
export function clone(source){
 const result=source.clone(true),pairs=new Map();
 function map(a,b){pairs.set(a,b);for(let i=0;i<a.children.length;i++)map(a.children[i],b.children[i]);}map(source,result);
 for(const [original,copy]of pairs)if(copy.isSkinnedMesh){copy.skeleton=original.skeleton.clone();copy.bindMatrix.copy(original.bindMatrix);copy.skeleton.bones=original.skeleton.bones.map(b=>pairs.get(b));copy.bind(copy.skeleton,copy.bindMatrix);}
 return result;
}
const nativeFetch=globalThis.fetch;
globalThis.fetch=async(url,options)=>{
 const href=String(url);
 if(href==='https://cdn.jsdelivr.net/npm/three@0.180.0/examples/jsm/utils/SkeletonUtils.js')return {ok:true,text:async()=>`export ${clone.toString()}`};
 if(href.startsWith('file:'))return {ok:true,arrayBuffer:async()=>{const b=fs.readFileSync(new URL(href));return b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength)}};
 return nativeFetch(url,options);
};
