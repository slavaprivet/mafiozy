import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

export const CATALOG_SHA256='ae089d73eb61131bc6a38ccc6a2b9b18639f7bd8b65079f7c15c1e1cda9cde6e';
export const PROCEDURAL_SHA256='82e6ef82a824e002d0f315972ffd3d967102b7c36256371699992bcfb76220dd';
export const TRANSPORT_SHA256='69ecbd14108fd151b504a41dc3d00ab5dbeca98b8c5ccd6251553fb60189546b';
export const CELL_METRES=64;
export const VISUAL_SPATIAL_STATE='UNVERIFIED_SOURCE_EXTENTS';
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const family=dataset=>['buildings','decor','detention'].includes(dataset)?'authored':dataset.startsWith('exploration-')||dataset.startsWith('road-')?'procedural':'transport';
const finite=v=>typeof v==='number'&&Number.isFinite(v);
function location(row,origin){
 if(Array.isArray(row.positionLocalM)&&row.positionLocalM.length===3&&row.positionLocalM.every(finite))return row.positionLocalM;
 const proxy=row.sourceRecord?.proxy;
 if(proxy&&finite(proxy.x)&&finite(proxy.z))return [proxy.x-origin[0],finite(row.sourceRecord.y)?row.sourceRecord.y-origin[1]:0,proxy.z-origin[2]];
 throw Error('No exact source anchor '+row.key);
}
export function buildIndex(catalogBytes,proceduralBytes,transportBytes){
 if(sha(catalogBytes)!==CATALOG_SHA256||sha(proceduralBytes)!==PROCEDURAL_SHA256||sha(transportBytes)!==TRANSPORT_SHA256)throw Error('Source lineage drift');
 const c=JSON.parse(catalogBytes),p=JSON.parse(proceduralBytes),t=JSON.parse(transportBytes);
 if(c.schema!=='mafiozi.godot.map-editor-catalog/v1'||c.counts?.objects!==9901||c.objects.length!==9901||p.schema!=='mafiozi.godot.map-editor-procedural-source/v1'||t.schema!=='mafiozi.godot.map-editor-transport-decor-source/v1')throw Error('Unsupported exact source');
 if(c.metresPerCell!==4.1||!Array.isArray(c.originM)||c.originM.length!==3)throw Error('Coordinate contract');
 const ids=new Set(),records=[],anchorCells=new Map(),counts={authored:0,procedural:0,transport:0};
 for(const row of c.objects){
  if(typeof row.key!=='string'||!row.key||ids.has(row.key)||typeof row.id!=='string'||!row.id)throw Error('Ambiguous source identity');
  ids.add(row.key);
  const pos=location(row,c.originM),f=family(row.dataset),anchorCell=`${Math.floor(pos[0]/CELL_METRES)}:${Math.floor(pos[2]/CELL_METRES)}`;
  // The catalog position/proxy is an address, not an independently verified
  // render AABB. A road, railway or GLB may cover cells far from its anchor.
  const record={key:row.key,id:row.id,dataset:row.dataset,family:f,category:row.category??row.dataset,label:row.label??row.assetId??row.id,positionLocalM:pos,anchorCell,sourceOrdinal:records.length,visualState:'not_streamed',visualSpatialState:VISUAL_SPATIAL_STATE,visualEvictionEligible:false,editState:'owner_receipt_required'};
  records.push(record);counts[f]++;
  if(!anchorCells.has(anchorCell))anchorCells.set(anchorCell,[]);
  anchorCells.get(anchorCell).push(record.sourceOrdinal);
 }
 if(counts.authored!==242||counts.procedural!==9394||counts.transport!==265)throw Error('Full-family count drift');
 return {schema:'mafiozi.full-world-readonly-index/v1',source:{catalogSha256:CATALOG_SHA256,proceduralSha256:PROCEDURAL_SHA256,transportSha256:TRANSPORT_SHA256,originM:c.originM,metresPerCell:4.1},counts,records,catalogAnchorCells:Object.fromEntries([...anchorCells].map(([k,v])=>[k,v])),visualSpatialState:VISUAL_SPATIAL_STATE,visualCellIncidence:null,visualEvictionEnabled:false,renderedIds:0,editorReady:false,ownerReceipt:null};
}
// Fail closed until a separate, source-hashed geometry owner supplies and
// verifies conservative visual bounds for every requested source key.
export function visualKeysForCell(index,cell){
 if(index.visualSpatialState!==VISUAL_SPATIAL_STATE||index.visualCellIncidence!==null||index.visualEvictionEnabled!==false)throw Error('Unexpected visual spatial contract');
 if(typeof cell!=='string'||!/^[-]?\d+:[-]?\d+$/.test(cell))throw Error('Invalid cell');
 throw Error('Visual cell incidence unavailable: anchor cells are catalog-only');
}
export function canEvictVisual(index,key){
 if(index.visualEvictionEnabled!==false)throw Error('Unexpected visual eviction contract');
 if(!index.records.some(record=>record.key===key))throw Error('Unknown source key');
 return false;
}
export function loadCurrentIndex(root=process.cwd()){
 const files=['godot/mafiozi_walk/data/map_editor/catalog.json','outputs/map_editor_procedural_source/manifest.json','outputs/map_editor_transport_decor_source/manifest.json'];
 const bytes=files.map(rel=>fs.readFileSync(path.join(root,rel)));
 return buildIndex(...bytes);
}
