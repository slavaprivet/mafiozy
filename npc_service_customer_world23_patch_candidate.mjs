// Review-only customer world delta, applied on top of the employee world proposal.
export const customerServiceHelpers23=String.raw`let _residentServiceVisitSerial23=0;
function _residentServiceBeginApproach23(n,visit,now){
 const registration=_residentCommerceServiceProviders.get(visit.door.instanceId||visit.door.id);
 if(!registration||typeof registration.provider.getServiceArrivalTarget!=='function')return false;
 visit.id??='service-visit:'+n.id+':'+(++_residentServiceVisitSerial23);
 visit._serviceRoute23={registration:registration.token,started:now,stage:'await',lastReached:0,index:1,points:null,blockedAt:null};
 visit.phase='service-approach';n._residentVisitStatus='waiting-for-seller';return true;
}
function _residentServiceRouteTick23(n,visit,dt,now){
 const route=visit._serviceRoute23;if(!route)return null;
 const registration=_residentCommerceServiceProviders.get(visit.door.instanceId||visit.door.id),provider=registration?.token===route.registration?registration.provider:null,input={npc:n,visit,now};
 const release=()=>{try{provider?.releaseServiceVisit?.(input);}catch{};delete visit._serviceRoute23;};
 const recover=()=>{release();visit.phase='exiting';visit.recovering=true;n.walking=false;n._residentVisitStatus='service-exit-recovery';return true;};
 if(!provider&&(!route.points||typeof _stationaryServiceExitMove23!=='function'))return recover();
 if(!provider)visit.phase='exiting';
 if(route.stage==='await'){
  if(visit.phase==='exiting'||now-route.started>=3000){visit.serviceExitAlignment={r:visit.door.r,c:visit.door.c};release();visit.phase='exiting';return null;}
  try{
   if(provider.acquireServiceVisit?.(input)!==true){n.walking=false;return true;}
   const arrival=_residentCommerceArrivalTarget(n,visit,now),certificate=provider.getServiceRoute?.(input),points=certificate?.points;
   if(!arrival||certificate?.stamp!==arrival.stamp||!Array.isArray(points)||points.length!==3||points.some(p=>!p||![p.r,p.c,p.y].every(Number.isFinite)))return recover();
   if(points[0].r!==visit.door.inside.r||points[0].c!==visit.door.inside.c||points[2].r!==arrival.r||points[2].c!==arrival.c||points[2].y!==arrival.y)return recover();
   if(certificate.visitId!==visit.id||certificate.buildingId!==(visit.door.instanceId||visit.door.id)||typeof certificate.siteRevision!=='string'||certificate.customerId!==String(n.id)||!Number.isSafeInteger(certificate.generation)||certificate.generation<1)return recover();
   route.certificate=certificate;route.visitId=certificate.visitId;route.points=points.map(p=>({r:p.r,c:p.c,y:p.y}));route.stamp=arrival.stamp;route.buildingId=certificate.buildingId;route.siteRevision=certificate.siteRevision;route.customerId=certificate.customerId;route.generation=certificate.generation;route.stage='approach';
  }catch{return recover();}
 }
 if(visit.phase!=='exiting')try{
  if(provider.touchServiceVisit?.(input)!==true)visit.phase='exiting';
  const arrival=_residentCommerceArrivalTarget(n,visit,now);if(!arrival||arrival.stamp!==route.stamp)visit.phase='exiting';
 }catch{visit.phase='exiting';}
 if(now-route.started>20000&&visit.phase!=='exiting')visit.phase='exiting';
 if(visit.phase==='exiting'&&route.stage!=='reverse'){route.stage='reverse';route.index=Math.min(1,route.lastReached);route.blockedAt=null;}
 if(route.stage==='at-counter')return null;
 const target=route.points[route.index];let moved;
 try{moved=route.stage==='reverse'?_stationaryServiceExitMove23?.({...input,dt,target}):provider.advanceServiceVisit?.({...input,dt,target});}catch{return recover();}
 if(!moved||!['moving','arrived','blocked','hold'].includes(moved.status))return recover();
 if(moved.status==='blocked'||moved.status==='hold'){
  route.blockedAt??=now;n.walking=false;
  if(now-route.blockedAt>=3000)return recover();
  return true;
 }
 route.blockedAt=null;
 n._residentVisitStatus=route.stage==='reverse'?'leaving-counter':'approaching-counter';
 if(moved.status!=='arrived')return true;
 if(route.stage==='reverse'){
  if(route.index>0){route.index--;return true;}
  visit.serviceExitAlignment={r:visit.door.r,c:visit.door.c};release();visit.phase='exiting';n._residentVisitStatus='leaving-building';return true;
 }
 route.lastReached=route.index;
 if(++route.index<route.points.length)return true;
 route.stage='at-counter';visit.phase='browsing';visit.since=now;visit.until=now+3700;visit.lookAngle=n.ang||0;
 n._civilianPlan.phase='browsing';n._residentVisitStatus='visiting';
 if(!_residentCommerceArrive(n,visit,now))visit.until=now;
 return true;
}
`;
export function serviceCustomerWorldCandidate(source){
 const newline=source.includes('\r\n')?'\r\n':'\n';source=source.replace(/\r\n/g,'\n');
 const replaceOnce=(a,b)=>{if(source.indexOf(a)<0||source.indexOf(a)!==source.lastIndexOf(a))throw Error('Customer source anchor changed: '+a.slice(0,90));source=source.replace(a,b);};
 replaceOnce('let _stationaryServicePilot23=null;', 'let _stationaryServicePilot23=null,_stationaryServiceExitMove23=null;');
 replaceOnce(' _stationaryServicePilot23=controller;', " _stationaryServicePilot23=controller;_stationaryServiceExitMove23=typeof geometryHost.advanceServiceExit==='function'?geometryHost.advanceServiceExit:null;");
 replaceOnce('_stationaryServicePilot23=null;controller.dispose();', '_stationaryServicePilot23=null;_stationaryServiceExitMove23=null;controller.dispose();');
 replaceOnce('function _residentNativeVisitTick(n,dt,now){',customerServiceHelpers23+'function _residentNativeVisitTick(n,dt,now){');
 replaceOnce("      if(visit.entryAlignment){visit.entryAlignment=null;return true;}\n      visit.phase='browsing';", "      if(visit.entryAlignment){visit.entryAlignment=null;return true;}\n      if(_residentServiceBeginApproach23(n,visit,now))return true;\n      visit.phase='browsing';");
 replaceOnce("    if(now<visit.until){n.walking=false;n.ang=visit.lookAngle", "    if(visit._serviceRoute23&&visit.commerce?.phase==='cancelled')visit.until=now;\n    if(now<visit.until){n.walking=false;n.ang=visit.lookAngle");
 replaceOnce('  const target=visit.phase===\'entering\'?(visit.entryAlignment||door.inside):(visit.returnPoint||door);',
 "  const serviceTick=_residentServiceRouteTick23(n,visit,dt,now);if(serviceTick!==null)return serviceTick;\n  const target=visit.phase==='entering'?(visit.entryAlignment||door.inside):(visit.serviceExitAlignment||visit.returnPoint||door);");
 replaceOnce("    }else{\n      n._residentNativeVisit=null;n._residentVisitStatus='visit-complete';", "    }else{\n      if(visit.serviceExitAlignment){delete visit.serviceExitAlignment;return true;}\n      n._residentNativeVisit=null;n._residentVisitStatus='visit-complete';");
 replaceOnce('  const simulationFrameDt=dt;', '  _stationaryServicePilot23?.tick(now,0);\n  const simulationFrameDt=dt;');
 return newline==='\r\n'?source.replace(/\n/g,'\r\n'):source;
}
