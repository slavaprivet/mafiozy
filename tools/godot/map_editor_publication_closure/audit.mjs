import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {SCHEMA,sha,pathFor,verifyClosure} from './closure.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const locations=[['catalog','godot/mafiozi_walk/data/map_editor/catalog.json'],['ground-topology','assets/maps/city_rebuild_v1/topology_for_placement.json'],['ground-palette','godot/mafiozi_walk/data/block.json'],['procedural','outputs/map_editor_procedural_source/manifest.json'],['transport','outputs/map_editor_transport_decor_source/manifest.json'],['landmarks','outputs/map_editor_protected_landmarks_source/manifest.json'],['landmark-textures','outputs/map_editor_landmark_texture_closure/manifest.json'],['rail-caption-capture','outputs/map_editor_station_canvas_capture/receipt.json']];
export function inventory(){
 const blobs=new Map(),localReaders=new Map(),families=[],admittedSources=new Set();
 const add=(file,kind,expectedSHA,expectedBytes)=>{const raw=fs.readFileSync(file),hash=sha(raw);if(expectedSHA)assert.equal(hash,expectedSHA);if(expectedBytes!==undefined)assert.equal(raw.length,expectedBytes);const portable=pathFor(kind,hash);if(blobs.has(hash))assert.equal(blobs.get(hash).kind,kind);else{blobs.set(hash,{sha256:hash,bytes:raw.length,kind,path:portable});localReaders.set(portable,file);}return {hash,raw};};
 for(const[id,relative]of locations){const file=path.join(root,relative),{hash,raw}=add(file,'json');admittedSources.add(hash);const manifest=JSON.parse(raw);let semanticKeys=[];
  if(id==='catalog'){semanticKeys=manifest.objects.map(o=>o.key);for(const resource of manifest.resources){const relative=resource.sourcePaths[0];assert(!path.isAbsolute(relative)&&!relative.includes('..'));add(path.join(root,relative),'glb',resource.sha256,resource.bytes);}}
  if(id==='procedural')semanticKeys=Object.keys(manifest.objectIndex);
  if(id==='transport'){semanticKeys=manifest.semanticObjects.map(o=>o.key);const train=manifest.railway.trainAsset;add(path.join(root,train.path),'glb',train.sha256,train.bytes);}
  if(id==='landmarks')semanticKeys=manifest.records.map(o=>o.key);
  if(id==='landmark-textures')semanticKeys=manifest.textures.map(o=>o.id);
  if(id==='rail-caption-capture'){semanticKeys=manifest.captures.map(o=>o.texture_id);for(const capture of manifest.captures)add(path.join(path.dirname(file),capture.rgba_file),'rgba8',capture.rgba_sha256);}
  for(const buffer of manifest.buffers??[]){assert.equal(buffer.file,`buffers/${buffer.sha256}.bin`);add(path.join(path.dirname(file),buffer.file),'buffer',buffer.sha256,buffer.bytes);}
  families.push({id,manifest_sha256:hash,semanticKeys:semanticKeys.sort()});
 }
 const closure={schema:SCHEMA,engineContract:'godot-native-map-importer/closure-v1',mapBundle_sha256:null,families,blobs:[...blobs.values()].sort((a,b)=>a.path.localeCompare(b.path))};
 const readBlob=portable=>{if(!localReaders.has(portable))throw Error('Not an inventoried blob');return fs.readFileSync(localReaders.get(portable));};
 const trusted={sourceManifests:admittedSources,familyManifests:new Map(families.map(f=>[f.id,f.manifest_sha256])),runtimeGates:new Set(),textureCaptures:new Map()};
 return {closure,readBlob,trusted};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const {closure,readBlob,trusted}=inventory(),report=verifyClosure(closure,readBlob,trusted,{requireReady:false});assert(report.integrity,JSON.stringify(report.errors));assert(!verifyClosure(closure,readBlob,trusted).ok,'Actual HOLD dependencies cannot be ready');
 const output=path.join(root,'outputs/map_editor_publication_closure');fs.mkdirSync(output,{recursive:true});fs.writeFileSync(path.join(output,'closure.json'),JSON.stringify(closure,null,2)+'\n');fs.writeFileSync(path.join(output,'AUDIT_REPORT.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({integrity:report.integrity,ready:report.ready,checks:report.checks,blobCount:report.portableBlobCount,bytes:report.portableBytes,holds:report.holds.length,errors:report.errors}));
}
