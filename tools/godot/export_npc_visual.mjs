#!/usr/bin/env node
// Exact neutral NPC visual export. No gameplay/session/HP/source birth authority.
import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {registerHooks} from 'node:module';
import {fileURLToPath,pathToFileURL} from 'node:url';
const repo=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
let output=path.join(repo,'outputs/astra21_npc_visual_source/exports');
const depDir=path.join(repo,'outputs/astra21_npc_visual_source/deps');
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const digest=v=>createHash('sha256').update(v).digest('hex');
const used=new Set();
registerHooks({
 resolve(s,c,next){return next(s==='three'?pathToFileURL(path.join(vendor,'build/three.module.js')).href:s,c)},
 load(u,c,next){if(u.startsWith('file:'))used.add(fileURLToPath(u));return next(u,c)}
});
const THREE=await import(pathToFileURL(path.join(vendor,'build/three.module.js')));
if(THREE.REVISION!=='180')throw Error('Exact Three180 required');
const dependencyReceipts=JSON.parse(fs.readFileSync(path.join(depDir,'receipts.json')));
for(const r of dependencyReceipts.files){if(digest(fs.readFileSync(path.join(depDir,r.file)))!==r.sha256)throw Error('Pinned addon SHA mismatch');}
const {GLTFLoader}=await import(pathToFileURL(path.join(vendor,'addons/loaders/GLTFLoader.js')));
const {clone:cloneSkeleton}=await import(pathToFileURL(path.join(depDir,'SkeletonUtils.mjs')));
const {GLTFExporter}=await import(pathToFileURL(path.join(depDir,'GLTFExporter.mjs')));
const importSource=n=>import(pathToFileURL(path.join(repo,'assets/maps/city_rebuild_v1',n)));
const {NPC_NAMED_BOSSES}=await importSource('npc_role_catalogue.mjs');
const {npcAppearanceFromWorld}=await importSource('npc_population.mjs');
const {applyNpcAppearance,NPC_HAIRSTYLES}=await importSource('npc_appearance.mjs');
const {shareNpcCloneSkeletons}=await importSource('npc_skeleton_sharing.mjs');
const {createHeroWalker,HERO_ASSET}=await importSource('hero_walk.mjs');
const {NPC_ASSETS}=await importSource('npc_actor.mjs');
// Binary-only Node shim. No document/canvas/image decoder or fake texture path.
if(globalThis.FileReader===undefined)globalThis.FileReader=class {
 readAsArrayBuffer(blob){blob.arrayBuffer().then(result=>{this.result=result;this.onloadend?.({target:this})}).catch(error=>{this.error=error;this.onerror?.(error)});}
};
function stablePath(node,root){
 const parts=[];for(let n=node;n&&n!==root;n=n.parent)parts.push(n.name+'['+n.parent.children.indexOf(n)+']');
 return parts.reverse().join('/');
}
function material(m){
 for(const v of Object.values(m))if(v?.isTexture)throw Error('HOLD unsupported texture material');
 if(!m.isMeshStandardMaterial||m.onBeforeCompile!==THREE.Material.prototype.onBeforeCompile)throw Error('HOLD unsupported material/shader hook '+m.name);
 return {name:m.name,type:m.type,color_linear:m.color.toArray(),emissive_linear:m.emissive.toArray(),emissive_intensity:m.emissiveIntensity,roughness:m.roughness,metalness:m.metalness,opacity:m.opacity,transparent:m.transparent,side:m.side,vertex_colors:m.vertexColors,depth_write:m.depthWrite,depth_test:m.depthTest,alpha_test:m.alphaTest};
}
function snapshot(root,context){
 root.updateMatrixWorld(true);root.traverse(n=>{if(n.isSkinnedMesh)n.skeleton.update()});
 const meshes=[],bones=[];
 root.traverse(n=>{
  if(n.isBone){
   const p=new THREE.Vector3(),q=new THREE.Quaternion(),s=new THREE.Vector3();n.matrix.decompose(p,q,s);
   bones.push({name:n.name,path:stablePath(n,root),parent_bone:n.parent?.isBone?n.parent.name:null,rest_local_matrix:n.matrix.toArray(),rest_local_trs:{position:p.toArray(),quaternion:q.toArray(),scale:s.toArray()},world_matrix:n.matrixWorld.toArray()});
  }
  if(!n.isMesh)return;
  const attrs={};for(const [name,a] of Object.entries(n.geometry.attributes)){
   if(a.isInterleavedBufferAttribute)throw Error('HOLD interleaved attribute');
   attrs[name]={item_size:a.itemSize,array_type:a.array.constructor.name,normalized:a.normalized,values:Array.from(a.array)};
  }
  const verts=[],point=new THREE.Vector3();
  for(let i=0;i<n.geometry.attributes.position.count;i++){n.getVertexPosition(i,point);verts.push(...point.applyMatrix4(n.matrixWorld).toArray());}
  let attachment=null;for(let p=n.parent;p&&p!==root;p=p.parent)if(p.isBone){attachment=p.name;break;}
  meshes.push({name:n.name,path:stablePath(n,root),source_mesh_key:n.userData.npc_visual_source_mesh_key??stablePath(n,root),parent_name:n.parent?.name??'',parent_bone:attachment,local_matrix:n.matrix.toArray(),world_matrix:n.matrixWorld.toArray(),attributes:attrs,indices:n.geometry.index?Array.from(n.geometry.index.array):null,groups:n.geometry.groups.map(x=>({...x})),materials:(Array.isArray(n.material)?n.material:[n.material]).map(material),skin:n.isSkinnedMesh?{ordered_bones:n.skeleton.bones.map(b=>b.name),bone_inverses:n.skeleton.boneInverses.map(m=>m.toArray()),bind_matrix:n.bindMatrix.toArray(),bind_matrix_inverse:n.bindMatrixInverse.toArray()}:null,neutral_deformed_world_vertices:verts});
 });
 const bounds=new THREE.Box3().setFromObject(root,true);
 return {bones,meshes,bounds:{min:bounds.min.toArray(),max:bounds.max.toArray()},normalization:{target_height:context.targetHeight,source_height:context.sourceHeight,scale:context.targetHeight/context.sourceHeight,offset:context.offset.position.toArray(),scaled_matrix:context.scaled.matrix.toArray(),offset_matrix:context.offset.matrix.toArray()},material_fidelity:'HOLD',limits:['Neutral appearance/rest oracle, no wet/wounds/phone/cash/combat/AI/HP','All COLOR_0 numeric values are linear; native vertex_color_is_srgb=false','No native pixels or full actor runtime parity']};
}
function rawGlb(bytes){return JSON.parse(Buffer.from(bytes).subarray(20,20+Buffer.from(bytes).readUInt32LE(12)).toString('utf8'))}
function preserveSourceNormals(buffer,source){
 const g=rawGlb(buffer),oldJsonLength=buffer.readUInt32LE(12),binStart=20+oldJsonLength+8;
 const bin=Buffer.from(buffer.subarray(binStart));const corrections=[],seen=new Map();
 for(const node of g.nodes){
  if(node.mesh==null)continue;
  const key=node.extras?.npc_visual_source_mesh_key;
  const mesh=source.meshes.find(x=>x.source_mesh_key===key);
  if(!mesh)throw Error('Exported source mesh tag missing');
  for(const primitive of g.meshes[node.mesh].primitives){
   const ai=primitive.attributes.NORMAL;if(ai==null||!mesh.attributes.normal)throw Error('NORMAL source/export mismatch');
   const a=g.accessors[ai],v=g.bufferViews[a.bufferView],normal=mesh.attributes.normal;
   if(a.componentType!==5126||a.type!=='VEC3'||a.count*3!==normal.values.length||v.buffer!==0)throw Error('Unsupported NORMAL layout');
   if(seen.has(ai)){if(JSON.stringify(seen.get(ai))!==JSON.stringify(normal.values))throw Error('Conflicting aliased normal accessor');continue;}
   seen.set(ai,normal.values);
   const base=(v.byteOffset??0)+(a.byteOffset??0),stride=v.byteStride??12;
   const min=[Infinity,Infinity,Infinity],max=[-Infinity,-Infinity,-Infinity];
   for(let i=0;i<a.count;i++){
    const before=[],after=normal.values.slice(i*3,i*3+3);let changed=false;
    for(let c=0;c<3;c++){
     const at=base+i*stride+c*4;before.push(bin.readFloatLE(at));
     if(!Object.is(before[c],after[c]))changed=true;
     bin.writeFloatLE(after[c],at);min[c]=Math.min(min[c],after[c]);max[c]=Math.max(max[c],after[c]);
    }
    if(changed)corrections.push({source_mesh_key:key,normal_accessor:ai,vertex_index:i,source_values:after,exporter_values:before});
   }
   if(a.min)a.min=min;if(a.max)a.max=max;
  }
 }
 // The source actor shares one skeleton. Exporter emits an identical skin per
 // SkinnedMesh; merge only byte-exact palettes, roots and inverse bind matrices.
 const skins=[],skinKeys=[],skinRemap=[],skinDeduplication=[];
 for(const [index,skin] of (g.skins??[]).entries()){
  const a=g.accessors[skin.inverseBindMatrices],v=g.bufferViews[a.bufferView];
  if(a.componentType!==5126||a.type!=='MAT4'||a.count!==skin.joints.length||a.sparse||v.buffer!==0)throw Error('Unsupported skin bind layout');
  const start=(v.byteOffset??0)+(a.byteOffset??0),stride=v.byteStride??64;
  const binds=Buffer.concat(Array.from({length:a.count},(_,i)=>bin.subarray(start+i*stride,start+i*stride+64)));
  const rest={...skin};delete rest.inverseBindMatrices;
  const key=JSON.stringify(rest)+'|'+binds.toString('hex');
  let target=skinKeys.indexOf(key);
  if(target<0){target=skins.length;skins.push(skin);skinKeys.push(key);}
  skinRemap.push(target);
  skinDeduplication.push({original_skin:index,target_skin:target,joints:[...skin.joints],skeleton:skin.skeleton,inverse_bind_sha256:digest(binds),byte_exact_equivalent:true});
 }
 for(const node of g.nodes)if(node.skin!=null)node.skin=skinRemap[node.skin];
 if(g.skins)g.skins=skins;
 const json=Buffer.from(JSON.stringify(g)),jp=Buffer.alloc((4-json.length%4)%4,32),j=Buffer.concat([json,jp]);
 const header=Buffer.alloc(20);header.write('glTF');header.writeUInt32LE(2,4);header.writeUInt32LE(20+j.length+8+bin.length,8);header.writeUInt32LE(j.length,12);header.writeUInt32LE(0x4e4f534a,16);
 const bh=Buffer.alloc(8);bh.writeUInt32LE(bin.length,0);bh.writeUInt32LE(0x004e4942,4);
 return {bytes:Buffer.concat([header,j,bh,bin]),corrections,skinDeduplication};
}
function compareRoundtrip(before,after){
 const a=before.meshes,b=after.meshes;
 if(a.length!==b.length)throw Error('Roundtrip mesh count changed');
 let maxVertex=0,maxColor=0,maxAttribute=0,maxUnusedNormalError=0,maxNormalError=0;let vertices=0,colorValues=0;const attributeErrors={},unusedNormalChanges=[];
 const consumed=new Set();
 for(const source of a){
  const target=b.find((x,i)=>x.source_mesh_key===source.source_mesh_key&&!consumed.has(i));
  if(!target)throw Error('Roundtrip missing mesh '+source.name);
  consumed.add(b.indexOf(target));
  if(source.parent_bone!==target.parent_bone)throw Error('Attachment bone changed '+source.name);
  if(source.neutral_deformed_world_vertices.length!==target.neutral_deformed_world_vertices.length)throw Error('Vertex count changed');
  for(let i=0;i<source.neutral_deformed_world_vertices.length;i++){maxVertex=Math.max(maxVertex,Math.abs(source.neutral_deformed_world_vertices[i]-target.neutral_deformed_world_vertices[i]));}
  vertices+=source.neutral_deformed_world_vertices.length/3;
  const usedVertices=new Set(source.indices??Array.from({length:source.attributes.position.values.length/3},(_,i)=>i));
  const changedUnusedNormals=new Set();
  for(const key of Object.keys(source.attributes)){
   const x=source.attributes[key],y=target.attributes[key];
   if(!y||x.values.length!==y.values.length)throw Error('Missing roundtrip attribute '+key);
   for(let i=0;i<x.values.length;i++){
    const err=Math.abs(x.values[i]-y.values[i]);
    if(key==='normal'){
     maxNormalError=Math.max(maxNormalError,err);
     if(!usedVertices.has(Math.floor(i/x.item_size))){maxUnusedNormalError=Math.max(maxUnusedNormalError,err);if(err>0)changedUnusedNormals.add(Math.floor(i/x.item_size));}
    }
    maxAttribute=Math.max(maxAttribute,err);
    if(err>0.00001&&!attributeErrors[key])attributeErrors[key]={mesh:source.name,index:i,source:x.values[i],roundtrip:y.values[i]};
    if(key==='color'){maxColor=Math.max(maxColor,err);colorValues++;}
   }
  }
  if(changedUnusedNormals.size)unusedNormalChanges.push({mesh:source.name,vertices:[...changedUnusedNormals],reason:'Pinned GLTFExporter normalizes zero normals on orphan vertices not referenced by ANY index; all triangle-used attributes remain checked'});
  if(JSON.stringify(source.indices)!==JSON.stringify(target.indices))throw Error('Triangle index changed');
  if(source.skin){
   if(!target.skin||JSON.stringify(source.skin.ordered_bones)!==JSON.stringify(target.skin.ordered_bones))throw Error('Ordered skin palette changed');
  }
 }
 if(maxVertex>0.00005||maxAttribute>0.00001||maxColor>0.000001||maxNormalError!==0)throw Error('Roundtrip attribute/skin deformation mismatch '+JSON.stringify({maxVertex,maxAttribute,maxColor,maxNormalError,attributeErrors}));
 return {pass:true,vertices,color_values:colorValues,max_world_vertex_component_error_m:maxVertex,max_triangle_used_attribute_error:maxAttribute,max_color_error:maxColor,unused_normal_changes:unusedNormalChanges,max_unused_normal_component_error:maxUnusedNormalError,full_normal_buffer_equality:maxNormalError===0,max_full_normal_component_error:maxNormalError};
}
const argv=process.argv.slice(2),checkOnly=argv.includes('--check');
const limitAt=argv.indexOf('--limit'),limit=limitAt>=0?Number(argv[limitAt+1]):19;
if(!Number.isInteger(limit)||limit<1||limit>19)throw Error('Limit must be1..19');
const sourceAt=argv.indexOf('--source-input');
if(argv.some((x,i)=>!['--catalogue','--check','--limit',String(limit),'--source-input'].includes(x)&&!(sourceAt>=0&&i===sourceAt+1)))throw Error('Unknown argument');
if(sourceAt>=0&&(argv.includes('--catalogue')||limitAt>=0||typeof argv[sourceAt+1]!=='string'))throw Error('Source input mode conflicts or missing path');
const sourceModuleSHA=digest(fs.readFileSync(path.join(repo,'assets/maps/city_rebuild_v1/npc_population.mjs')));
const appearanceModuleSHA=digest(fs.readFileSync(path.join(repo,'assets/maps/city_rebuild_v1/npc_appearance.mjs')));
let sourceReceipt=null,requests=sourceAt>=0?[]:NPC_NAMED_BOSSES.slice(0,limit).map(row=>({row,descriptor:npcAppearanceFromWorld({id:row.bridgeId,look:row.look,role:row.displayRole}),kind:'catalogue_fixture',fixture:true,provenance:{label:row.source??'NPC_NAMED_BOSSES',test_only:false}}));
function validateDescriptor(d,id){
 if(!d||Array.isArray(d)||d.id!==id)throw Error('Descriptor bridge ID mismatch');
 const strings=['id','sex','role','skin','hairColor','hairstyle','outfit','shirt','hat'];
 for(const key of strings)if(typeof d[key]!=='string'||!d[key].length||d[key].length>256)throw Error('Missing/invalid complete descriptor field '+key);
 for(const key of ['height','build','browStyle'])if(typeof d[key]!=='number'||!Number.isFinite(d[key]))throw Error('Missing/invalid descriptor numeric '+key);
 if(!['male','female'].includes(d.sex)||!Number.isInteger(d.browStyle)||d.browStyle<0||d.browStyle>7)throw Error('Descriptor sex/brow invalid');
 // Preserve unknown descriptor fields verbatim; known geometry/color controls
 // must be finite source values. JSON input is already size-bounded.
 for(const key of ['belly','shoulderWidth','faceWidth','jawWidth','cheekFullness'])if(d[key]!=null&&(typeof d[key]!=='number'||!Number.isFinite(d[key])||Math.abs(d[key])>100))throw Error('Invalid source numeric '+key);
 for(const key of ['skin','hairColor','outfit','shirt','accent','trousers','outfitColor'])if(d[key]!=null&&!/^#[0-9a-fA-F]{6}$/.test(d[key]))throw Error('Unsupported exact source color '+key);
 if(d.height<1.65||d.height>2.05||d.build<.93||d.build>1.07||!NPC_HAIRSTYLES.includes(d.hairstyle))throw Error('Descriptor is not fully source-resolved');
}
if(sourceAt>=0){
 const inputPath=path.resolve(argv[sourceAt+1]),stat=fs.statSync(inputPath);
 if(!stat.isFile()||stat.size>1048576)throw Error('Source input must be file <=1MiB');
 const inputBytes=fs.readFileSync(inputPath),input=JSON.parse(inputBytes);
 if(input.schema!=='mafiozi.npc-visual-source/v1'||input.source_module_sha256!==sourceModuleSHA||input.appearance_module_sha256!==appearanceModuleSHA)throw Error('Source schema/module SHA mismatch');
 if(!Array.isArray(input.entries)||input.entries.length<1||input.entries.length>64)throw Error('Source entries must be1..64');
 const ids=new Set();
 sourceReceipt={input_file_sha256:digest(inputBytes),input_bytes:inputBytes.length,source_module_sha256:sourceModuleSHA,appearance_module_sha256:appearanceModuleSHA,tests_only:input.entries.some(e=>e.kind==='synthetic_fixture'||e.provenance?.test_only===true),authority:'NONE: self-declared provenance is not authenticated live capture or source birth'};
 output=path.join(repo,'outputs/astra21_npc_visual_source',sourceReceipt.tests_only?'exports_source_tests':'exports_source',sourceReceipt.input_file_sha256);
 requests=input.entries.map(e=>{
  const id=e.bridge_id;
  if(typeof id!=='string'||!id.length||id.length>256||ids.has(id))throw Error('Invalid/duplicate bridge ID');ids.add(id);
  if(!['catalogue_fixture','captured_appearance','synthetic_fixture'].includes(e.kind)||typeof e.fixture!=='boolean'||e.fixture!==(e.kind!=='captured_appearance'))throw Error('Kind/fixture flag mismatch');
  if(!e.provenance||typeof e.provenance.label!=='string'||!e.provenance.label.length||e.provenance.label.length>512||typeof e.provenance.test_only!=='boolean')throw Error('Explicit provenance required');
  if(e.kind==='synthetic_fixture'&&!e.provenance.test_only||e.kind==='captured_appearance'&&e.provenance.test_only)throw Error('Synthetic/production provenance inconsistent');
  if(e.authenticated===true||e.live_spawn===true||e.source_birth_authorized===true)throw Error('Authority claims unsupported');
  if((e.source_row!=null)===(e.resolved_descriptor!=null))throw Error('Exactly one source_row/resolved_descriptor required');
  if(e.source_row&&(typeof e.source_row!=='object'||Array.isArray(e.source_row)||e.source_row.id!==id))throw Error('Source row bridge ID mismatch');
  const descriptor=e.source_row?npcAppearanceFromWorld(e.source_row):e.resolved_descriptor;
  validateDescriptor(descriptor,id);
  const text=JSON.stringify(descriptor);
  if(e.descriptor_json!=null&&e.descriptor_json!==text||e.descriptor_sha256!=null&&e.descriptor_sha256!==digest(text))throw Error('Descriptor JSON/SHA mismatch');
  if(typeof e.canonical_source_sha256!=='string')throw Error('Canonical source SHA required');
  return {row:{bridgeId:id,name:e.label??id,source:e.provenance.label},descriptor,kind:e.kind,fixture:e.fixture,provenance:e.provenance,input_kind:e.source_row?'source_row':'resolved_descriptor',source_row:e.source_row??null,expected_canonical_sha:e.canonical_source_sha256};
 });
}
const templates={};const baseReceipts={};
for(const [sex,asset] of Object.entries(NPC_ASSETS)){
 const filename=fileURLToPath(asset.url),bytes=fs.readFileSync(filename);used.add(filename);
 if(bytes.length!==asset.bytes||digest(bytes)!==asset.sha256)throw Error('Canonical source binding mismatch '+sex);
 const gltf=await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'');
 templates[sex]=gltf.scene;
 baseReceipts[sex]={bytes:bytes.length,sha256:digest(bytes),path:path.relative(repo,filename).replaceAll('\\','/'),textures:rawGlb(bytes).textures?.length??0,animations:gltf.animations.length};
 if(baseReceipts[sex].textures||gltf.animations.length)throw Error('HOLD source texture/animation binding changed');
}
function templateDigest(root){const data=[];root.updateMatrixWorld(true);root.traverse(n=>{if(n.isMesh)data.push([n.name,...Object.entries(n.geometry.attributes).map(([key,a])=>[key,digest(Buffer.from(a.array.buffer,a.array.byteOffset,a.array.byteLength))]),material(n.material),n.matrix.toArray()]);if(n.isBone)data.push([n.name,n.matrix.toArray()])});return digest(JSON.stringify(data));}
const templateBefore=Object.fromEntries(Object.entries(templates).map(([sex,t])=>[sex,templateDigest(t)]));
const entries=[];
if(!checkOnly)fs.mkdirSync(output,{recursive:true});
for(const request of requests){
 const {row,descriptor}=request,descriptorJson=JSON.stringify(descriptor);
 if(request.expected_canonical_sha&&request.expected_canonical_sha!==baseReceipts[descriptor.sex]?.sha256)throw Error('Canonical source SHA mismatch');
 const clone=cloneSkeleton(templates[descriptor.sex]);shareNpcCloneSkeletons({THREE,root:clone});
 const appearance=applyNpcAppearance({THREE,scene:clone,descriptor,cloneTextures:true});
 const walker=createHeroWalker({THREE,scene:clone,targetHeight:descriptor.height});
 walker.object.name='NPC_'+row.bridgeId;walker.object.userData.npcId=row.bridgeId;
 const context=walker.artistContext(),source=snapshot(walker.object,context);
 walker.object.traverse(n=>{if(n.isMesh)n.userData.npc_visual_source_mesh_key=stablePath(n,walker.object)});
 const exporter=new GLTFExporter();
 const exported=Buffer.from(await exporter.parseAsync(walker.object,{binary:true,trs:false,onlyVisible:true,animations:[],includeCustomExtensions:false}));
 const preserved=preserveSourceNormals(exported,source),bytes=preserved.bytes;
 const assetHash=digest(bytes),g=rawGlb(bytes);
 if(g.animations?.length)throw Error('Unexpected exported clips');
 const roundtrip=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 const parsed=snapshot(roundtrip,{...context});
 const roundtripCheck=compareRoundtrip(source,parsed);
 const oracle={schema:'mafiozi.npc-visual-oracle/v1',bridge_id:row.bridgeId,descriptor_json:descriptorJson,descriptor_sha256:digest(descriptorJson),canonical_source_sha256:baseReceipts[descriptor.sex].sha256,asset_sha256:assetHash,appearance_application_count:1,normalization_application_count:1,animation_count:0,source,roundtrip:roundtripCheck,exported_gltf:{nodes:g.nodes.length,meshes:g.meshes.length,skins:g.skins?.length??0,extensions_used:g.extensionsUsed??[],skin_node_indices:g.nodes.flatMap((n,i)=>n.skin!=null?[{node_index:i,name:n.name,skin_index:n.skin}]:[])}};
 oracle.normal_corrections=preserved.corrections;
 oracle.skin_deduplication=preserved.skinDeduplication;
 oracle.normal_degenerate_fidelity='HOLD';
 oracle.normal_correction_policy='Restore exact source Float32 NORMAL accessor values after pinned exporter auto-normalization; preserve source topology, including zero normals. No glTF unit-normal conformance or native degenerate pixel claim.';
 oracle.bone_parent_map=Object.fromEntries(source.bones.map(b=>[b.name,b.parent_bone]));
 oracle.color_ranges=source.meshes.filter(m=>m.attributes.color).map(m=>{const v=m.attributes.color.values;return {source_mesh_key:m.source_mesh_key,min:Math.min(...v),max:Math.max(...v),outside_unit_values:v.filter(x=>x<0||x>1).length,linear:true}});
 oracle.color_hdr_fidelity=oracle.color_ranges.some(x=>x.outside_unit_values>0)?'HOLD':'not_present';
 if(sourceReceipt)oracle.source_input={...sourceReceipt,kind:request.kind,fixture:request.fixture,provenance:request.provenance,input_kind:request.input_kind,source_row:request.source_row};
 const oracleBytes=Buffer.from(JSON.stringify(oracle)+'\n'),oracleHash=digest(oracleBytes);
 const assetFile=assetHash+'.glb',oracleFile=oracleHash+'.json';
 for(const [name,data] of [[assetFile,bytes],[oracleFile,oracleBytes]]){
  const filename=path.join(output,name);
  if(checkOnly){if(!fs.existsSync(filename)||!fs.readFileSync(filename).equals(data))throw Error('Reproduction mismatch '+name);}
  else fs.writeFileSync(filename,data);
 }
 const entry={kind:request.kind,catalogue_only:request.kind==='catalogue_fixture',not_live_spawn:true,bridge_id:row.bridgeId,label:row.name,source_provenance:row.source,descriptor,descriptor_json:descriptorJson,descriptor_sha256:digest(descriptorJson),asset_file:assetFile,asset_sha256:assetHash,asset_bytes:bytes.length,canonical_source_sha256:baseReceipts[descriptor.sex].sha256,oracle_file:oracleFile,oracle_sha256:oracleHash,oracle_bytes:oracleBytes.length,appearance_application_count:1,normalization_application_count:1,animation_count:0,material_fidelity:'HOLD',normalization:source.normalization,bounds:source.bounds,mesh_count:source.meshes.length,bone_count:source.bones.length,hairstyle:descriptor.hairstyle,roundtrip:roundtripCheck,limits:source.limits};
 if(sourceReceipt)entry.source_input={...sourceReceipt,fixture:request.fixture,provenance:request.provenance,input_kind:request.input_kind};
 entry.normal_degenerate_fidelity='HOLD';entry.normal_corrections=preserved.corrections.length;
 entry.bone_parent_map=oracle.bone_parent_map;
 entry.color_ranges=oracle.color_ranges;entry.color_hdr_fidelity=oracle.color_hdr_fidelity;
 entries.push(entry);
 appearance.dispose();walker.dispose();
 for(const [sex,t] of Object.entries(templates))if(templateDigest(t)!==templateBefore[sex])throw Error('Source template mutated by appearance/export');
 console.log(JSON.stringify({bridge_id:row.bridgeId,asset_file:assetFile,oracle_file:oracleFile,meshes:source.meshes.length,vertices:roundtripCheck.vertices,roundtrip:roundtripCheck.pass,check:checkOnly}));
}
used.add(fileURLToPath(import.meta.url));
const manifest={schema:'mafiozi.npc-visual/v1',scope:'neutral catalogue appearance fixtures only',material_fidelity:'HOLD',node_version:process.version,three_revision:THREE.REVISION,export_options:{binary:true,trs:false,onlyVisible:true,animations:[],includeCustomExtensions:false},canonical_sources:baseReceipts,dependencies:[...used].sort().map(filename=>({path:path.relative(repo,filename).replaceAll('\\','/'),bytes:fs.statSync(filename).size,sha256:digest(fs.readFileSync(filename))})),addon_receipts:dependencyReceipts,entries,limits:['Catalogue-only fixtures, not live resident/merchant roster or source session capture','No spawn/authority/HP/AI/commerce/gait/state serialization','Dry neutral StandardMaterial GLB; native material/pixel fidelity HOLD','Future arbitrary source IDs need their own true descriptor assets or native appearance adapter','No GPU/native gameplay/performance acceptance']};
if(sourceReceipt){manifest.scope=sourceReceipt.tests_only?'tests_only':'neutral appearance from explicitly supplied source row/resolved descriptor';manifest.tests_only=sourceReceipt.tests_only;manifest.source_input=sourceReceipt;manifest.limits[0]='Input provenance is self-declared and does not authenticate live/session/roster/source birth';manifest.limits[3]='Exact descriptor-specific asset, no source birth/roster authority granted';}
if(!checkOnly)fs.writeFileSync(path.join(output,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
else{const existing=JSON.parse(fs.readFileSync(path.join(output,'manifest.json')));if(JSON.stringify(existing)!==JSON.stringify(manifest))throw Error('Manifest/source dependency SHA reproduction mismatch');}
console.log(JSON.stringify({status:'PASS',entries:entries.length,hairstyles:[...new Set(entries.map(x=>x.hairstyle))],source_template_unchanged:true,check:checkOnly}));
