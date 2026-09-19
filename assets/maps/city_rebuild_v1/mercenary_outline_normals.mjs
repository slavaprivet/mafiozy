// Hull normals only: weld coincident vertices across authored hard-normal seams.
// The original geometry, lighting normals, positions and topology stay intact.
const cache=new WeakMap();
export function* smoothOutlineNormals(THREE,geometry){
 const position=geometry.attributes.position,source=geometry.attributes.normal;
 const old=cache.get(geometry);
 if(old&&old.position===position&&old.normal===source&&old.pv===position.version&&old.nv===source?.version)return old.attribute;
 const groups=new Map(),keys=new Array(position.count),normal=new THREE.Vector3();
 let generated=null,base=source;if(!base){generated=geometry.clone();generated.computeVertexNormals();base=generated.attributes.normal;}
 for(let i=0;i<position.count;i++){
  const key=Math.round(position.getX(i)*1e5)+','+Math.round(position.getY(i)*1e5)+','+Math.round(position.getZ(i)*1e5);keys[i]=key;
  let group=groups.get(key);if(!group){group={sum:new THREE.Vector3(),directions:new Set()};groups.set(key,group);}
  normal.fromBufferAttribute(base,i);const nk=Math.round(normal.x*1e4)+','+Math.round(normal.y*1e4)+','+Math.round(normal.z*1e4);
  if(!group.directions.has(nk)){group.directions.add(nk);group.sum.add(normal);}
  if(i>0&&i%1024===0)yield;
 }
 const values=new Float32Array(position.count*3);
 for(let i=0;i<position.count;i++){normal.copy(groups.get(keys[i]).sum);if(normal.lengthSq()<1e-8)normal.fromBufferAttribute(base,i);normal.normalize().toArray(values,i*3);if(i>0&&i%2048===0)yield;}
 generated?.dispose();const attribute=new THREE.BufferAttribute(values,3);cache.set(geometry,{position,normal:source,pv:position.version,nv:source?.version,attribute});return attribute;
}
