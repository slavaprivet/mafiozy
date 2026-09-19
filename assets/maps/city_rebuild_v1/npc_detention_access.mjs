// Source custody decides when access is authorized. This adapter only operates
// the matching physical doors and reports their actual animated clearance.
export function createNpcDetentionAccess({getEntries,worldScale=4.1}={}){
 return request=>{
  const id=String(request?.destinationId||''),entry=getEntries().find(e=>e.kind==='detention'&&(e.instance?.detentionId===id||e.instance?.id===id));
  if(!entry)return {ready:false,reason:'detention-not-loaded'};
  const point=request.from;
  if(!point||![point.r,point.c].every(Number.isFinite))return {ready:false,reason:'missing-custodian-position'};
  const center=entry.instance.transform?.positionM;
  if(!center||Math.hypot(point.c*worldScale-center[0],point.r*worldScale-center[2])>40)return {ready:false,reason:'custodian-too-far'};
  if(request.action==='open'){entry.setEntranceOpen(true);entry.setGateOpen(true);}
  else if(request.action==='close'){entry.setGateOpen(false);entry.setEntranceOpen(false);}
  return {ready:entry.doors.every(d=>d.fraction>=.95),reason:entry.doors.every(d=>d.fraction>=.95)?'open':'doors-moving-or-closed',instanceId:entry.instance.id};
 };
}
