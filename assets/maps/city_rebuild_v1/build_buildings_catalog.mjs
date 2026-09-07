// Reproducible, byte-preserving asset staging. Does not change game sources.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const here=path.dirname(fileURLToPath(import.meta.url)),root=path.resolve(here,'../../..');
const manifestPath=process.argv[2];if(!manifestPath)throw Error('Pass latest-ready residential manifest');
const read=p=>JSON.parse(fs.readFileSync(p,'utf8')),hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const I=()=>[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1];
function mul(a,b){const o=Array(16).fill(0);for(let c=0;c<4;c++)for(let r=0;r<4;r++)for(let k=0;k<4;k++)o[c*4+r]+=a[k*4+r]*b[c*4+k];return o;}
function matrix(n){if(n.matrix)return n.matrix;const[x,y,z,w]=n.rotation||[0,0,0,1],s=n.scale||[1,1,1],t=n.translation||[0,0,0];return[(1-2*y*y-2*z*z)*s[0],(2*x*y+2*w*z)*s[0],(2*x*z-2*w*y)*s[0],0,(2*x*y-2*w*z)*s[1],(1-2*x*x-2*z*z)*s[1],(2*y*z+2*w*x)*s[1],0,(2*x*z+2*w*y)*s[2],(2*y*z-2*w*x)*s[2],(1-2*x*x-2*y*y)*s[2],0,...t,1];}
const transform=(m,p)=>[0,1,2].map(r=>m[12+r]+p.reduce((n,v,c)=>n+m[c*4+r]*v,0));
const blank=()=>({min:[Infinity,Infinity,Infinity],max:[-Infinity,-Infinity,-Infinity]});
const add=(b,p)=>p.forEach((v,k)=>{b.min[k]=Math.min(b.min[k],v);b.max[k]=Math.max(b.max[k],v);});
const hidden=name=>/(?:^|[_ .-])LOD[_ .-]?[12](?:$|[_ .-])|collision|collider|socket|anchor|navmask|clearance|camera|light_rig/i.test(name);
function inspect(bytes,source){
  if(bytes.readUInt32LE(0)!==0x46546c67||bytes.readUInt32LE(4)!==2||bytes.readUInt32LE(8)!==bytes.length)throw Error('Invalid GLB '+source.assetId);
  let g,bin;for(let offset=12;offset<bytes.length;){const size=bytes.readUInt32LE(offset),type=bytes.readUInt32LE(offset+4);if(type===0x4e4f534a)g=JSON.parse(bytes.subarray(offset+8,offset+8+size).toString());if(type===0x004e4942)bin=bytes.subarray(offset+8,offset+8+size);offset+=8+size;}
  if(!g||!bin)throw Error('Missing GLB chunks');
  if([...(g.buffers||[]),...(g.images||[])].some(x=>x.uri&&!x.uri.startsWith('data:')))throw Error('External dependency');
  const bounds=blank(),nodes=[],collisionBodies=[],hideNodeNames=[];let triangles=0,vertices=0;
  function walk(i,parent,parentHidden=false){const n=g.nodes[i],m=mul(parent,matrix(n)),name=n.name||'node_'+i,isHidden=parentHidden||hidden(name);if(isHidden)hideNodeNames.push(name);const nb=blank();
    for(const p of g.meshes?.[n.mesh]?.primitives||[]){
      const a=g.accessors[p.attributes.POSITION],v=g.bufferViews[a.bufferView];if(a.componentType!==5126||a.type!=='VEC3'||a.sparse||!v)throw Error('Unsupported POSITION');
      const base=(v.byteOffset||0)+(a.byteOffset||0),stride=v.byteStride||12;
      for(let k=0;k<a.count;k++){const q=transform(m,[0,1,2].map(j=>bin.readFloatLE(base+k*stride+j*4)));add(nb,q);if(!isHidden)add(bounds,q);}
      if(!isHidden){vertices+=a.count;triangles+=(p.indices!==undefined?g.accessors[p.indices].count:a.count)/3;}
    }
    const origin=transform(m,[0,0,0]);nodes.push({name,origin,mesh:n.mesh!==undefined,hidden:isHidden,bounds:Number.isFinite(nb.min[0])?nb:null});
    if(/collision|collider/i.test(name)&&Number.isFinite(nb.min[0]))collisionBodies.push({node:name,...nb});
    for(const c of n.children||[])walk(c,m,isHidden);
  }
  for(const i of g.scenes[g.scene||0].nodes)walk(i,I());
  if(!Number.isFinite(bounds.min[0]))throw Error('No visual geometry');
  const socketName=source.door?.anchor_node||source.door?.node;
  const socket=nodes.find(n=>n.name===socketName)||nodes.find(n=>/PublicDoorSocket|EntranceAnchor|Public.*Socket/i.test(n.name))||nodes.find(n=>n.name==='CivicHall_DoorThreshold');
  const publicDoor=socket?.origin||source.door?.position_gltf||source.publicSocket||null;
  const center=[(bounds.min[0]+bounds.max[0])/2,bounds.min[1],(bounds.min[2]+bounds.max[2])/2];
  return{visualBounds:bounds,recenterXYZ:center.map(x=>-x),dimensionsXYZ:bounds.max.map((x,i)=>x-bounds.min[i]),publicDoorLocalXYZ:publicDoor,
    publicDoorEvidence:socket?'actual_glb_node:'+socket.name:publicDoor?'authored_manifest':'missing',frontSign:publicDoor&&publicDoor[2]<center[2]?-1:1,collisionBodies,hideNodeNames:[...new Set(hideNodeNames)],
    measuredVisualVertices:vertices,measuredVisualTriangles:triangles,nodeCount:nodes.length,doorCandidateNodes:nodes.filter(n=>/door|entrance|socket/i.test(n.name)).map(n=>({name:n.name,origin:n.origin}))};
}
const home=read(manifestPath),sources=[];
for(const pkg of home.packages)for(const a of pkg.assets){sources.push({assetId:a.asset_id,role:pkg.area==='glass_skyline'?'glass_tower':'residence',districts:a.district_compatibility,packageId:pkg.package_id,sourceAcceptance:a.user_acceptance,door:a.public_door,
  lods:Object.entries(a.lods).filter(([,l])=>l.file).map(([key,l])=>({...l,lod:Number(key.slice(3)),path:path.join(pkg.package_root,l.file)}))});}
