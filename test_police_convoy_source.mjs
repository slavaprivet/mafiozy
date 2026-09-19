import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';import {performance} from 'node:perf_hooks';
const source=fs.readFileSync('world.html','utf8').replace(/\r\n/g,'\n');
function fn(n){const a=source.indexOf(`function ${n}(`);assert.ok(a>=0,n);return source.slice(a,source.indexOf('\n}',a)+2);}
let now=10000,routeCalls=0,passable=true,doorReady=false;const sent=[];
const driver={id:'driver',x:0,y:0,ang:0,alive:true,hp:100};const v={id:'v',x:0,y:0,ang:0,hp:100,_policePrisonTransport:true,_driverCopId:'driver'};
const ar={vehicleId:'v',phase:'transport',driverCopId:'driver',playerBoarded:true,playerAttachedVehicleId:'v'};
const dest={id:'real',nativeReady:true,stop:{r:3,c:4},handoff:{r:2,c:4},intake:{r:1,c:4},release:{r:2,c:5}};
const e={Math,Number,String,Boolean,performance:{now:()=>now},window:{},_walkTrafficNavigationResolver:()=>({ready:doorReady}),document:{documentElement:{dataset:{}}},_LOCAL_PREVIEW:true,_policeDetentionRegistry:[],_murderPoliceArrest:ar,cityCops:[driver],worldCops:[],serviceVehicles:[v],player:{r:0,c:0,ang:0,walkPhase:0},POLICE_RESPONSE_SPEED:6,_setVehicleRoute:()=>routeCalls++,ws:{readyState:1,send:p=>sent.push(JSON.parse(p))},_policeCrewSegmentPassable:()=>passable,_prisonEscortBodyPassable:()=>passable};
vm.createContext(e);for(const n of ['_policeConvoyDestination','_syncPoliceConvoyCop','_policeConvoyCanDrive','_policeConvoyAuthorityAction','_policeConvoyDoorsReady','_moveDetainedPlayer','_murderPoliceArrestInCustody','_murderPoliceVehicleOwnsCustody','_enforceMurderPoliceCustodyVehicle'])vm.runInContext(fn(n),e);
assert.equal(e._policeConvoyCanDrive(v,ar,now),false);assert.equal(ar.transportBlockedReason,'destination-unavailable');
e._policeDetentionRegistry=[dest];assert.equal(e._policeConvoyCanDrive(v,ar,now),true);assert.equal(routeCalls,0);assert.equal(ar.destinationId,'real');
driver.alive=false;assert.equal(e._policeConvoyCanDrive(v,ar,now),false);assert.equal(v.speed,0);assert.equal(ar.transportBlockedReason,'driver-or-vehicle-down');driver.alive=true;
driver._transportBoarded=true;driver._transportVehicleId='v';driver._transportSeatId='front_left';e._syncPoliceConvoyCop(driver);assert.equal(driver.alive,true);assert.equal(driver.walking,false);assert.equal(driver.y,.17);
e._LOCAL_PREVIEW=false;assert.equal(e._policeConvoyCanDrive(v,ar,now),false);ar.serverAccepted=true;ar.boardAccepted=true;ar.custodyId='custody';ar.custodyToken='token';assert.equal(e._policeConvoyCanDrive(v,ar,now),true);assert.equal(sent[0].d.action,'motion');now+=800;assert.equal(e._policeConvoyCanDrive(v,ar,now),false,'No autonomous driving while server admission timed out');
assert.equal(e._policeConvoyAuthorityAction(ar,'book','real'),false);assert.equal(sent.at(-1).d.action,'book');ar._authorityActions={book:true};assert.equal(e._policeConvoyAuthorityAction(ar,'book','real'),true);assert.equal(e._policeConvoyAuthorityAction(ar,'book','fake'),false);
assert.equal(e._policeConvoyDoorsReady(ar,now),false);doorReady=true;now+=250;assert.equal(e._policeConvoyDoorsReady(ar,now),true);
passable=false;const before={...e.player};e._moveDetainedPlayer(3,4,1);assert.equal(e.player.r,before.r);assert.equal(e.player.c,before.c,'Blocked escort never teleports');passable=true;e._moveDetainedPlayer(3,4,.1);assert.ok(Math.hypot(e.player.r,e.player.c)<.2);
assert.ok(!fn('_startMurderPolicePrisonTransport').includes('cop.alive=false'),'Boarding preserves actual driver identity/life');assert.ok(!fn('_updateMurderPolicePrisonHandoff').includes('phaseAt>26000'),'Timeout is not physical arrival');
e._LOCAL_PREVIEW=true;v.state='returning';delete ar._motionPending;ar._destinationRouted=true;
function bench(f){const a=[];for(let j=0;j<80;j++){const st=performance.now();for(let k=0;k<100;k++)f();a.push((performance.now()-st)/100);}a.sort((a,b)=>a-b);return {p50:a[40],p95:a[76]};}
const beforePerf=bench(()=>e._enforceMurderPoliceCustodyVehicle(v,now));const afterPerf=bench(()=>{e._enforceMurderPoliceCustodyVehicle(v,now);e._policeConvoyCanDrive(v,ar,now);});
console.log('PASS source convoy: driver death/identity, unavailable destination, real seats, server wait, authority booking, closed doors, blocked physical escort. CPU ms/update',JSON.stringify({before:beforePerf,after:afterPerf}));

e._LOCAL_PREVIEW=false;e.currentWeapon='pistol';driver.alive=true;driver.hp=77;driver._serverConvoyCopId='canonical';vm.runInContext(fn('hitCityCop'),e);e.hitCityCop(driver,0,1,100);assert.equal(driver.hp,77,'Authoritative driver cannot be killed by local HP claim');assert.equal(sent.at(-1).t,'cop_shoot');assert.equal(sent.at(-1).d.target,'canonical');console.log('PASS alias ordinary cop_shoot, no local HP mutation');

e._LOCAL_PREVIEW=true;ar.voluntary=true;ar.playerBoarded=true;ar.phase='transport';e._murderPoliceArrest=ar;vm.runInContext(fn('_tickVoluntarySurrender'),e);assert.equal(e._tickVoluntarySurrender(.1,now),true);assert.equal(ar.phase,'transport','Voluntary holding logic cannot overwrite boarded transport');console.log('PASS voluntary surrender respects boarded convoy owner');
