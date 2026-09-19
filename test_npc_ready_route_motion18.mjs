import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {sourceFunction} from './assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs';
const source=fs.readFileSync('world.html','utf8');
const end=source.indexOf('  // Entries are collected after iteration');
const start=source.lastIndexOf('    if (now < n.idleUntil)',end);
const actual=source.slice(start,end).replace(/\s*}\s*$/,'');
const old=actual.replace('n.idleUntil = purposefulWalk?now:now+(1200+Math.random()*2600)*Math.max(.65,idM);','n.idleUntil = now+(1200+Math.random()*2600)*Math.max(.65,idM);');
assert.notEqual(old,actual);
function run({before=false,native=true,rest=false,guard=false}={}){
 let now=1000,requests=0;
 const math=Object.create(Math);math.random=()=>.5;
 const b={Math:math,Number,performance:{now:()=>now},_walkNpcNavigationResolver:native?()=>({swept:true,blocked:false}):null,
  _npcLifeEligible:n=>!n.dead,_isRespawnableResident:()=>true,_npcEffectiveSpeed:()=>.4,
  npcPassable:()=>true,npcPassableForSnitch:()=>true,_residentEnterBuilding:()=>false,_civilianPlanArrive:()=>false};
 vm.createContext(b);
 for(const name of ['_civilianPlanEligible','_civilianArrivalRadius','_setNpcRoute','_clearNpcRoute','_npcBodyPassable','_npcPathPassable'])vm.runInContext(sourceFunction(source,name),b);
 vm.runInContext(fs.readFileSync('assets/maps/city_rebuild_v1/npc_city_population_source.js','utf8'),b);
 vm.runInContext(fs.readFileSync('assets/maps/city_rebuild_v1/npc_civilian_elapsed_source.js','utf8'),b);
 b.pickNpcWaypoint=n=>{requests++;return b._setNpcRoute(n,[{r:10.5,c:12.5}],'walk');};
 vm.runInContext('globalThis.tick=(n,dt,now)=>{for(const actor of [n]){const civilianRoutineDt=dt;'+(before?old:actual)+'}};',b);
 const n={id:'resident_ready18',r:10.5,c:10.5,tr:10.5,tc:10.5,hp:100,speed:.4,walkPhase:0,idleUntil:rest?4000:0,_guard:guard};
 let firstMove=null;
 for(let frame=0;frame<35;frame++){now=1000+frame*100;const previous=n.c;b.tick(n,.1,now);if(n.c>previous&&firstMove===null)firstMove=now-1000;}
 return {firstMove,requests};
}
const before=run({before:true}),after=run(),legacy=run({native:false}),rest=run({rest:true}),guard=run({guard:true});
assert(before.firstMove>=2500);
assert.equal(after.firstMove,100,'a ready route moves next frame instead of another random pause');
assert.equal(legacy.firstMove,before.firstMove,'old 2D timing stays intact');
assert.equal(guard.firstMove,before.firstMove,'special role timing stays intact');
assert(rest.firstMove>=3000,'an existing deliberate rest is not shortened');
console.log(JSON.stringify({before,after,legacy,rest,guard,limits:'Actual ordinary source branch; next route supplied at planner boundary to isolate post-search delay. CPU, no LIVE/FPS claim.'},null,2));
