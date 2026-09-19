// Source state/continuous-collision regression; actual model acceptance lives in
// the separate native lifecycle fixture. This is not a full-city FPS test.
import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';
const source=fs.readFileSync('world.html','utf8');
const fn=name=>{const start=source.indexOf('function '+name+'(');assert(start>=0,name);let p=source.indexOf('{',start),depth=1;for(p++;depth;p++){if(source[p]==='{')depth++;if(source[p]==='}')depth--;}return source.slice(start,p);};
let now=1000,open=false,wall=false;
const door={id:'native:shop',native:true,r:5,c:5,inside:{r:3.9,c:5}},n={id:'resident_17',hp:60,r:5,c:5,walkPhase:0,_civilianPlan:{cycle:0}},NPCS=[n];
const query=({r,c})=>({blocked:wall&&r<4.7&&r>4.2&&c>4.5&&c<5.5,depth:0});
const context={performance:{now:()=>now},Math,Number,NPCS,RESIDENTS_INDOORS:[],_walkNpcNavigationResolver:query,_walkTrafficNavigationResolver:()=>({ready:open}),_npcRouteWalkBlocked:(r,c)=>query({r,c}).blocked,npcPassable:()=>true,npcPassableForSnitch:()=>true,_npcEffectiveSpeed:()=>1,_civilianPlanUnit:()=>.25,pickNpcWaypoint(){},_openResidentDoorVisual(){}};
vm.createContext(context);for(const name of ['_clearNpcRoute','_npcBodyPassable','_npcPathPassable','_civilianPlanInterrupted','_residentNativePassable','_residentNativeVisitTick','_residentEnterBuilding'])vm.runInContext(fn(name),context);
assert(context._residentEnterBuilding(n,now,door));
// Normal animation may take time to open. Permanently unavailable doors now
// release an outside resident after 3 s (covered by visit_recovery18), so this
// verifies the ordinary wait before that failure deadline.
for(let i=0;i<20;i++){now+=100;context._residentNativeVisitTick(n,.1,now);}
assert.equal(n.r,5,'closed door does not allow elapsed-time entry');assert.equal(context.RESIDENTS_INDOORS.length,0);assert.equal(NPCS[0],n);
open=true;let phases=new Set();for(let i=0;i<160&&n._residentNativeVisit;i++){now+=100;const before={r:n.r,c:n.c};context._residentNativeVisitTick(n,.1,now);assert(Math.hypot(n.r-before.r,n.c-before.c)<=.100001);phases.add(n._residentNativeVisit?.phase);}
assert(phases.has('browsing')&&phases.has('exiting'));assert(!n._residentNativeVisit);assert(Math.abs(n.r-door.r)<.0251);assert.equal(n.hp,60);assert.equal(NPCS[0],n);assert.equal(context.RESIDENTS_INDOORS.length,0);
wall=true;context._residentEnterBuilding(n,now,door);for(let i=0;i<20&&n._residentNativeVisit;i++){now+=100;context._residentNativeVisitTick(n,.1,now);assert(n.r>=4.88,'capsule stops before thin obstruction');assert.notEqual(n._residentNativeVisit?.phase,'browsing');}
wall=false;for(let i=0;i<160&&n._residentNativeVisit;i++){now+=100;context._residentNativeVisitTick(n,.1,now);}
assert(!n._residentNativeVisit,'cleared short obstruction permits physical entry and exit');
wall=false;context._residentEnterBuilding(n,now,door);n.hp=0;n.dead=true;const deathR=n.r;assert.equal(context._residentNativeVisitTick(n,.1,now),false);assert.equal(n.r,deathR);assert.equal(n.hp,0);assert.equal(NPCS[0],n);
console.log('PASS source native visit: real door wait, continuous enter/stay/exit, capsule obstruction, unchanged NPC identity/HP, death interruption; no hiding or teleport');
