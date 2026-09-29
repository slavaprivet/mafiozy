// TEST_ONLY actors/meshes/walls. Executes the unchanged original complete source.
import fs from 'node:fs';
import crypto from 'node:crypto';
import {pathToFileURL} from 'node:url';
import {createNpcMeleeContact} from '../../assets/maps/city_rebuild_v1/npc_melee_contact.mjs';
const THREE=await import(pathToFileURL(process.argv[2]??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js'));
const cases=[];
const baseTriangle=[[-.5,.5,0],[.5,.5,0],[0,1.5,0]];
const mesh=(name,options={})=>({name,triangles:[baseTriangle],...options});
const actor=(id,parts=[mesh('surface')],options={})=>({id,parts,...options});
const defaultInput={previous:[0,1,1],current:[0,1,-1],attackType:'punch'};
const add=(name,actors=[actor('TEST_ONLY_A')],input={},walls=[])=>cases.push({name,actors,input:{...defaultInput,...input},walls});
add('ordinary');add('reverse-normal',undefined,{previous:[0,1,-1],current:[0,1,1]});
add('actor-tie',[actor('TEST_ONLY_first'),actor('TEST_ONLY_second')]);
add('source-actor-improvements',[actor('TEST_ONLY_far',[mesh('far',{translation:[0,0,-.5]})]),actor('TEST_ONLY_near',[mesh('near',{translation:[0,0,.25]})])]);
add('mesh-tie',[actor('TEST_ONLY_A',[mesh('first'),mesh('second')])]);
add('face-tie',[actor('TEST_ONLY_A',[mesh('duplicate',{triangles:[baseTriangle,baseTriangle]})])]);
add('limb-tie',undefined,{contacts:[{previous:[0,1,1],current:[0,1,-1]},{previous:[0,1,-1],current:[0,1,1]}]});
add('invisible-actor-ancestor',[actor('TEST_ONLY_hidden',undefined,{ancestorVisible:false}),actor('TEST_ONLY_visible')]);
add('invisible-mesh-ancestor',[actor('TEST_ONLY_A',[mesh('hidden',{ancestorVisible:false}),mesh('visible')])]);
add('excluded-actor',[actor('TEST_ONLY_excluded'),actor('TEST_ONLY_kept')],{excludeId:'TEST_ONLY_excluded'});
add('strict-id-type',[actor(7)],{excludeId:'7'});add('strict-numeric-exclude',[actor(7)],{excludeId:7});
add('no-near-actor',[actor('TEST_ONLY_far',undefined,{position:[100,0,0]})]);add('empty-actors',[]);
add('exact-near-boundary',[actor('TEST_ONLY_near')],{previous:[0,4,0],current:[0,4,0],radius:.5});
add('outside-near-boundary',[actor('TEST_ONLY_near')],{previous:[0,4.01,0],current:[0,4.01,0],radius:.5});
add('head-half',[actor('TEST_ONLY_A',[mesh('head',{head:[.5,.5,.5]})])]);
add('body-below-half',[actor('TEST_ONLY_A',[mesh('body',{head:[.49,.49,.49]})])]);
add('head-interpolated',[actor('TEST_ONLY_A',[mesh('blend',{head:[0,0,1]})])]);
add('default-punch-radius',undefined,{previous:[0,1,.12],current:[0,1,.12]});
add('default-FOOT-radius',undefined,{previous:[0,1,.12],current:[0,1,.12],attackType:'FOOT_STRIKE'});
add('input-radius-precedence',undefined,{previous:[0,1,.12],current:[0,1,.12],radius:.13});
add('contact-radius-precedence',undefined,{attackType:'kick',contacts:[{previous:[0,1,.12],current:[0,1,.12],radius:.1}]});
add('contacts-from-to-alias',undefined,{contacts:[{from:[0,1,1],to:[0,1,-1]}]});
const z=Math.fround(.1);
add('native-epsilon-superset-must-be-rejected',undefined,{previous:[0,1,z],current:[.1,1,z],radius:z-2e-10});
add('source-AABB-inclusive-touch',undefined,{previous:[0,1,z],current:[.1,1,z],radius:z});
const side=(x,z=0)=>mesh(`side_${x}`,{triangles:[[[-.15,.7,0],[.15,.7,0],[0,1.3,0]]],translation:[x,0,z]});
add('occluded-nearest-then-farther',[actor('TEST_ONLY_A',[side(-.4,.25),side(.4)])],{contacts:[{previous:[-.4,1,1],current:[-.4,1,-1]},{previous:[.4,1,1],current:[.4,1,-1]}]},[{position:[-.4,1,.6],size:[.2,1,.03]}]);
add('origin-occlusion-after-limb-clear',undefined,{previous:[0,1,.2],current:[0,1,-.2],origin:[0,1,1]},[{position:[0,1,.5],size:[1,1,.02]}]);
add('invisible-wall-ancestor',undefined,{origin:[0,1,1]},[{position:[0,1,.5],size:[1,1,.02],ancestorVisible:false}]);
add('invisible-nearest-visible-farther-wall',undefined,{},[{position:[0,1,.7],size:[1,1,.02],visible:false},{position:[0,1,.5],size:[1,1,.02]}]);
add('wall-within-source-epsilon-clear',undefined,{},[{position:[0,1,5e-6],plane:true}]);
add('wall-beyond-source-epsilon-block',undefined,{},[{position:[0,1,2e-5],plane:true}]);
add('zero-limb-ray-distance',undefined,{previous:[0,1,0],current:[0,1,0],origin:[0,1,1]},[{position:[0,1,.5],size:[1,1,.02]}]);
add('inactive',undefined,{active:false});add('zero-sweeps',undefined,{contacts:[]});
add('too-many-sweeps',undefined,{contacts:Array.from({length:5},()=>({previous:[0,1,1],current:[0,1,-1]}))});
const visible=node=>{for(let n=node;n;n=n.parent)if(!n.visible)return false;return true;};
const vec=a=>new THREE.Vector3(...a);
const rows=[];
for(const specification of cases){
 const world=new THREE.Scene(),records=[],walls=[],rays=[],visited=[];
 for(const description of specification.actors){
  const parent=new THREE.Group();parent.visible=description.ancestorVisible!==false;world.add(parent);
  const object=new THREE.Group();object.position.fromArray(description.position??[0,0,0]);object.visible=description.visible!==false;parent.add(object);
  const parts=[];
  for(const part of description.parts){
   const geometry=new THREE.BufferGeometry(),positions=part.triangles.flat(2),count=positions.length/3;
   geometry.setAttribute('position',new THREE.Float32BufferAttribute(positions,3));geometry.setIndex(Array.from({length:count},(_,i)=>i));
   const head=Array.from({length:count},(_,i)=>part.head?.[i%3]??1);
   geometry.setAttribute('skinIndex',new THREE.Uint16BufferAttribute(Array.from({length:count},()=>[0,1,0,1]).flat(),4));
   geometry.setAttribute('skinWeight',new THREE.Float32BufferAttribute(head.flatMap(h=>[h,1-h,0,0]),4));
   const ancestor=new THREE.Group();ancestor.visible=part.ancestorVisible!==false;object.add(ancestor);
   const surface=new THREE.SkinnedMesh(geometry,new THREE.MeshBasicMaterial({side:THREE.DoubleSide}));surface.name=part.name;surface.visible=part.visible!==false;ancestor.add(surface);
   const headBone=new THREE.Bone(),bodyBone=new THREE.Bone();headBone.name='head';bodyBone.name='chest';surface.add(headBone,bodyBone);surface.bind(new THREE.Skeleton([headBone,bodyBone]));
   surface.position.fromArray(part.translation??[0,0,0]);parts.push(surface);
   const original=surface.getVertexPosition.bind(surface);surface.getVertexPosition=(...args)=>{const key=[description.id,part.name];if(!visited.some(v=>v[0]===key[0]&&v[1]===key[1]))visited.push(key);return original(...args);};
  }
  records.push({id:description.id,object,parts});
 }
 for(const item of specification.walls){
  const parent=new THREE.Group();parent.visible=item.ancestorVisible!==false;world.add(parent);
  const wall=new THREE.Mesh(item.plane?new THREE.PlaneGeometry(1,1):new THREE.BoxGeometry(...item.size),new THREE.MeshBasicMaterial({side:THREE.DoubleSide}));wall.position.fromArray(item.position);wall.visible=item.visible!==false;parent.add(wall);walls.push(wall);
 }
 world.updateMatrixWorld(true);
 class RecordedRaycaster extends THREE.Raycaster{intersectObjects(objects,recursive,target){const hits=super.intersectObjects(objects,recursive,target);const first=hits.find(h=>visible(h.object));rays.push({from:this.ray.origin.toArray(),to:this.ray.origin.clone().addScaledVector(this.ray.direction,this.far).toArray(),distance:first?.distance??null});return hits;}}
 const contact=createNpcMeleeContact({THREE:{...THREE,Raycaster:RecordedRaycaster},getActors:()=>records,obstacles:()=>walls});
 const input={...specification.input};for(const key of ['previous','current','from','to','origin'])if(Array.isArray(input[key]))input[key]=vec(input[key]);
 if(input.contacts)input.contacts=input.contacts.map(row=>Object.fromEntries(Object.entries(row).map(([k,v])=>[k,Array.isArray(v)?vec(v):v])));
 const result=contact(input);const sourceVisited=visited.slice();
 const actors=records.map(record=>({actor_id:record.id,root_position:record.object.getWorldPosition(new THREE.Vector3()).toArray(),visible:visible(record.object),parts:record.parts.map((surface,order)=>({mesh_id:surface.name,mesh_order:order,visible:visible(surface),world_vertices:Array.from({length:surface.geometry.attributes.position.count},(_,i)=>surface.getVertexPosition(i,new THREE.Vector3()).applyMatrix4(surface.matrixWorld).toArray()),indices:Array.from(surface.geometry.index.array),head_slot_weights:Array.from(surface.geometry.attributes.skinWeight.array,(weight,i)=>i%4===0||i%4===2?weight:0)}))}));
 rows.push({name:specification.name,input:specification.input,actors,blocker_count:walls.length,rays,visited:sourceVisited,expected:result?{actor_id:result.npcId,mesh_id:result.anchor.meshPath.at(-1).name,face:result.anchor.indices,weights:result.anchor.weights,normal_side:result.anchor.normalSide,point:Object.values(result.point),normal:Object.values(result.normal),zone:result.zone,distance:result.distance,attack_type:result.attackType}:null});
 world.traverse(n=>{n.geometry?.dispose();n.material?.dispose();});
}
const source=new URL('../../assets/maps/city_rebuild_v1/npc_melee_contact.mjs',import.meta.url);
const anchorSource=new URL('../../assets/maps/city_rebuild_v1/npc_contact_anchor.mjs',import.meta.url);
const sourceHash=path=>crypto.createHash('sha256').update(fs.readFileSync(path,'utf8').replace(/\r\n/g,'\n'),'utf8').digest('hex');
const result={scope:'TEST_ONLY real Three SkinnedMesh/obstacle fixtures; unchanged complete source executes selection/occlusion',source_hash_normalization:'crlf_to_lf',source_sha256:sourceHash(source),anchor_source_sha256:sourceHash(anchorSource),three_revision:THREE.REVISION,rows};
fs.writeFileSync(new URL('../../godot/mafiozi_walk/scripts/tests/fixtures/melee_contact_selection_oracle.json',import.meta.url),JSON.stringify(result));
console.log(JSON.stringify({rows:rows.length,hits:rows.filter(r=>r.expected).length,source_sha256:result.source_sha256}));
