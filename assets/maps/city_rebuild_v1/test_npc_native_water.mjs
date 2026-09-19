import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';
const world=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8'),fragment=fs.readFileSync(new URL('./npc_native_water_source.js',import.meta.url),'utf8'),names=['npcPassable','npcPassableForSnitch','npcWaypointOk','_npcBodyPassable','_npcPathPassable','_clearNpcRoute','_setNpcRoute','_planNpcRouteTo','_recoverNpcFromCollision'];
const functions=names.map(name=>world.match(new RegExp('^function '+name+'\\([^]*?^}','m'))?.[0]);assert(functions.every(Boolean));
const routeBudget=world.slice(world.indexOf('let _npcRouteWorkFrame='),world.indexOf('function _planNpcRouteTo('));assert(routeBudget.includes('function _npcReserveRouteWork'));
let simulationTime=0;const MAP=Array.from({length:24},()=>Array(24).fill(9)),box={MAP,MAP_ROWS:24,MAP_COLS:24,isBlockedPed:()=>false,_inPrisonIslandRestrictedZone:()=>false,inArena:()=>false,inLair:()=>false,_cityV3NextSurfaceAt:()=>false,_inPitCorridor:()=>false,_npcEffectiveSpeed:()=>1,_uniqueNpcCityPassable:()=>true,performance:{now:()=>simulationTime}};vm.createContext(box);
vm.runInContext(fragment+'\n'+routeBudget+'\n'+functions.join('\n')+'\n globalThis.api={pass:npcPassable,waypoint:npcWaypointOk,path:_npcPathPassable,plan:_planNpcRouteTo,escape:_npcWaterEscape,recover:_recoverNpcFromCollision,set(fn){_walkNpcNavigationResolver=fn;}};',box);const a=box.api;
const navigation=({r,c})=>({depth:r>=7&&r<=12&&c>=7&&c<=12?Math.min(r-7,12-r,c-7,12-c)+.1:0,blocked:r>3&&r<5&&c>8&&c<10});a.set(navigation);
assert(!a.pass(9,9),'native lake blocks old MAP9 pavement');assert(!a.waypoint({},9,9),'no watery target');assert(!a.pass(4,9),'native building/car solid blocks old MAP9');assert(!a.path(4,7,4,11,()=>true),'custom/prison pass cannot bypass native solids');assert(!a.waypoint({_uniqueNpc:true},9,9),'unique source shortcut cannot bypass native water');assert(!a.path(9,5,9,14),'sweep cannot cross lake despite dry endpoint');
const n={id:'resident',r:9.5,c:5.5};assert(a.plan(n,9.5,14.5,box.npcPassable,.1,1200,'water-detour'));assert(n._route.length);assert(n._route.every(p=>navigation(p).depth===0&&!navigation(p).blocked));assert(n._route.some(p=>p.r<7||p.r>12),'route goes around actual shore');
const wet={id:'already-wet',r:9,c:9};const original={r:wet.r,c:wet.c};assert(!a.recover(wet));assert.deepEqual({r:wet.r,c:wet.c},original,'registration/recovery never teleports wet NPC');
for(let i=0;i<700&&navigation(wet).depth>.025;i++){simulationTime=i*50;const before={r:wet.r,c:wet.c},depth=navigation(wet).depth;a.escape(wet,.05,i*50);assert(Math.hypot(wet.r-before.r,wet.c-before.c)<=.05+1e-9);assert(navigation(wet).depth<=depth+.002);assert(!navigation(wet).blocked);}
assert(navigation(wet).depth<=.025,'existing wet NPC physically returns to shore');
MAP[18][18]=16;a.set(null);assert(!a.pass(18.5,18.5),'legacy source water remains blocked');a.set(()=>({depth:0,blocked:false}));assert(a.pass(9,9),'dry support over native water can be reported by bridge');
console.log('PASS actual source pathfinder: native water/solids override old pavement, dry targets, swept crossing refusal, shoreline detour, physical egress/no teleport, legacy fallback');

// Force tiny search slices to verify that a wet actor's candidate scan resumes.
a.set(({r,c})=>({blocked:false,depth:r>=7&&r<=12&&c>=7&&c<=12?1:0}));let workChecks=0;box._npcReserveRouteWork=()=>true;box._npcRouteWorkExpired=()=>++workChecks>6;
const sliced={id:'sliced-water',r:9,c:9,walkPhase:0};let resumed=false,sliceCount=0;
for(;sliceCount<500&&!sliced._waterEscapeTarget;sliceCount++){workChecks=0;a.escape(sliced,.016,simulationTime+=50);if(sliced._waterEscapeSearch)resumed=true;}
assert(resumed&&sliceCount>1&&sliced._waterEscapeTarget,'candidate and segment search resumes after shared budget exhaustion');assert(Math.hypot(sliced.r-9,sliced.c-9)<.02,'search never relocates the wet actor');console.log('PASS water search shared-budget resume after '+sliceCount+' slices');

