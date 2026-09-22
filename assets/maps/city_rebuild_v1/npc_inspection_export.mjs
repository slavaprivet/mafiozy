// Click-only QA export. Never walk meshes, globals or accessor properties.
export function inspectionJson(value,{maxNodes=50000}={}){
 let nodes=0;const seen=new WeakSet();
 function copy(v,depth=0){
  if(++nodes>maxNodes||depth>10)return null;
  if(v===null||typeof v==='boolean')return v;
  if(typeof v==='number')return Number.isFinite(v)?v:null;
  if(typeof v==='string')return v.slice(0,4096);
  if(typeof v!=='object'||seen.has(v))return null;
  const proto=Object.getPrototypeOf(v);if(!Array.isArray(v)&&proto!==Object.prototype&&proto!==null)return null;
  seen.add(v);const out=Array.isArray(v)?[]:{};
  for(const key of Object.keys(v).slice(0,Array.isArray(v)?512:128)){
   if(['__proto__','constructor','prototype'].includes(key))continue;
   const d=Object.getOwnPropertyDescriptor(v,key);if(d&&'value'in d)out[key]=copy(d.value,depth+1);
  }
  seen.delete(v);return out;
 }
 return copy(value);
}
export function createInspectionExport({rows=[],getActorState=()=>null,routeReplay=null,npcWorld=null,time=0}={}){
 const actors=[];for(const row of rows){if(actors.length>=512)break;if(!row||typeof row.id!=='string')continue;
  const p=row.object?.position,q=row.object?.quaternion;
  actors.push({id:row.id,source:inspectionJson(row.source),presentation:inspectionJson({visible:row.object?.visible,position:p?{x:p.x,y:p.y,z:p.z}:null,quaternion:q?{x:q.x,y:q.y,z:q.z,w:q.w}:null,state:getActorState(row.id)})});
 }
 return {version:1,kind:'npc-inspection-snapshot',capturedAt:new Date().toISOString(),presentationTime:time,actorLimit:512,actors,routeReplay:inspectionJson(routeReplay),npcWorld:inspectionJson(npcWorld),limitations:['Point-in-time cached source/presentation, not a pose-input timeline.','No serialized wet vertices, wounds, initial animation state or terrain geometry.','Bounded JSON: 512 actors/array entries, depth10, strings4096, object keys128. Truncated or unsupported values may be null.']};
}
