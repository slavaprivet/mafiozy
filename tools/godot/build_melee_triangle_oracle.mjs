// Executes the unchanged real Three/skinned-surface contact implementation.
// Single triangles are explicit geometry fixtures, not gameplay hit authority.
import fs from 'node:fs';
import crypto from 'node:crypto';
import {pathToFileURL} from 'node:url';
import {createNpcMeleeContact} from '../../assets/maps/city_rebuild_v1/npc_melee_contact.mjs';
const vendor=process.argv[2] ?? 'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js';
const T=await import(pathToFileURL(vendor));
let seed=18733;
const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
const rows=[];
const round=v=>new T.Vector3(Math.fround(v.x),Math.fround(v.y),Math.fround(v.z));
for(let variant=0;variant<3;variant++){
 const vertices=variant===2?[-.6,.3,0,.6,.3,0,0,.3,0]:[-.6,.3,0,.6,.3,0,0,1.7,0];
 const geometry=new T.BufferGeometry();geometry.setAttribute('position',new T.Float32BufferAttribute(vertices,3));
 geometry.setAttribute('skinIndex',new T.Uint16BufferAttribute(Array(3).fill([0,0,0,0]).flat(),4));
 geometry.setAttribute('skinWeight',new T.Float32BufferAttribute(Array(3).fill([1,0,0,0]).flat(),4));geometry.setIndex([0,1,2]);
 const actor=new T.Group(),mesh=new T.SkinnedMesh(geometry,new T.MeshBasicMaterial({side:T.DoubleSide}));
 const bone=new T.Bone();bone.name='head';mesh.add(bone);actor.add(mesh);mesh.bind(new T.Skeleton([bone]));
 if(variant===1){actor.position.set(10,2,-3);actor.rotation.y=.55;actor.scale.set(.8,1.1,.9);}
 actor.updateMatrixWorld(true);
 const query=createNpcMeleeContact({THREE:T,getActors:()=>[{id:'TEST_ONLY_triangle',object:actor}],obstacles:()=>[]});
 const triangles=[0,1,2].map(i=>mesh.getVertexPosition(i,new T.Vector3()).applyMatrix4(mesh.matrixWorld));
 const cases=[[[0,1,1],[0,1,-1],.1],[[0,1,0],[0,1,0],.1],[[.61,.3,.04],[.61,.3,.04],.1],[[.8,1,.1],[.8,1,-.1],.1],[[0,1,-1],[0,1,1],.1],[[0,1,.05],[.2,1,.05],.1]];
 for(let i=0;i<90;i++) cases.push([[random()*2-1,random()*2,random()*1.6-.8],[random()*2-1,random()*2,random()*1.6-.8],.03+random()*.2]);
 for(const [previous,current,radius] of cases){
  const from=round(new T.Vector3(...previous).applyMatrix4(actor.matrixWorld)),to=round(new T.Vector3(...current).applyMatrix4(actor.matrixWorld));
  const hit=query({previous:from,current:to,radius,attackType:'punch'});
  rows.push({variant,from:from.toArray(),to:to.toArray(),radius,triangle:triangles.map(v=>v.toArray()),expected:hit?{point:Object.values(hit.point),normal:Object.values(hit.normal),weights:hit.anchor.weights,distance:hit.distance}:null});
 }
 geometry.dispose();mesh.material.dispose();
}
const source=new URL('../../assets/maps/city_rebuild_v1/npc_melee_contact.mjs',import.meta.url);
const result={source_sha256:crypto.createHash('sha256').update(fs.readFileSync(source)).digest('hex'),three_revision:T.REVISION,scope:'TEST_ONLY triangle geometry; original complete source skin contact executed',rows};
const dest=new URL('../../godot/mafiozi_walk/scripts/tests/fixtures/melee_triangle_oracle.json',import.meta.url);
fs.writeFileSync(dest,JSON.stringify(result));
console.log(JSON.stringify({rows:rows.length,hits:rows.filter(x=>x.expected).length,source_sha256:result.source_sha256,three_revision:T.REVISION}));
