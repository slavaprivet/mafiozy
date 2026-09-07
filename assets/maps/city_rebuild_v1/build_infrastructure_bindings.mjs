import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const here=path.dirname(fileURLToPath(import.meta.url)),root=path.resolve(here,'../../..');
const manifestPath=process.argv[2];if(!manifestPath)throw Error('Pass industry latest manifest');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const mb=fs.readFileSync(manifestPath),manifest=JSON.parse(mb),catalog=JSON.parse(fs.readFileSync(path.join(here,'decor_catalog.v1.json')));
function verified(g){const b=fs.readFileSync(g.absolutePath);if(b.length!==g.bytes||hash(b)!==g.sha256.toLowerCase())throw Error('Hash mismatch '+g.absolutePath);return b;}
function json(b){if(b.readUInt32LE(0)!==0x46546c67||b.readUInt32LE(4)!==2)throw Error('Not GLB');return JSON.parse(b.subarray(20,20+b.readUInt32LE(12)).toString());}
const roads=manifest.assets.find(x=>x.assetId==='smooth_clay_road_rail_crossing_kit_v1'),roadSource=roads.glbs[0],rj=json(verified(roadSource));
const materialDescriptors=rj.materials.filter(x=>/^MAT_CLAY_(ASPHALT_|CURB|WARM_CONCRETE|MARKING_)/.test(x.name)).map(x=>({id:x.name,sourceAssetId:roads.assetId,colorSpace:'linear_srgb',baseColorFactor:x.pbrMetallicRoughness.baseColorFactor,metallicFactor:x.pbrMetallicRoughness.metallicFactor,roughnessFactor:x.pbrMetallicRoughness.roughnessFactor,doubleSided:x.doubleSided}));
const street=manifest.assets.find(x=>x.assetId==='street_infrastructure_clay_kit_v1'),lampAdapters={},findings=[];
for(const binding of street.glbs.filter(x=>x.coverage==='streetlight')){
 const b=verified(binding),g=json(b),asset=catalog.entries.find(x=>x.assetId===binding.assetId);
 if(!asset||asset.lods[0].sha256!==hash(b))throw Error('Civic/industry source drift');
 const meshes=g.nodes.filter(n=>n.mesh!==undefined),base=meshes.find(n=>/^Lamp_Base_/.test(n.name));if(!base)throw Error('Missing lamp ground base');
 // Current four exports have scene-root TRS. Refuse changed hierarchy/matrices.
 const roots=new Set(g.scenes[g.scene||0].nodes);for(const n of meshes)if(!roots.has(g.nodes.indexOf(n))||n.matrix||n.children?.length)throw Error('Lamp geometry adapter requires re-audit');
 function transform(n,p){const[x,y,z]=p.map((v,k)=>v*(n.scale?.[k]??1)),[qx,qy,qz,qw]=n.rotation||[0,0,0,1];const tx=2*(qy*z-qz*y),ty=2*(qz*x-qx*z),tz=2*(qx*y-qy*x);return[x+qw*tx+qy*tz-qz*ty,y+qw*ty+qz*tx-qx*tz,z+qw*tz+qx*ty-qy*tx].map((v,k)=>v+(n.translation?.[k]??0));}
 function bounds(n){const points=[];for(const p of g.meshes[n.mesh].primitives){const a=g.accessors[p.attributes.POSITION];for(const x of[a.min[0],a.max[0]])for(const y of[a.min[1],a.max[1]])for(const z of[a.min[2],a.max[2]])points.push(transform(n,[x,y,z]));}return {node:n.name,min:[0,1,2].map(k=>Math.min(...points.map(p=>p[k]))),max:[0,1,2].map(k=>Math.max(...points.map(p=>p[k])))};}
 const ground=bounds(base),all=meshes.map(bounds),visual={min:[0,1,2].map(k=>Math.min(...all.map(x=>x.min[k]))),max:[0,1,2].map(k=>Math.max(...all.map(x=>x.max[k])))};
 const origin=[(ground.min[0]+ground.max[0])/2,ground.min[1],(ground.min[2]+ground.max[2])/2];
 const sourceSocket=asset.placementOriginGltfM;
 const adapter={placementOriginGltfM:origin,placementOriginEvidence:{sourceNode:base.name,sourceSocketGltfM:sourceSocket,reason:'Meshes already recentered; helper socket retains stale catalog translation',sha256:hash(b)},
  clearanceM:[2*Math.max(Math.abs(visual.min[0]-origin[0]),Math.abs(visual.max[0]-origin[0]))+.6,2*Math.max(Math.abs(visual.min[2]-origin[2]),Math.abs(visual.max[2]-origin[2]))+.6,visual.max[1]-origin[1]+.3],
  collisionEvidence:{sourceNode:base.name,method:'exact POSITION accessor bounds with scene-root TRS, only ground base; no canopy AABB',sha256:hash(b)},
  groundBodiesGltfM:[{node:ground.node,min:ground.min.map((x,k)=>x-origin[k]),max:ground.max.map((x,k)=>x-origin[k])}],visualBoundsGltfM:visual};
 lampAdapters[asset.assetId]=adapter;
 if(origin.some((x,k)=>Math.abs(x-sourceSocket[k])>1e-5))findings.push({assetId:asset.assetId,code:'STALE_PLACEMENT_SOCKET',sourceSocketGltfM:sourceSocket,groundOriginGltfM:origin,mitigation:'evidence-backed per-asset visual-origin override, source GLB untouched'});
}
// Bridge sources in the industrial manifest must agree with the civic catalog.
const bridgeRows=manifest.assets.filter(a=>a.coverage?.some(x=>/bridge/.test(x)));
const bridgeBindings=[];for(const row of bridgeRows)for(const glb of row.glbs||[]){const match=catalog.entries.find(e=>e.lods.some(l=>l.sha256===glb.sha256?.toLowerCase()));if(match){verified(glb);bridgeBindings.push({assetId:match.assetId,source:glb});}}
const output={schema:'mafiozi.city-rebuild.infrastructure-bindings/v1',scope:'isolated_walk_preview',source:{path:path.resolve(manifestPath),bytes:mb.length,sha256:hash(mb)},
 roadMaterials:{source:{path:roadSource.absolutePath,bytes:roadSource.bytes,sha256:roadSource.sha256},usage:'Extracted PBR descriptors only. Combined 12-module GLB is NOT instantiated or staged as one map model.',materialDescriptors},lampAdapters,bridgeBindings,findings,artAcceptance:'needs_visual_review'};
fs.writeFileSync(path.join(here,'infrastructure_catalog.v1.json'),JSON.stringify(output,null,2)+'\n');console.log(JSON.stringify({materials:materialDescriptors.length,lamps:Object.keys(lampAdapters).length,staleSockets:findings.length,bridgeBindings:bridgeBindings.length}));
