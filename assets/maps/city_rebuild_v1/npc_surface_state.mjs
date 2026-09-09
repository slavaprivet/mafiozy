// Versioned in-memory transport helpers. No storage, gameplay authority or hit replay.
export const NPC_SURFACE_STATE_VERSION=1;
export function surfaceMeshPath(root,mesh){const path=[];let node=mesh;while(node!==root){if(!node.parent)throw Error('Surface mesh outside root');path.unshift(node.parent.children.indexOf(node));node=node.parent;}return path;}
export function resolveSurfaceMesh(root,path){if(!Array.isArray(path)||path.length>64||path.some(i=>!Number.isInteger(i)||i<0))throw Error('Invalid surface mesh path');let node=root;for(const i of path)node=node?.children[i];if(!node?.isMesh)throw Error('Missing surface mesh');return node;}
export function surfaceGeometrySignature(mesh){
 const g=mesh.geometry;let hash=2166136261;const parts=[];
 for(const name of ['position','skinIndex','skinWeight','index']){const a=name==='index'?g.index:g.attributes[name];if(!a){parts.push(name+':none');continue;}const array=a.array||a.data?.array;if(!array)throw Error('Unsupported surface attribute');parts.push(name+':'+a.count+':'+a.itemSize);const bytes=new Uint8Array(array.buffer,array.byteOffset,array.byteLength);for(const b of bytes){hash^=b;hash=Math.imul(hash,16777619);}}
 return parts.join('|')+'|'+(hash>>>0).toString(16);
}
export function surfaceMeshRecord(root,mesh){return {path:surfaceMeshPath(root,mesh),signature:surfaceGeometrySignature(mesh)};}
export function validateSurfaceMesh(root,record){const mesh=resolveSurfaceMesh(root,record?.path);if(record.signature!==surfaceGeometrySignature(mesh))throw Error('Surface geometry signature mismatch');return mesh;}
export function encodeWetBytes(values){let raw='';for(const value of values)raw+=String.fromCharCode(Math.round(Math.max(0,Math.min(1,value))*255));return btoa(raw);}
export function decodeWetBytes(data,count){if(!Number.isInteger(count)||count<0||count>1000000||typeof data!=='string'||data.length!==Math.ceil(count/3)*4||!/^[A-Za-z0-9+/]*={0,2}$/.test(data))throw Error('Invalid wet vertex payload');const raw=atob(data);if(raw.length!==count)throw Error('Wet vertex length mismatch');return Uint8Array.from(raw,c=>c.charCodeAt(0));}
export function validateSurfaceReceipts(values){if(!Array.isArray(values)||values.length>512||values.some(v=>typeof v!=='string'||!v||v.length>1024)||new Set(values).size!==values.length)throw Error('Invalid surface receipts');return values;}
