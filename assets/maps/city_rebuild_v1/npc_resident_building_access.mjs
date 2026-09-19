// Adapt existing physical entrances; this does not create shops or replace IDs.
export function createNpcResidentBuildingAccess({getEntries,worldScale=4.1}={}){
 let generation=null,entryCount=-1,records=[],byId=new Map();
 function refresh(){
  const entries=getEntries();if(entries===generation&&entryCount===entries?.length&&records.length)return;generation=entries;entryCount=entries?.length;records=[];byId=new Map();
  for(const entry of entries||[]){
   if(entry.kind==='detention'||!entry.approachPoint||!entry.roomPoint||!entry.proximity||!entry.interact)continue;
   const outside=entry.approachPoint(),room=entry.roomPoint();
   if(![outside.x,outside.z,room.x,room.z].every(Number.isFinite))continue;
   outside.y=entry.floorHeight(outside.x,outside.z)??outside.y;
   // Stop inside the public entrance, before deeper room furniture. The same
   // collision sweep as walking still decides whether it can actually be reached.
   let inside=room.clone();const length=Math.hypot(room.x-outside.x,room.z-outside.z);
   for(let d=.8;d<length;d+=.15){const p=outside.clone().lerp(room,d/length);p.y=entry.floorHeight(p.x,p.z)??p.y;if(entry.containsInterior?.(p)){inside=p.clone().lerp(room,Math.min(1,.8/Math.max(.01,length-d)));break;}}
   const binding=/^(business|bank|major|blackmarket):(.+)$/.exec(String(entry.instance.gameplayId||''));
   const id='native:'+entry.instance.id,door={id,native:true,authored:true,residentEligible:true,instanceId:entry.instance.id,sourceKind:binding?.[1]||'native',sourceId:binding?.[2]||entry.instance.id,sourceAliases:binding?[binding[0]]:[],r:outside.z/worldScale,c:outside.x/worldScale,inside:{r:inside.z/worldScale,c:inside.x/worldScale}};
   door.districtId=String(entry.instance.districtId||'');door.assetId=String(entry.instance.assetId||'');door.buildingRole=String(entry.instance.role||'');
   records.push(door);byId.set(id,{entry,outside,door});
  }
 }
 return request=>{
  refresh();if(request?.action==='list')return {ready:records.length>0,doors:records};
  const record=byId.get(request?.doorId);if(!record)return {ready:false,reason:'entry-not-loaded'};
  const {entry,outside,door}=record,from=request.from;
  if(!from||!Number.isFinite(from.r)||!Number.isFinite(from.c)||Math.hypot(from.r-door.r,from.c-door.c)>3)return {ready:false,reason:'resident-too-far'};
  let state=entry.proximity(outside);
  if(request.action==='open'&&state&&!state.opening){entry.interact(outside);state=entry.proximity(outside);}
  return {ready:!!state&&state.fraction>=.95,reason:!state?'outside-interaction-range':state.fraction>=.95?'open':'door-moving',door};
 };
}
