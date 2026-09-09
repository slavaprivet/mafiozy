import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';
const s=fs.readFileSync('world.html','utf8');function fn(name){const a=s.indexOf('function '+name+'('),b=s.indexOf('\nfunction ',a+1);assert(a>=0&&b>a);return s.slice(a,b)}
let now=1000;const c={Math,Number,performance:{now:()=>now},player:{r:0,c:0,ang:0},_clearPoliceFootRoute(){},_policeCrewBodyPassable:()=>true,_policeCrewPassable:()=>true,_npcRouteWalkBlocked:()=>false,_planPoliceFootRoute(){},_prisonIslandCollisionAt:()=>null,_moveMurderResponseCop:()=>{throw Error('unexpected collision fallback')},_ambulanceNeedsBodyCrew:()=>true,_ambulancePatientPosition:()=>({r:12,c:2}),_ambulanceReadyToDeploy:()=>true};vm.createContext(c);
vm.runInContext(s.match(/const NPC_HERO_PACE=Object.freeze\([^\n]+/)[0]+fn('_npcPacedSpeed')+fn('_policeCrewSegmentPassable')+fn('_prisonEscortBodyPassable')+fn('_movePoliceFootCop')+fn('_movePrisonEscortCop')+fn('_movePoliceBackup')+fn('_beachShopMove')+fn('_startAmbulanceBodyCrew'),c);
for(const dt of [1/30,1/60,1/144]){
 for(const running of [false,true]){const cop={x:0,y:0,speed:9};for(let t=0;t<60;t++){now+=dt*1000;const before={x:cop.x,y:cop.y};c._movePoliceFootCop(cop,20,20,dt,running?1.8:1);assert(Math.hypot(cop.x-before.x,cop.y-before.y)*4.1<= (running?7.8:1.8)*dt+1e-9);assert.equal(cop._paceRunning,running)}}
 const escort={x:0,y:0,speed:6};c._movePrisonEscortCop(escort,20,0,dt,1.18);assert(escort.y*4.1<=1.8*dt+1e-9);assert.equal(escort._paceRunning,false);
 const backup={id:'backup',r:0,c:0,walkPhase:0};c._movePoliceBackup(backup,5,0,dt);assert(backup.r*4.1<=7.8*dt+1e-9);assert.equal(backup._paceRunning,true);
 const shopper={_shopR:0,_shopC:0,_shopTargetR:5,_shopTargetC:0,walkPhase:0};c._beachShopMove(shopper,dt);assert(shopper._shopR*4.1<=1.8*dt+1e-9);
}
const v={id:'ambulance',x:0,y:0,ang:0,payload:{npc:{}}};assert(c._startAmbulanceBodyCrew(v,now));const ms=v._medicalScene,d=Math.hypot(ms.targetR-ms.rearR,ms.targetC-ms.rearC);assert(d/ms.approachMs*1000*4.1<=1.8+1e-9);assert(d/ms.returnMs*1000*4.1<=1.8+1e-9);assert.equal(v.workUntil,now+ms.total);assert.equal(v._medicalCrew.length,2);
console.log('PASS human service pace: police walk/chase, prison escort, backup run, shop walk at30/60/144FPS; stretcher timeline preserves phase duration and hero walk cap');
