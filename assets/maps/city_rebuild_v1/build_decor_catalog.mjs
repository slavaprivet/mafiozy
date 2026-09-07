// Mechanical, byte-preserving catalog/staging builder. Never edits gameplay.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '../../..');
const manifestPath = process.argv[2];
if (!manifestPath) throw Error('Usage: node build_decor_catalog.mjs <latest-ready-manifest.json>');
const hash = b => crypto.createHash('sha256').update(b).digest('hex');
const manifestBytes = fs.readFileSync(manifestPath), manifest = JSON.parse(manifestBytes);
const registryPath = 'assets/decor/civic_park_v2/registry.v1.json';
const registryBytes = fs.readFileSync(path.join(root, registryPath));
const registry = JSON.parse(registryBytes);
const identity = () => [1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1];
function multiply(a,b) { const out=Array(16).fill(0); for(let c=0;c<4;c++)for(let r=0;r<4;r++)for(let k=0;k<4;k++)out[c*4+r]+=a[k*4+r]*b[c*4+k];return out; }
function matrix(n) {
  if(n.matrix)return n.matrix;
  const [x,y,z,w]=n.rotation||[0,0,0,1],s=n.scale||[1,1,1],t=n.translation||[0,0,0];
  return [(1-2*y*y-2*z*z)*s[0],(2*x*y+2*w*z)*s[0],(2*x*z-2*w*y)*s[0],0,
    (2*x*y-2*w*z)*s[1],(1-2*x*x-2*z*z)*s[1],(2*y*z+2*w*x)*s[1],0,
    (2*x*z+2*w*y)*s[2],(2*y*z-2*w*x)*s[2],(1-2*x*x-2*y*y)*s[2],0,...t,1];
}
const point=(m,p)=>[0,1,2].map(r=>m[12+r]+p.reduce((v,x,c)=>v+m[c*4+r]*x,0));
function inspect(bytes, asset) {
  if(bytes.readUInt32LE(0)!==0x46546c67||bytes.readUInt32LE(4)!==2||bytes.readUInt32LE(8)!==bytes.length||bytes.readUInt32LE(16)!==0x4e4f534a)throw Error('Invalid GLB '+asset.assetId);
  const g=JSON.parse(bytes.subarray(20,20+bytes.readUInt32LE(12)).toString()), nodes=g.nodes||[], worlds=new Map();
  if([...(g.buffers||[]),...(g.images||[])].some(x=>x.uri&&!x.uri.startsWith('data:')))throw Error('Unpinned external GLB resource '+asset.assetId);
  function walk(i,parent){if(worlds.has(i))throw Error('Shared/cyclic GLB node');const m=multiply(parent,matrix(nodes[i]));worlds.set(i,m);for(const c of nodes[i].children||[])walk(c,m);}
  for(const i of g.scenes[g.scene||0].nodes)walk(i,identity());
  const iface=asset.interfaces||{}, names=nodes.map(n=>n.name).filter(Boolean);
  const placement=iface.placementSocket||iface.placementSockets?.[0];
  const pi=nodes.findIndex(n=>n.name===placement), origin=pi<0?null:point(worlds.get(pi),[0,0,0]);
  const collisionNames=iface.collision?.collisionNodes||[], bodies=[];
  for(const name of collisionNames){const i=nodes.findIndex(n=>n.name===name);if(i<0)throw Error('Missing collision '+name);const points=[];
    function bounds(k){const n=nodes[k];for(const p of g.meshes?.[n.mesh]?.primitives||[]){const a=g.accessors[p.attributes.POSITION];if(!a.min||!a.max)throw Error('No POSITION bounds');for(const x of[a.min[0],a.max[0]])for(const y of[a.min[1],a.max[1]])for(const z of[a.min[2],a.max[2]])points.push(point(worlds.get(k),[x,y,z]));}for(const c of n.children||[])bounds(c);}
    bounds(i); if(points.length&&origin)bodies.push({node:name,min:origin.map((o,k)=>Math.min(...points.map(p=>p[k]))-o),max:origin.map((o,k)=>Math.max(...points.map(p=>p[k]))-o)});
  }
  const clearanceName=iface.clearanceSocket||iface.clearanceNodes?.[0], cn=nodes.find(n=>n.name===clearanceName);
  // dimensionsM is Blender XYZ (width, depth, height), even after glTF Y-up export.
  const clearanceM=cn?.extras?.dimensionsM||null;
  const required=[placement,clearanceName,...collisionNames,...(iface.navMaskNodes||[]),...(iface.semanticSockets||[])].filter(Boolean);
  for(const n of required)if(!names.includes(n))throw Error('Missing contract node '+n);
  return {placementSocket:placement||null,placementOriginGltfM:origin,clearanceNode:clearanceName||null,clearanceM,collisionBodiesGltfM:bodies,nodeCount:nodes.length,verifiedContractNodes:required};
}
const entries=[];
for(const asset of manifest.assets){
  const repo=registry.entries.find(e=>e.assetId===asset.assetId), lods=[];let inspection;
  for(const glb of asset.glbs){
    const sourcePath=path.normalize(glb.path),bytes=fs.readFileSync(sourcePath),sha256=hash(bytes);
    if(bytes.length!==glb.bytes||sha256!==glb.sha256.toLowerCase())throw Error('Source hash mismatch '+sourcePath);
    const current=inspect(bytes,asset);if(glb.lod===0)inspection=current;
    let relativePath;
    if(repo){const binding=repo.lods.find(l=>l.lod===glb.lod);relativePath=path.posix.join('assets/decor/civic_park_v2',binding.url);
      const rb=fs.readFileSync(path.join(root,relativePath));if(hash(rb)!==sha256||rb.length!==bytes.length)throw Error('Repo/source drift '+relativePath);
    }else{relativePath=path.posix.join('assets/maps/city_rebuild_v1/models',asset.packageId,path.basename(sourcePath));const destination=path.join(root,relativePath);
      fs.mkdirSync(path.dirname(destination),{recursive:true});if(fs.existsSync(destination)){if(hash(fs.readFileSync(destination))!==sha256)throw Error('Refuse overwrite '+destination);}else fs.writeFileSync(destination,bytes,{flag:'wx'});
    }
    lods.push({lod:glb.lod,url:'/'+relativePath,relativePath,bytes:bytes.length,sha256,sourcePath});
  }
  entries.push({assetId:asset.assetId,kind:asset.kind,packageId:asset.packageId,
    artAcceptance:{source:asset.userAcceptance,status:repo?'approved_civic_kit':'needs_visual_review',evidence:repo?'User explicitly accepted the civic park kit and requested integration; source not_explicitly_recorded is preserved above.':'User authorized technically checked assets in isolated rebuild preview, not final art acceptance.'},
    allowedScope:'isolated_rebuild_preview',sourceValidation:asset.validation,stagingStatus:'bytes_and_contract_nodes_verified',
    interfaces:asset.interfaces,...inspection,visualBoundsBlenderM:asset.glbs.find(l=>l.lod===0)?.boundsBlenderXYZM,
    clearanceM:repo?.clearanceM||inspection?.clearanceM||null,
    requiresGroundAdapter:!inspection?.collisionBodiesGltfM?.length&&asset.kind!=='plaza_module',
    assetRole:asset.kind==='building'?'building_catalog_only':asset.assetId==='street_furniture_v1'?'collection_not_single_placement':/traffic_signal/.test(asset.assetId)?'signal_adapter_required':(['forest_path','waterfront','surface_transition'].includes(asset.kind)||asset.assetId==='lookout_deck')?'walkable_surface_adapter_required':'decor',lods});
}
const output={schema:'mafiozi.city-rebuild.decor-catalog/v1',scope:'isolated_rebuild_preview_not_main',
  sources:{manifest:{path:path.resolve(manifestPath),bytes:manifestBytes.length,sha256:hash(manifestBytes)},registry:{path:registryPath,bytes:registryBytes.length,sha256:hash(registryBytes)}},
  counts:{types:entries.length,glbs:entries.reduce((n,e)=>n+e.lods.length,0),approvedCivicTypes:entries.filter(e=>e.artAcceptance.status==='approved_civic_kit').length,needsVisualReviewTypes:entries.filter(e=>e.artAcceptance.status==='needs_visual_review').length},
  coordinateContract:'Transforms are glTF Y-up, placement origin recentered; world x=c*metresPerCell,z=r*metresPerCell. Blender clearanceM order is width,depth,height.',
  missing:[{type:'trees',reason:'No tree asset in this 63-type manifest; rejected Artist12 content excluded.'},{type:'asphalt_glb',reason:'No asphalt GLB in manifest; emit merged native road surface batches, material binding required from host.'}],
  restrictions:['Catalog/collection GLBs are never world placements.','No final art acceptance inferred from technical PASS.','Collision uses declared proxy nodes only; no full facade or canopy AABB.','Bridge proxy requires deck/rail navigation adapter, not one solid blocking cuboid.','Street signals require per-approach authoritative layout and safe aspect controller.'],entries};
fs.writeFileSync(path.join(here,'decor_catalog.v1.json'),JSON.stringify(output,null,2)+'\n');
console.log(JSON.stringify(output.counts));
