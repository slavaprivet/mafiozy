import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
const sourcePath='assets/maps/city_rebuild_v1/weapon_effects.mjs';
const source=fs.readFileSync(sourcePath,'utf8');
const sourceHash=createHash('sha256').update(source).digest('hex');
if(sourceHash!=='4dfa7adf47309b89dd1b87bb0776abd1b2385c15c24256b749b7c71dfa9ff7ec')throw Error('Source changed; review before recapture');
const THREE=await import(pathToFileURL(path.join(process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor','build/three.module.js')));
const seam='return {shoot,update,dispose,stats,limits:';
if(source.split(seam).length!==2)throw Error('Source capture seam');
const capture=source.replace(seam,'return {debugPools:()=>({impactPool,markPool,explosionPool}),shoot,update,dispose,stats,limits:');
const {createWeaponEffects}=await import('data:text/javascript;base64,'+Buffer.from(capture).toString('base64'));
const scene=new THREE.Scene();
const fx=createWeaponEffects(THREE,scene,{limits:{projectiles:1,casings:1,flashes:1,impacts:1,marks:1,explosions:1,pendingCasings:1}});
const meshes={},seen=new Map();
function node(n){
 let mesh=null;
 if(n.geometry){
  const g=n.geometry;
  if(!seen.has(g)){const key='mesh'+seen.size;seen.set(g,key);meshes[key]={vertices:Array.from(g.attributes.position.array),normals:g.attributes.normal?Array.from(g.attributes.normal.array):[],uv:g.attributes.uv?Array.from(g.attributes.uv.array):[],indices:g.index?Array.from(g.index.array):[],lines:n.isLineSegments===true};}
  mesh=seen.get(g);
 }
 const m=n.material;
 return {name:n.name,position:n.position.toArray(),quaternion:n.quaternion.toArray(),scale:n.scale.toArray(),visible:n.visible,mesh,material:m?{color:m.color.getHexString(),metalness:m.metalness??0,roughness:m.roughness??1,unlit:m.isMeshBasicMaterial===true||m.isLineBasicMaterial===true,opacity:m.opacity,transparent:m.transparent,additive:m.blending===THREE.AdditiveBlending,depthWrite:m.depthWrite,doubleSided:m.side===THREE.DoubleSide}:null,children:n.children.map(node)};
}
const pools=fx.debugPools();
const result={source_sha256:sourceHash,meshes,impact:node(pools.impactPool[0].mesh),mark:node(pools.markPool[0].mesh),explosion:node(pools.explosionPool[0].root)};
const output=process.argv[2]??'godot/mafiozi_walk/data/weapons/surface_effect_meshes.json';
fs.mkdirSync(path.dirname(output),{recursive:true});
const encoded=JSON.stringify(result);fs.writeFileSync(output,encoded);
fx.dispose();
console.log(JSON.stringify({output,sourceHash,sha256:createHash('sha256').update(encoded).digest('hex'),bytes:encoded.length,meshes:Object.keys(meshes).length}));
