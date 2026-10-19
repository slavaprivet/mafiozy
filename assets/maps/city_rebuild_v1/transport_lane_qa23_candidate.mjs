// Candidate text transforms only. This module is not imported by game runtime.
function replaceOnce(text,before,after){
 if(text.split(before).length!==2)throw new Error('Candidate anchor missing/nonunique: '+before.slice(0,100));
 return text.replace(before,after);
}
export const qaSource=`
// QA-only first lane rejection per request; independent of gameplay/job state.
const _civilianLaneQaOn=(()=>{let search='';try{search=typeof location!=='undefined'?location.search:'';if(typeof window!=='undefined'&&window.parent!==window)search+='&'+(window.parent?.location?.search||'');}catch{}return /(?:^|[?&])(?:npcqa|npctransportqa)=1(?:&|$)/.test(search);})();
const _civilianLaneQaHistory=_civilianLaneQaOn?[]:null,_civilianLaneQaRecorded=_civilianLaneQaOn?new WeakMap():null;
function _civilianTripLaneRejectionQa(car,trip,job,from,to,result,now){
 if(!_civilianLaneQaOn||result?.status!=='blocked'||!job.laneRequestId||_civilianLaneQaRecorded.get(job)===job.laneRequestId)return;
 // These replies still mean wait in the actual producer, until its30s limit.
 if(['route_queue_full','route_worker_uninitialized','async_routing_unavailable'].includes(result.reason)&&now-job.createdAt<30000)return;
 const copyPose=p=>p?{r:Number.isFinite(p.r)?p.r:null,c:Number.isFinite(p.c)?p.c:null,angle:Number.isFinite(p.angle)?p.angle:null}:null;
 const profile=result.qaLaneShape,shape=profile?{halfLength:profile.halfLength,halfWidth:profile.halfWidth,collisionPadding:profile.collisionPadding,...(profile.collisionHull?{collisionHull:profile.collisionHull.map(p=>p.slice())}:{})}:null;
 const record={carId:String(_threeVehicleEntityId(car)),npcId:trip?.npc?String(_threeNpcEntityId(trip.npc)):null,requestId:String(job.laneRequestId),sourceClockMs:Number.isFinite(now)?now:null,from:copyPose(from),to:to?{...copyPose(to),id:typeof to.id==='string'?to.id:null,buildingId:typeof to.buildingId==='string'?to.buildingId:null}:null,shape,shapeUnits:'metres',status:result.status,reason:typeof result.reason==='string'?result.reason:null,allowedLotIds:Array.isArray(to?.lotIds)?to.lotIds.slice():null};
 _civilianLaneQaRecorded.set(job,job.laneRequestId);_civilianLaneQaHistory.push(record);if(_civilianLaneQaHistory.length>16)_civilianLaneQaHistory.shift();
 document.documentElement.dataset.civilianLaneRejections=JSON.stringify({version:1,scope:'first-terminal-lane-rejection-per-request',records:_civilianLaneQaHistory});
}
`;
export function patchCivilian(raw){
 let text=raw.replace(/\r\n/g,'\n');
 text=replaceOnce(text,'function _civilianTripPlanTrace(',qaSource+'\nfunction _civilianTripPlanTrace(');
 text=replaceOnce(text,"const lane=nav({mode:'lane-route',requestId:job.laneRequestId,carId,from,to:job.laneTo,maxSnapDistance:12});","const laneRequest={mode:'lane-route',requestId:job.laneRequestId,carId,from,to:job.laneTo,maxSnapDistance:12};if(_civilianLaneQaOn)laneRequest.qaLaneShape=true;\n  const lane=nav(laneRequest);if(_civilianLaneQaOn)_civilianTripLaneRejectionQa(car,trip,job,from,job.laneTo,lane,now);");
 return text;
}
export function patchNavigation(raw){
 let text=raw.replace(/\r\n/g,'\n');
 text=replaceOnce(text,"return routeJobs?.query({...request,vehicleProfile})||{ready:false,status:'blocked',reason:'async_routing_unavailable',points:[]};",`// Diagnostic request flag never enters the worker request/signature.
   let laneRequest=request;if(request.qaLaneShape===true){const {qaLaneShape,...plain}=request;laneRequest=plain;}
   const result=routeJobs?.query({...laneRequest,vehicleProfile})||{ready:false,status:'blocked',reason:'async_routing_unavailable',points:[]};
   if(request.qaLaneShape!==true||result.status!=='blocked')return result;
   return {...result,qaLaneShape:{halfLength:vehicleProfile.halfLength,halfWidth:vehicleProfile.halfWidth,collisionPadding:Number.isFinite(vehicleProfile.collisionPadding)?vehicleProfile.collisionPadding:0,...(vehicleProfile.collisionHull?{collisionHull:vehicleProfile.collisionHull.map(p=>p.slice())}:{})}};`);
 return text;
}
export function patchExport(raw){
 let text=raw.replace(/\r\n/g,'\n');
 text=replaceOnce(text,'routeReplay=null,npcWorld=null,time=0','routeReplay=null,npcWorld=null,civilianLaneRejections=null,time=0');
 text=replaceOnce(text,'npcWorld:inspectionJson(npcWorld),limitations:','npcWorld:inspectionJson(npcWorld),...(civilianLaneRejections?{civilianLaneRejections:inspectionJson(civilianLaneRejections)}:{}),limitations:');
 return text;
}
export function patchInspection(raw){
 let text=raw.replace(/\r\n/g,'\n');
 text=replaceOnce(text,"if(new URLSearchParams(search).get('npcqa')!=='1')", "if(!['npcqa','npctransportqa'].some(key=>new URLSearchParams(search).get(key)==='1'))");
 text=replaceOnce(text,'npcWorld:datasetJson(doc.body?.dataset?.npcWorld)}','npcWorld:datasetJson(doc.body?.dataset?.npcWorld),civilianLaneRejections:datasetJson(doc.documentElement?.dataset?.civilianLaneRejections)}');
 return text;
}
export function patchWorld(raw){
 const text=raw.replace(/\r\n/g,'\n'),start=text.indexOf('// CIVILIAN_PARKING_TRIP_START'),end=text.indexOf('// CIVILIAN_PARKING_TRIP_END',start)+'// CIVILIAN_PARKING_TRIP_END'.length;
 if(start<0||end<=start)throw Error('World transport block missing');
 return text.slice(0,start)+patchCivilian(text.slice(start,end))+text.slice(end);
}
