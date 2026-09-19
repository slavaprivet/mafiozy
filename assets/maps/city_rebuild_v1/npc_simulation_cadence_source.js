// NPC_SIMULATION_CADENCE_START
// Distant ordinary residents retain their objects, routes and elapsed movement.
// Only expensive per-resident updates are staggered; world events still run.
const _npcSimulationStats={full:0,distant:0,deferred:0};
function _npcSimulationDelta(n,dt,now){
 if(!(dt>0)||!Number.isFinite(dt))return 0;
 const native=typeof _walkRendererActive==='function'&&_walkRendererActive();
 const important=n.dead||n.alive===false||Number.isFinite(n.hp)&&n.hp<=0||n._uniqueNpc||n._said||n._empireBoss||n._empireCrew||n._gang||n._guard||n._cashier||n._clientOfBiz||n._medicalCrewVehicleId||n._medicalDowned||n._forcedCrawl||n._civilianTrip||n._residentNativeVisit||n._civilianActivity?.phase==='approach'||n._waterEscaping||n._inVehicle||n._inCar||n._carriedByAmbulance||n._ambulanceInTransit||n._ambientTrafficDriver||n._vehicleHijackControlled||n._corpsePhoneCall||n._hijackReaction||n.snitching||n._hostile||n._fighting||n._fightingMelee||n._policeCuffed||n._playerConversationOpen||n._playerConversationUntil>now||n.panicUntil>now||n._knockedUntil>now||n._meleeStunnedUntil>now||n._burnUntil>now||n._routeSearchPending||n._npcWanderSearch||n._npcInitialPlacementPending;
 const dr=n.r-player.r,dc=n.c-player.c,total=(n._npcSimCarry||0)+dt;
 if(!native||important||dr*dr+dc*dc<=38*38){n._npcSimCarry=0;n._npcSimDue=0;_npcSimulationStats.full++;return important?dt:total;}
 if(!n._npcSimDue){let hash=2166136261;for(const ch of String(n.id||''))hash=Math.imul(hash^ch.charCodeAt(0),16777619)>>>0;hash=Math.imul(hash^(hash>>>16),2246822507)>>>0;n._npcSimDue=now+hash%250;}
 if(now<n._npcSimDue){n._npcSimCarry=total;_npcSimulationStats.deferred++;return 0;}
 n._npcSimCarry=0;n._npcSimDue+=Math.max(1,Math.floor((now-n._npcSimDue)/250)+1)*250;_npcSimulationStats.distant++;return total;
}
// NPC_SIMULATION_CADENCE_END
