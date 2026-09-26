#!/usr/bin/env python3
"""Execute the actual Walk print-shop generators; export their immutable result.

No geometry/layout recreation in Python. Node/Three and every imported source are
receipted. --check reruns generation and compares bytes without mutating outputs.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / 'godot/mafiozi_walk/data/printshop_interior.json'
NODE = r'''
import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {registerHooks} from 'node:module';
import {pathToFileURL,fileURLToPath} from 'node:url';
const repo=process.cwd(),vendor=process.env.WALK_THREE_VENDOR;
const used=new Set();
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(path.join(vendor,'build/three.module.js')).href:s,c)},load(u,c,next){if(u.startsWith('file:'))used.add(fileURLToPath(u));return next(u,c)}});
const T=await import(pathToFileURL(path.join(vendor,'build/three.module.js')));
const {GLTFLoader}=await import(pathToFileURL(path.join(vendor,'addons/loaders/GLTFLoader.js')));
const mod=n=>import(pathToFileURL(path.join(repo,'assets/maps/city_rebuild_v1',n)));
const {createWindowedBuildingEntry}=await mod('building_window_integration.mjs');
const {applyBuildingDoorsGlass}=await mod('building_doors_glass.mjs');
const {createPrintShopServiceStation}=await mod('native_print_shop_service_station.mjs');
const digest=b=>createHash('sha256').update(b).digest('hex');
const read=n=>{const p=path.join(repo,n);used.add(p);return fs.readFileSync(p)};
const id='REBUILD-VISUAL-print_shop-001';
const item=JSON.parse(read('assets/maps/city_rebuild_v1/buildings_placement.v1.json')).instances.find(n=>n.id===id);
const block=JSON.parse(read('godot/mafiozi_walk/data/block.json'));
const binding=block.buildings.find(n=>n.id===id);
if(!binding||JSON.stringify(item.transform)!==JSON.stringify(binding.transform))throw Error('Block transform does not match source');
const bytes=read(item.binding.url.replace(/^\//,''));
if(digest(bytes)!==item.binding.sha256||bytes.length!==item.binding.bytes)throw Error('GLB binding mismatch');
const visual=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
const originals=new Map();visual.traverse(n=>{if(n.isMesh)originals.set(n,{name:n.name,geometry:n.geometry,material:n.material,parent:n.parent,matrix:n.matrix.clone()})});
const scene=new T.Scene(),group=new T.Group(),t=item.transform,origin=new T.Vector3(...block.originM);
group.position.fromArray(t.positionM);group.rotation.y=t.yawDegrees*Math.PI/180;group.scale.setScalar(t.uniformScale);visual.position.fromArray(t.modelLocalOffsetM);group.add(visual);scene.add(group);scene.updateMatrixWorld(true);
visual.traverse(n=>{if(item.hideNodeNames?.includes(n.name))n.visible=false});
applyBuildingDoorsGlass(visual,item);
const {entry}=createWindowedBuildingEntry({THREE:T,visual,instance:item,metresPerCell:4.1});
if(!entry?.storeys||entry.storeys.floors.length!==1)throw Error('Audited one-storey source changed');
// Certification here is geometry, not service activation. Reject overlaps using
// exact source bodies; no fake seller, inventory or camera visibility state.
const baseBodies=entry.getCollisionBodies();
const inside=(x,z,p)=>{let hit=false;for(let i=0,j=p.length-1;i<p.length;j=i++){const a=p[i],b=p[j];if((a[1]>z)!==(b[1]>z)&&x<(b[0]-a[0])*(z-a[1])/(b[1]-a[1])+a[0])hit=!hit}return hit};
const pointClear=p=>!baseBodies.some(b=>(b.maxYM??Infinity)>p.y+.08&&(b.minYM??-Infinity)<p.y+1.9&&Array.from({length:33},(_,i)=>{const a=i*Math.PI/16,r=i===32?0:.738;return inside((p.x+Math.cos(a)*r)/4.1,(p.z+Math.sin(a)*r)/4.1,b.polygonCR)}).some(Boolean));
const overlaps=(a,b)=>{for(const polygon of[a,b])for(let i=0;i<polygon.length;i++){const p=polygon[i],q=polygon[(i+1)%polygon.length],x=-(q[1]-p[1]),z=q[0]-p[0],u=a.map(v=>v[0]*x+v[1]*z),v=b.map(v=>v[0]*x+v[1]*z);if(Math.max(...u)<=Math.min(...v)+1e-9||Math.max(...v)<=Math.min(...u)+1e-9)return false}return true};
const station=createPrintShopServiceStation({THREE:T,entry,siteRevision:'service-pilot-v1',validateLayout:({layout,counterRect,room})=>{const r=counterRect,polygon=[[r[0],r[1]],[r[2],r[1]],[r[2],r[3]],[r[0],r[3]]].map(([x,z])=>{const p=entry.storeys.worldPoint({x,y:room.y,z});return[p.x/4.1,p.z/4.1]});return Object.values(layout).filter(v=>v&&typeof v==='object'&&'x'in v).every(pointClear)&&!baseBodies.some(b=>(b.maxYM??Infinity)>layout.work.y+.05&&(b.minYM??-Infinity)<layout.work.y+1.339&&overlaps(polygon,b.polygonCR))}});
scene.updateMatrixWorld(true);
const publicPivot=entry.object.children.find(n=>n.name==='Entry_Hinge_0');
const servicePivot=station.root.children.find(n=>n.isGroup).children[0];
const relative=m=>{const a=m.toArray();a[12]-=origin.x;a[13]-=origin.y;a[14]-=origin.z;return a};
const motionOf=n=>{for(let p=n;p;p=p.parent){if(p===publicPivot)return 'public';if(p===servicePivot)return 'service'}return ''};
const motions={public:publicPivot,service:servicePivot};
const motionFrames=Object.fromEntries(Object.entries(motions).map(([key,n])=>{const p=new T.Vector3(),q=new T.Quaternion(),s=new T.Vector3();n.matrixWorld.decompose(p,q,s);return[key,new T.Matrix4().compose(p,q,new T.Vector3(1,1,1))]}));
const geometries=[],materials=[],meshes=[],overrides=[],hidden=[],geometryIds=new Map(),materialIds=new Map();
const material=m=>{if(materialIds.has(m))return materialIds.get(m);if(m.map||m.normalMap||m.roughnessMap)throw Error('Texture material needs an explicit export: '+m.name);const index=materials.length;materialIds.set(m,index);materials.push({name:m.name,colorLinear:m.color?.toArray()??[1,1,1],roughness:m.roughness??1,metalness:m.metalness??0,emissiveLinear:m.emissive?.toArray()??[0,0,0],emissiveIntensity:m.emissiveIntensity??0,opacity:m.opacity??1,transparent:!!m.transparent,doubleSided:m.side===T.DoubleSide,vertexColors:!!m.vertexColors,sourceProceduralShader:m.onBeforeCompile.toString().includes('shader')&&m.onBeforeCompile!==T.Material.prototype.onBeforeCompile});return index};
const geometry=g=>{if(geometryIds.has(g))return geometryIds.get(g);const index=geometries.length;geometryIds.set(g,index);const attrs={};for(const k of ['position','normal','uv','color']){const a=g.getAttribute(k);if(a){if(a.isInterleavedBufferAttribute||a.normalized)throw Error('Unsupported source attribute');attrs[k]={size:a.itemSize,values:Array.from(a.array)}}}geometries.push({attributes:attrs,indices:g.index?Array.from(g.index.array):null,groups:g.groups.map(v=>({...v}))});return index};
const visible=n=>{for(let p=n;p;p=p.parent)if(!p.visible)return false;return true};
const body=b=>({...b,polygonXZ:b.polygonCR.map(([c,r])=>[c*4.1-origin.x,r*4.1-origin.z]),minY:b.minYM-origin.y,maxY:b.maxYM-origin.y});
const floorNames=/^(Entry_Interior_Floor|Entry_Corridor_Floor|Entry_Continuous_Ramp|Storey_Floors|Storey_Walls_And_Ceilings)$/;
visual.traverse(n=>{
 if(!n.isMesh)return;
 const original=originals.get(n),motion=motionOf(n),mat=(Array.isArray(n.material)?n.material:[n.material]).map(material);
 if(original&&!motion){if(!visible(n)){hidden.push(original.name);return}if(n.geometry!==original.geometry||n.material!==original.material)overrides.push({sourceName:original.name,geometry:geometry(n.geometry),materials:mat});return}
 if(original)hidden.push(original.name);
 if(!visible(n))return;
 const base=motion?motionFrames[motion].clone().invert().multiply(n.matrixWorld).toArray():relative(n.matrixWorld);
 const record={name:n.name,geometry:geometry(n.geometry),materials:mat,transform:base,motion,floorCollision:floorNames.test(n.name)};
 if(n.isInstancedMesh){const m=new T.Matrix4();record.instances=Array.from({length:n.count},(_,i)=>{n.getMatrixAt(i,m);return m.toArray()})}
 if(n.instanceColor)record.instanceColorsLinear=Array.from({length:n.count},(_,i)=>[n.instanceColor.getX(i),n.instanceColor.getY(i),n.instanceColor.getZ(i)]);
 meshes.push(record);
});
const staticBodies=baseBodies.filter(b=>!b.movingDoor||b.interiorDoor).map(body).concat(station.getCollisionBodies().filter(b=>!b.movingDoor).map(body));
const doors={public:{id:id+':public-door',duration:.65,angle:Math.PI/2,transform:relative(publicPivot.matrixWorld),bodies:baseBodies.filter(b=>b.movingDoor&&!b.interiorDoor).map(body),anchor:entry.object.getWorldPosition(new T.Vector3()).sub(origin).toArray(),proximity:2.45},service:{id:station.layout.doorId,duration:.6,angle:-Math.PI/2,transform:relative(servicePivot.matrixWorld),bodies:station.getCollisionBodies().filter(b=>b.movingDoor).map(body),anchor:[station.layout.doorInside.x-origin.x,station.layout.doorInside.y-origin.y,station.layout.doorInside.z-origin.z],proximity:1.65}};
for(const [key,d]of Object.entries(doors))d.transform=relative(motionFrames[key]);
for(const d of Object.values(doors)){const inv=new T.Matrix4().fromArray(d.transform).invert();for(const b of d.bodies){b.pointsLocal=[];for(const [x,z]of b.polygonXZ)for(const y of[b.minY,b.maxY])b.pointsLocal.push(new T.Vector3(x,y,z).applyMatrix4(inv).toArray())}}
const anchors=Object.fromEntries(Object.entries(station.layout).filter(([,v])=>v&&typeof v==='object'&&'x'in v).map(([k,p])=>[k,[p.x-origin.x,p.y-origin.y,p.z-origin.z]]));
anchors.publicApproach=entry.approachPoint().sub(origin).toArray();anchors.publicInside=entry.roomPoint().sub(origin).toArray();
const sources=[...used].sort().map(p=>({path:p.startsWith(repo+path.sep)?path.relative(repo,p).replaceAll('\\','/'):'THREE_VENDOR/'+path.relative(vendor,p).replaceAll('\\','/'),bytes:fs.statSync(p).size,sha256:digest(fs.readFileSync(p))}));
const result={schema:'mafiozi-printshop-interior-v1',sourceId:id,assetSha256:item.binding.sha256,transform:t,originM:block.originM,unit:'metres; source +Y, +Z retained',replaceCollisionSourceIndices:[0,1,2],sources,entryReport:entry.report,rooms:entry.storeys.rooms,floors:entry.storeys.floors,anchors,serviceIds:{stationId:station.layout.stationId,roomId:station.layout.roomId,doorId:station.layout.doorId},geometry:geometries,materials,meshes,overrides,hideOriginalNames:hidden,staticBodies,doors,limits:['Pilot geometry and public/service doors only; no seller/economy/service authority activated.','Other source room door and safe remain in their source closed pose; no invented unlock state.','Procedural interior finish shaders and light photometry require separate LIVE parity; base linear materials retained.','Roof ladder mesh is source-generated, but ladder climbing action is not enabled.']};
result.frames={entryToPreview:relative(entry.object.matrixWorld),storeysToPreview:relative(entry.storeys.root.matrixWorld)};
result.sourceLights=[];visual.traverse(n=>{if(n.isPointLight&&visible(n))result.sourceLights.push({position:n.getWorldPosition(new T.Vector3()).sub(origin).toArray(),colorLinear:n.color.toArray(),intensity:n.intensity,distance:n.distance,decay:n.decay})});
result.runtimeVersions={node:process.version,three:T.REVISION};
process.stdout.write(JSON.stringify(result));
station.dispose();entry.dispose();
'''

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--three-vendor', default='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor')
    args = parser.parse_args()
    env = dict(os.environ, WALK_THREE_VENDOR=args.three_vendor)
    result = subprocess.run(['node', '--input-type=module', '-'], input=NODE, text=True,
                            encoding='utf-8', cwd=ROOT, env=env, capture_output=True)
    if result.returncode:
        sys.stderr.write(result.stderr)
        raise SystemExit(result.returncode)
    data = json.loads(result.stdout)
    data['exporterSha256'] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    output = (json.dumps(data, ensure_ascii=False, separators=(',', ':'), allow_nan=False)+'\n').encode('utf-8')
    if args.check:
        if not TARGET.is_file() or TARGET.read_bytes() != output:
            raise SystemExit('FAIL: generated interior is stale')
    else:
        TARGET.write_bytes(output)
    print(json.dumps({'pass': True, 'check': args.check, 'bytes': len(output),
                      'sha256': hashlib.sha256(output).hexdigest(),
                      'overrides': len(data['overrides']), 'meshes': len(data['meshes']),
                      'staticBodies': len(data['staticBodies']), 'rooms': len(data['rooms'])}))

if __name__ == '__main__':
    main()
