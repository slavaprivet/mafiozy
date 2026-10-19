// Review-only addon; accepted source/world proposals are left byte-for-byte intact.
function replace(source,a,b){if(source.indexOf(a)<0||source.indexOf(a)!==source.lastIndexOf(a))throw Error('Employee return anchor changed: '+a.slice(0,70));return source.replace(a,b);}
export function employeeReturnControllerCandidate(source){
 const nl=source.includes('\r\n')?'\r\n':'\n';source=source.replace(/\r\n/g,'\n');
 source=replace(source,"  if(result.intent?.kind==='walk'&&owned(body)&&!sourceBusy(body,now)){",`  let returnMovement=null;
  if(typeof host.advanceEmployeeReturn==='function'){
   try{returnMovement=host.advanceEmployeeReturn({actor:body,now,dt,generation:state.generation,employeeId:employmentId,
    controlled:owned(body)&&!sourceBusy(body,now),returning:state.phase==='returning'&&result.intent?.kind==='walk',
    hasControl:()=>owned(body)&&!sourceBusy(body,now)&&yes(host.isCurrentSite,layout)});}catch{returnMovement={status:'hold',reason:'return-host-unavailable'};}
  }
  if(result.intent?.kind==='walk'&&owned(body)&&!sourceBusy(body,now)){`);
 source=replace(source,'const movement=advanceStationaryServiceActor(',"const movement=returnMovement||advanceStationaryServiceActor(");
 source=replace(source,'dispose(){disposed=true;',"dispose(){host.advanceEmployeeReturn?.dispose?.();disposed=true;");
 return nl==='\r\n'?source.replace(/\n/g,'\r\n'):source;
}
export const employeeReturnSourceHost23=String.raw`function _stationaryServiceReturnHost23(){
 return{
  entrance:layout=>{const access=_walkTrafficNavigationResolver({mode:'resident-access',action:'list'});return access?.doors?.find(d=>d.instanceId===layout.buildingId);},
  cancelRoute:n=>{_cancelNpcDirectedSearch(n);_clearNpcRoute(n);},
  planRoute:(n,p)=>{
   const ready=_planNpcRouteTo(n,p.r,p.c,_residentNativeRecoveryPass,.002,768,'building_entry');
   if(!ready)return{status:n._routeSearchPending?'pending':'blocked'};
   const points=n._route?.map(p=>({r:p.r,c:p.c}));_cancelNpcDirectedSearch(n);_clearNpcRoute(n);
   return{status:'ready',points};
  },
  openEntrance:(n,door)=>_walkTrafficNavigationResolver({mode:'resident-access',action:'open',doorId:door.id,from:{r:n.r,c:n.c}}),
  entryLane:(n,visit)=>_residentNativeEntryLane(n,visit)
 };
}
`;
export function employeeReturnWorldCandidate(source){
 const nl=source.includes('\r\n')?'\r\n':'\n';source=source.replace(/\r\n/g,'\n');
 source=replace(source,'function _installStationaryServicePilot23(factory,station,geometryHost){',employeeReturnSourceHost23+'function _installStationaryServicePilot23(factory,station,geometryHost){');
 source=replace(source,'const controller=factory({station,host:{...geometryHost,npcs:NPCS,spawnNpc,',`const returnHost={...geometryHost.employeeReturnGeometry,..._stationaryServiceReturnHost23()};
 let advanceEmployeeReturn=null;
 if(typeof geometryHost.createEmployeeReturn==='function')advanceEmployeeReturn=geometryHost.createEmployeeReturn({layout:station.layout,host:returnHost});
 const controller=factory({station,host:{...geometryHost,advanceEmployeeReturn,npcs:NPCS,spawnNpc,`);
 return nl==='\r\n'?source.replace(/\n/g,'\r\n'):source;
}