// Real legacy water and road tile rules, not only old grass under native water.
for(let r=1;r<23;r++)for(let c=1;c<23;c++)MAP[r][c]=(r>=7&&r<=11&&c>=7&&c<=11)?16:0;
const mixedNav=({r,c})=>({blocked:false,depth:r>=7&&r<12&&c>=7&&c<12?Math.min(r-7,12-r,c-7,12-c)+.1:0});
a.set(mixedNav);box._npcReserveRouteWork=()=>true;box._npcRouteWorkExpired=()=>false;
const legacyWet={id:'legacy-water-road-egress',r:9,c:9,walkPhase:0};
for(let i=0;i<900&&mixedNav(legacyWet).depth>.025;i++){const before={r:legacyWet.r,c:legacyWet.c},depth=mixedNav(legacyWet).depth;a.escape(legacyWet,.05,simulationTime+=50);assert(Math.hypot(legacyWet.r-before.r,legacyWet.c-before.c)<=.05+1e-9);assert(mixedNav(legacyWet).depth<=depth+.002);}
assert.equal(mixedNav(legacyWet).depth,0,'MAP16 water can physically reach MAP0 shore');
vm.runInContext('globalThis.egressPath=_npcWaterEgressPath;',box);
a.set(({r,c})=>({depth:1,blocked:r>8.7&&r<9.3}));
assert.equal(box.egressPath({r:8,c:9},10,9),false,'water egress still cannot pass native solid');
a.set(({r})=>({depth:r-7,blocked:false}));
assert.equal(box.egressPath({r:8,c:9},9,9),false,'water egress never allows a deeper path');
console.log('PASS physical egress across legacy MAP16/MAP0, monotonic depth, native solid refusal');

// The actual generic helper must now rescue special local actors without
// rewriting their distinct mission/order objects or enabling ordinary water paths.
a.set(mixedNav);let pauses=0;box._pauseEmpireMovementWatch=()=>pauses++;
for(const flag of ['_uniqueNpc','_said','_empireBoss','_empireCrew','_gang','_guard']){
 const order={target:'owned-building',role:flag},special={id:flag,r:9,c:9,[flag]:true,walkPhase:0,_empireAction:order,_empireActionKey:'keep-me'};
 for(let i=0;i<900&&mixedNav(special).depth>.025;i++){const r=special.r,c=special.c,depth=mixedNav(special).depth;a.escape(special,.05,simulationTime+=50);assert(Math.hypot(special.r-r,special.c-c)<=.05+1e-9);assert(mixedNav(special).depth<=depth+.002);assert.equal(special._empireAction,order);assert.equal(special._empireActionKey,'keep-me');assert(Number.isFinite(special.walkPhase));}
 assert.equal(mixedNav(special).depth,0,flag+' reaches dry shore');assert(!a.waypoint(special,9,9),flag+' still cannot choose water as ordinary route');
}
assert(pauses>0,'special stuck-route watch paused during water escape');
for(const flags of [{dead:true},{alive:false},{_medicalDowned:true},{_policeCuffed:true},{_civilianTripRiding:true},{_residentIndoors:true},{_inVehicle:true},{_empireDownUntil:Infinity},{_empireHospitalUntil:Infinity},{_meleeStunnedUntil:Infinity},{_carriedByAmbulance:true}]){
 const person={id:'protected',r:9,c:9,_empireBoss:true,...flags};assert(!a.escape(person,.1,simulationTime));assert.equal(person.r,9);assert.equal(person.c,9);
}
vm.runInContext('globalThis.policeEscape=_npcPoliceWaterEscape;',box);box._clearPoliceFootRoute=cop=>{cop._policeFootRoute=null};
const cop={id:'citycop-water',alive:true,y:9,x:9,tx:20,ty:20,_casePhase:'search',_responseVehicleId:'same-source-response',_policeFootRoute:[{r:20,c:20}]};
for(let i=0;i<900&&mixedNav({r:cop.y,c:cop.x}).depth>.025;i++){const y=cop.y,x=cop.x;box.policeEscape(cop,.05,simulationTime+=50);assert(Math.hypot(cop.y-y,cop.x-x)<=.05+1e-9);assert(!Object.hasOwn(cop,'r'));assert(!Object.hasOwn(cop,'c'));assert.equal(cop.tx,20);assert.equal(cop.ty,20);assert.equal(cop._casePhase,'search');assert.equal(cop._responseVehicleId,'same-source-response');}
assert.equal(mixedNav({r:cop.y,c:cop.x}).depth,0,'local cop physically swims to shore');box.policeEscape(cop,.05,simulationTime);assert.equal(cop._policeFootRoute,null);
for(const phase of ['arrest_escort','boarding','return','disembark']){cop._casePhase=phase;cop.y=cop.x=9;assert(!box.policeEscape(cop,.1,simulationTime));assert.equal(cop.y,9);assert.equal(cop.x,9);}
const liveHook=world.indexOf('if(_npcPoliceWaterEscape(cop,dt,now))continue;');assert(liveHook>world.indexOf('function updateCityCops(')&&liveHook<world.indexOf("if(!String(cop._casePhase||'').startsWith('arrest_'))_recoverPoliceFootCop(cop);"),'physical water handling precedes old position recovery');
const {normalizeNpcSnapshot}=await import('./npc_population.mjs');
for(const role of ['boss','gang_member','guard','police']){const snap=normalizeNpcSnapshot({id:role,r:9,c:9,role,police:role==='police',walking:true},{time:1,waterAt:()=>({level:1.6,depth:1.6})});assert(snap.inWater&&snap.waterLevel>snap.chestWorldY,'actual snapshot signals deep swim for '+role);}
console.log('PASS special local actor and police shore return, no teleport/identity/order rewrite, protected custody/death/interior/vehicle phases, actual deep-water snapshots');
