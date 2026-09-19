import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const world=fs.readFileSync('world.html','utf8').replace(/\r\n/g,'\n');
const helper=fs.readFileSync('assets/maps/city_rebuild_v1/npc_city_population_source.js','utf8');
const fn=name=>{const start=world.indexOf('function '+name+'(');assert(start>=0,name);let p=world.indexOf('{',start),depth=1;for(p++;depth;p++){if(world[p]==='{')depth++;if(world[p]==='}')depth--;}return world.slice(start,p);};
const end=world.indexOf('  // Entries are collected after iteration'),start=world.lastIndexOf('    if (now < n.idleUntil)',end);
const foot=world.slice(start,end).replace(/\s*}\s*$/,'');assert(start>0);
function run({before=false,native=true,dt=.1}={}){
 let now=1000,blocked=0,newTasks=0,pauses=0;
 const n={r:10.5,c:10.5,tr:10.5,tc:11.5,_routeIndex:0,_routeKind:'walk',_route:[{r:10.5,c:11.5},{r:11.5,c:11.5},{r:12.5,c:11.5}],walkPhase:0,idleUntil:0};
 const corridor=(r,c)=>(Math.abs(r-10.5)<=.20001&&c>=10.2&&c<=11.7)||(Math.abs(c-11.5)<=.20001&&r>=10.3&&r<=13);
 const b={Math,Number,performance:{now:()=>now},_npcLifeEligible:n=>!n.dead,_isRespawnableResident:()=>true,_npcEffectiveSpeed:()=>.4,_walkNpcNavigationResolver:native?()=>({blocked:false,depth:0}):null,npcPassable:corridor,npcPassableForSnitch:corridor,_residentEnterBuilding:()=>false,_civilianPlanArrive:()=>false,pickNpcWaypoint:()=>newTasks++};
 vm.createContext(b);for(const name of ['_npcBodyPassable','_npcPathPassable','_clearNpcRoute','_civilianArrivalRadius','_civilianPlanEligible'])vm.runInContext(fn(name),b);
 vm.runInContext(helper,b);vm.runInContext(fs.readFileSync('assets/maps/city_rebuild_v1/npc_civilian_elapsed_source.js','utf8'),b);
 if(before)vm.runInContext('function _civilianArrivalRadius(){return .4;}',b);
 const realStep=b._npcRoutineStep;b._npcRoutineStep=(...args)=>{const result=realStep(...args);if(!result)blocked++;return result;};
 vm.runInContext('globalThis.tick=(n,dt,now)=>{const civilianRoutineDt=_npcConsumeCivilianElapsed(n,dt,now);for(const actor of [n]){'+foot+'}};',b);
 for(let frame=0;frame<180&&!newTasks;frame++){
  now+=dt*1000;const r=n.r,c=n.c;b.tick(n,dt,now);
  if(n._route&&r===n.r&&c===n.c)pauses++;
  assert(corridor(n.r,n.c),'actual source position stays in the corridor');
 }
 return{n,blocked,newTasks,pauses};
}
const before=run({before:true}),after=run(),far=run({dt:.25});
assert(before.blocked>0&&before.n.r<11,'old broad intermediate arrival cuts the inside corner and stalls');
for(const result of [after,far]){
 assert.equal(result.blocked,0,'complete authored cardinal route stays physically passable');
 assert(result.n.r>12&&result.newTasks===1,'resident completes the outing');
 assert.equal(result.pauses,0,'changing intermediate waypoint does not insert a stopped animation frame');
}
console.log(JSON.stringify({before:{blocked:before.blocked,r:before.n.r},after:{blocked:after.blocked,r:after.n.r,pauses:after.pauses},farCadence:{blocked:far.blocked,r:far.n.r,pauses:far.pauses},limits:'actual source foot branch and footprint gates in a narrow L corridor; CPU, no rendered scene'}));
