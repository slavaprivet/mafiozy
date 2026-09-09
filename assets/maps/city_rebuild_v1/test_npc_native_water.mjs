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