for(const folder of ['accepted_v1','next_batch_v1']){const dir=path.join(root,'assets/buildings/city_v3',folder),reg=read(path.join(dir,'registry.v1.json'));for(const e of reg.entries){const m=read(path.resolve(dir,e.manifest.url));sources.push({assetId:e.key.split('@')[0],role:'business_facade',districts:['old_town','chinatown','southside','central'],packageId:folder,sourceAcceptance:e.status,door:{node:m.geometry.public_door_node},publicSocket:m.geometry.public_anchor_local_xyz_m||m.geometry.public_door_local_xyz_m,lods:[{lod:0,path:path.resolve(dir,e.asset.url),...e.asset}]});}}
sources.push({assetId:'glass_pavilion_small_v1',role:'glass_retail',districts:['central','eastside'],packageId:'glass_v1',sourceAcceptance:'approved_glass_reference',publicSocket:[0,0,5.05],lods:[{lod:0,path:path.join(root,'assets/buildings/city_v3/glass_v1/glass_pavilion_small_ao.ecae5f97bd53.glb'),bytes:3773048,sha256:'ecae5f97bd53e9466bea3a520ec95a58ecacd7a232fbde902de0a1a7d4672873'}]});
for(const e of read(path.join(here,'decor_catalog.v1.json')).entries.filter(e=>e.kind==='building'))sources.push({assetId:e.assetId,role:'civic_building',districts:e.assetId==='fire_station'?['central','eastside','southside','iron_harbor','north_hills']:['central','eastside','southside'],packageId:e.packageId,sourceAcceptance:e.artAcceptance,door:{node:e.interfaces?.semanticSockets?.find(n=>/public|entrance/i.test(n))},lods:e.lods.map(l=>({...l,path:path.join(root,l.relativePath)}))});
const entries=[];
for(const s of sources){const lods=[];let inspection;for(const l of s.lods){const bytes=fs.readFileSync(l.path),sha=hash(bytes);if(sha!==l.sha256.toLowerCase()||bytes.length!==l.bytes)throw Error('Hash/bytes mismatch '+l.path);
  const relativePath='assets/maps/city_rebuild_v1/building_models/'+s.assetId+'/'+path.basename(l.path),dest=path.join(root,relativePath);fs.mkdirSync(path.dirname(dest),{recursive:true});
  if(fs.existsSync(dest)){if(hash(fs.readFileSync(dest))!==sha)throw Error('Refuse different hash overwrite '+dest);}else fs.writeFileSync(dest,bytes,{flag:'wx'});
  if(l.lod===0)inspection=inspect(bytes,s);lods.push({lod:l.lod,url:'/'+relativePath,sha256:sha,bytes:bytes.length});
 }
 entries.push({...s,lods,...inspection,sourceAcceptance:s.sourceAcceptance??'not_recorded',artAcceptance:'needs_visual_review',allowedScope:'isolated_rebuild_walk_preview',scale:1,metresPerCell:4.1,sourceHashVerified:true});
}
const catalog={schema:'mafiozi.city-rebuild.buildings-catalog/v1',scope:'isolated_rebuild_walk_preview_not_main',sourceManifest:{path:manifestPath,sha256:hash(fs.readFileSync(manifestPath))},counts:{types:entries.length,glbs:entries.reduce((n,e)=>n+e.lods.length,0)},entries};
fs.writeFileSync(path.join(here,'buildings_catalog.v1.json'),JSON.stringify(catalog,null,2)+'\n');
console.log(JSON.stringify({counts:catalog.counts,assets:entries.map(e=>({id:e.assetId,dimensions:e.dimensionsXYZ.map(x=>+x.toFixed(2)),door:e.publicDoorEvidence}))},null,2));
