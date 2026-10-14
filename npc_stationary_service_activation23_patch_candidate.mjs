// Composes accepted source/customer/return proposals. No filesystem writes.
export const serviceMerchantSource23=String.raw`function _installStationaryServiceMerchant23(factory,station,geometryHost,createProvider){
 if(typeof createProvider!=='function'||typeof geometryHost?.canPresentServiceActor!=='function')return null;
 let bundle=null,remove=null,disposed=false;
 const hold=()=>({status:'hold',reason:'service-provider-not-ready'});
 const registration=_installStationaryServicePilot23(factory,station,{...geometryHost,
  ownsServiceSlot:q=>bundle?.provider?.ownsServiceSlot(q)===true,
  advanceServiceExit:input=>bundle?.exitMovement?.(input)||hold()});
 if(!registration)return null;
 const source=Object.freeze({
  entityId:n=>_threeNpcEntityId(n),identity:n=>({id:String(n.id),generation:1}),
  now:()=>performance.now(),currentVisit:n=>n._residentNativeVisit,isPresent:n=>NPCS.includes(n),
  entranceInside:()=>_walkTrafficNavigationResolver({mode:'resident-access',action:'list'})?.doors?.find(d=>d.instanceId===station.layout.buildingId)?.inside,
  canControl:(n,visit,now)=>NPCS.includes(n)&&n._residentNativeVisit===visit&&!n.dead&&!_civilianPlanInterrupted(n,now)&&!n._vehicleHijackControlled&&!n._civilianTripRiding&&!n._ambulanceInTransit&&!n._playerConversationOpen&&!(n._playerConversationUntil>now)
 });
 try{
  bundle=createProvider({controller:registration.controller,source});
  if(typeof bundle?.exitMovement!=='function'||typeof bundle?.provider?.ownsServiceSlot!=='function')throw Error('Service lease/exit bundle required');
  remove=_residentCommerceRegisterService(station.layout.buildingId,bundle.provider);
 }catch(error){bundle?.provider?.disposeServiceVisits?.();registration.unregister();throw error;}
 return{controller:registration.controller,unregister(){if(disposed)return false;disposed=true;remove?.();bundle.provider.disposeServiceVisits?.();registration.unregister();return true;}};
}
`;
export const serviceVisitInterruption23=String.raw`function _residentServiceYield23(n,visit,now){
 const route=visit?._serviceRoute23;if(!route)return false;
 const interrupted=_civilianPlanInterrupted(n,now)||n._vehicleHijackControlled||n._civilianTripRiding||n._ambulanceInTransit||n._playerConversationOpen||n._playerConversationUntil>now;
 if(interrupted){
  visit.phase='exiting';route.suspended23=true;route.blockedAt=null;
  const registration=_residentCommerceServiceProviders.get(visit.door.instanceId||visit.door.id);
  if(registration?.token===route.registration)try{registration.provider.releaseServiceVisit?.({npc:n,visit,now});}catch{}
  if(visit.commerce&&!visit.commerce.settled&&typeof _residentCommerceTick==='function')_residentCommerceTick(n,visit,now);
  n._residentVisitStatus='service-interrupted';return true;
 }
 if(route.suspended23){route.suspended23=false;route.blockedAt=null;visit.blockedAt=0;visit.accessWaitAt=null;}
 return false;
}
`;
export function serviceMerchantWorldCandidate(input){
 const nl=input.includes('\r\n')?'\r\n':'\n';let source=input.replace(/\r\n/g,'\n');
 const replace=(a,b)=>{if(source.indexOf(a)<0||source.indexOf(a)!==source.lastIndexOf(a))throw Error('Merchant activation anchor changed: '+a.slice(0,80));source=source.replace(a,b);};
 replace('function _residentNativeVisitTick(n,dt,now){',serviceVisitInterruption23+'function _residentNativeVisitTick(n,dt,now){');
 replace("  if(_civilianPlanInterrupted(n,now)&&visit.phase!=='exiting'){visit.phase='exiting';visit.blockedAt=0;}","  if(_residentServiceYield23(n,visit,now))return false;\n  if(_civilianPlanInterrupted(n,now)&&visit.phase!=='exiting'){visit.phase='exiting';visit.blockedAt=0;}");
 replace('window.Mafiozi3DBridge = Object.freeze({',serviceMerchantSource23+'window.Mafiozi3DBridge = Object.freeze({\n  installStationaryServiceMerchant23(factory,station,geometryHost,createProvider){return _installStationaryServiceMerchant23(factory,station,geometryHost,createProvider);},');
 replace('canControl:(n,now)=>!_civilianPlanInterrupted(n,now)',"canControl:(n,now)=>(typeof geometryHost.canPresentServiceActor!=='function'||geometryHost.canPresentServiceActor(n)===true)&&!_civilianPlanInterrupted(n,now)");
 replace('    const npcLifePool=x=>{',"    const npcLifePool=x=>{\n      if(_stationaryServicePilot23?.owns(x))return 'mission';");
 // One owned pilot body sorts before other mission candidates, within the
 // existing total cap. A role marker alone grants no rendering priority.
 replace('const driverOrder=Number(!!(b.source._ambientTrafficDriver||b.source._civilianTripRiding))-Number(!!(a.source._ambientTrafficDriver||a.source._civilianTripRiding));',
 "const serviceOrder=Number(_stationaryServicePilot23?.owns(b.source)===true)-Number(_stationaryServicePilot23?.owns(a.source)===true);if(serviceOrder)return serviceOrder;const driverOrder=Number(!!(b.source._ambientTrafficDriver||b.source._civilianTripRiding))-Number(!!(a.source._ambientTrafficDriver||a.source._civilianTripRiding));");
 return nl==='\r\n'?source.replace(/\n/g,'\r\n'):source;
}
export function serviceMerchantControllerCandidate(input){
 const anchor='station.update(dt,nearby);';if(input.indexOf(anchor)<0||input.indexOf(anchor)!==input.lastIndexOf(anchor))throw Error('Service door update anchor changed');
 return input.replace(anchor,'if(station.update(dt,nearby))host.onServiceDoorChanged?.();');
}
export const serviceMerchantWalkHost23=String.raw`let stationaryServiceWalk23=null,servicePilotBridge23=null,servicePilotAttempt23=0;
function ensureStationaryServiceWalk23(){
 if(stationaryServiceWalk23&&servicePilotBridge23!==npcBridge){stationaryServiceWalk23.dispose();stationaryServiceWalk23=null;}
 if(stationaryServiceWalk23||busy||!npcPopulation||!hero||!npcBridge||!npcNativeNavigation||!walkCollisionIndex||performance.now()<servicePilotAttempt23)return;
 if(!buildingEntries.some(e=>e.instance?.id==='REBUILD-VISUAL-print_shop-001'))return;
 servicePilotAttempt23=performance.now()+1000;servicePilotBridge23=npcBridge;
 try{
  stationaryServiceWalk23=createStationaryServiceWalk23({THREE,bridge:npcBridge,siteRevision:String(revision)+':service23:'+buildingCameraIndexGeneration,host:{
   ready:()=>!busy&&!!hero&&!!npcPopulation&&!!walkCollisionIndex&&npcBridge===servicePilotBridge23,
   getEntries:()=>buildingEntries,getCollisionIndex:()=>walkCollisionIndex,invalidateNavigation:()=>npcNativeNavigation?.beginFrame(),nativeQuery:request=>npcNativeNavigation?.query(request),
   groundHeight,ceilingHeight,waterAt,getCamera:()=>camera,getHero:()=>hero,
   heroBody:()=>({radius:worldHealthFrame?.snapshot.dead||heroBlast||artistSurface?.state.kind==='prone'?2.5:.18*M,height:Math.max(1.9,postureMotion?.height||hero.height||1.9)}),
   getNpcActors:()=>npcPopulation.getActors(),getNpcActor:id=>npcPopulation.getActor(id),getFleet:()=>fleet?.records||[],getTrafficActors:()=>worldTrafficPresentation?.getActors()||[]
  }});
  document.body.dataset.stationaryService23=stationaryServiceWalk23?'printshop-active':'waiting-for-source-hooks';
  window.MafioziStationaryService23=Object.freeze({inspect:()=>stationaryServiceWalk23?.diagnostics()||null});
 }catch(error){document.body.dataset.stationaryService23='hold:'+String(error.message).slice(0,160);}
}
`;
export function serviceMerchantWalkCandidate(input){
 const nl=input.includes('\r\n')?'\r\n':'\n';let source=input.replace(/\r\n/g,'\n');
 const replace=(a,b)=>{if(source.indexOf(a)<0||source.indexOf(a)!==source.lastIndexOf(a))throw Error('Walk service anchor changed: '+a.slice(0,80));source=source.replace(a,b);};
 source="import {createStationaryServiceWalk23} from './service_pilot23_candidate/walk_host.mjs';\n"+source;
 replace('function updateNpcPopulation(dt){',serviceMerchantWalkHost23+'function updateNpcPopulation(dt){\n ensureStationaryServiceWalk23();');
 replace(' updateWalkEntryCollisionGroups(walkCollisionIndex,entryBodyVersions,buildingEntries,dt,hero?.object.position);',' updateWalkEntryCollisionGroups(walkCollisionIndex,entryBodyVersions,buildingEntries,dt,hero?.object.position);\n stationaryServiceWalk23?.syncCollision();');
 replace('function clearContent({recreate=true}={}){','function clearContent({recreate=true}={}){stationaryServiceWalk23?.dispose();stationaryServiceWalk23=null;servicePilotAttempt23=0;');
 return nl==='\r\n'?source.replace(/\n/g,'\r\n'):source;
}
