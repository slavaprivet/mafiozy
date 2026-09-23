// Isolated candidate; world/Walk do not import this file.
// Depends on the separately reviewed full-footprint _nearestEmpireWalkPoint.
import {empireTargetFootprintCandidate23} from './npc_empire_target_footprint23_candidate.mjs';
export function refreshEmpireCachedTargets23() {
  if(typeof _walkNpcNavigationResolver!=='function')return 0;
  let changed=0;const now=performance.now();
  for(const n of SPECIALIST_NPCS){
    const action=n._empireAction,target=n._empireTarget,request=n._empirePendingRoute;
    // Only the autonomous startup patrol is owned by this repair. Native business
    // identity and authenticated server orders remain the coordinator's scope.
    if(!n._empireBoss||action?.kind!=='patrol'||String(action.target_id)!==`offline:${n._specialistId}`||
      !target||!Number.isFinite(target.r)||!Number.isFinite(target.c)||
      n.dead||n.alive===false||Number.isFinite(n.hp)&&n.hp<=0||n._hiddenByEmpire||
      n._hostile||n._fighting||n._fightingMelee||n._empirePlayerWar||n._empireEnemyLeaderId||n._empireCombatTarget||n._empireFieldEncounterStatus==='active'||n._policeCuffed||
      n.panicUntil>now||n._knockedUntil>now||n._meleeStunnedUntil>now||n._empireDownUntil>now||n._empireHospitalUntil>Date.now()||
      n._playerConversationOpen||n._empireStreetNegotiation||n._corpsePhoneCall||
      n._civilianTrip||n._civilianTripRiding||n._inVehicle||n._inCar||n.vehicleId||n.vehicle_id||
      n._responseVehicleId||n._civilianSeat||n._transportBoarded||n._ambientTrafficPhase==='drive'||n._vehicleHijackControlled||
      n._residentIndoors||n._interiorId||n.interior_id||n._insideBuilding||n._residentNativeVisit||
      n._medicalDowned||n._carriedByAmbulance||n._evacuated||
      request&&request.kind!=='empire_action'||n._routeKind&&n._routeKind!=='empire_action'||
      n._routeSearchKind&&n._routeSearchKind!=='empire_action')continue;
    if(request&&(request.generation!==( +n._empireRouteGeneration||0)||request.targetKey!==String(n._empireActionKey||'')))continue;
    if(_empireTargetFootprintPassable23(target.r,target.c))continue;
    const replacement=_nearestEmpireWalkPoint(target.r,target.c);
    if(!replacement||!_empireTargetFootprintPassable23(replacement.r,replacement.c))continue;
    const base=n._empireActivityBaseTarget;
    n._empireTarget=replacement;
    if(base&&base.r===target.r&&base.c===target.c)n._empireActivityBaseTarget=replacement;
    // Preserve shared scheduler position, active cohort and empire queue order.
    // Only this actor's old frontier/path is invalidated; the next normal slice
    // starts against the updated target with the same action generation.
    n._npcDirectedSearch=null;n._npcWanderSearch=null;n._routeSearchPending=false;
    n._routeSearchKind=null;n._routeRequestAt=null;_clearNpcRoute(n);
    if(request)n._empirePendingRoute={...request,goalR:replacement.r,goalC:replacement.c};
    n._empireActionArrived=false;n._empireArrivedGeneration=-1;
    n._empireRouteRetryAt=0;n._empireRouteExact=null;n.walking=false;
    _pauseEmpireMovementWatch(n);changed++;
  }
  return changed;
}

export function cachedTargetRegistration23(world){
  const line=world.split('\n').find(line=>line.trimStart().startsWith('registerWalkNpcNavigationResolver(resolver){'));
  if(!line)throw new Error('Missing actual navigation registration');
  const before='_walkNpcNavigationResolver=resolver;if(resolver)_npcInitialSafePlacement();';
  if(!line.includes(before))throw new Error('Unexpected navigation registration contract');
  const after='const changed=resolver!==_walkNpcNavigationResolver;_walkNpcNavigationResolver=resolver;if(resolver){_npcInitialSafePlacement();if(changed)refreshEmpireCachedTargets23();}';
  return line.trim().replace(before,after).replace(/,$/,'');
}

export function buildCachedTargetCandidate23(world){
  const start=world.indexOf('function _nearestEmpireWalkPoint('),end=world.indexOf('\n}',start)+2;
  if(start<0||end<2)throw new Error('Missing nearest-target function');
  const nearest=world.slice(start,end),registration=world.split('\n').find(line=>line.trimStart().startsWith('registerWalkNpcNavigationResolver(resolver){')).trim().replace(/,$/,'');
  return world.replace(nearest,empireTargetFootprintCandidate23(nearest)+'\n'+refreshEmpireCachedTargets23.toString()).replace(registration,cachedTargetRegistration23(world));
}
