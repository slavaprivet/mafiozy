import assert from 'node:assert/strict';
import {createNpcServiceDestinations} from './npc_service_destinations.mjs';
import {createNpcDetentionAccess} from './npc_detention_access.mjs';
let hospitals=[],blocked=false,time=0;
const services=createNpcServiceDestinations({clock:()=>time+=.002,worldScale:1,getHospitals:()=>hospitals,isRoad:(x,z)=>z>2&&z<5,vehicleQuery:()=>({clear:!blocked}),pedestrianQuery:()=>({blocked,depth:0})});
assert.equal(services.query({}),null,'no physical hospital means no legacy fallback');
hospitals=[{hospitalId:'native-hospital',door:{r:0,c:0}}];let result;
for(let i=0;i<100&&!result;i++){services.beginFrame();result=services.query({carId:'service_a'});}
assert.equal(result.hospitalId,'native-hospital');assert.ok(result.bay.r>2&&result.bay.r<5);assert.deepEqual(result.door,{r:0,c:0});
assert(result.footRoute.length>2,'returns an actual swept pedestrian route');
assert.deepEqual(result.footRoute[0],result.access);assert.deepEqual(result.footRoute.at(-1),result.door);
// An L-shaped approach requires turning around a real barrier. Every returned
// edge must leave room for the full .18 tile body, not merely its centre.
let detourTime=0;
const blockedAt=(r,c)=>r>.9&&r<1.1&&c<1.35;
const detour=createNpcServiceDestinations({clock:()=>detourTime+=.002,worldScale:1,
 getHospitals:()=>hospitals,isRoad:(x,z)=>z>2&&z<4&&Math.abs(x)<.4,
 vehicleQuery:()=>({clear:true}),pedestrianQuery:({r,c})=>({blocked:blockedAt(r,c),depth:0})});
let around;for(let frame=0;frame<300&&!around;frame++){detour.beginFrame();around=detour.query({carId:'detour'});}
assert(around,'resumable route finds the side opening');assert(around.footRoute.some(p=>p.c>1.5));
for(let i=1;i<around.footRoute.length;i++)for(let n=0;n<=20;n++){
 const a=around.footRoute[i-1],b=around.footRoute[i],r=a.r+(b.r-a.r)*n/20,c=a.c+(b.c-a.c)*n/20;
 for(const [dr,dc]of [[0,0],[.18,0],[-.18,0],[0,.18],[0,-.18]])assert(!blockedAt(r+dr,c+dc),'body never cuts the barrier corner');
}
services.invalidate();blocked=true;
for(let i=0;i<100;i++){services.beginFrame();assert.equal(services.query({carId:'service_a'}),null,'blocked physical access cannot deliver');}
let entrance=false,gate=false;const entry={kind:'detention',instance:{id:'site',detentionId:'district',transform:{positionM:[4,0,8]}},doors:[{fraction:0},{fraction:0}],setEntranceOpen:v=>entrance=v,setGateOpen:v=>gate=v};
const access=createNpcDetentionAccess({worldScale:1,getEntries:()=>[entry]});
assert.equal(access({destinationId:'missing',from:{r:8,c:4}}).ready,false);
assert.equal(access({destinationId:'district',action:'open',from:{r:100,c:100}}).ready,false);assert.equal(entrance,false);
assert.equal(access({destinationId:'district',action:'open',from:{r:8,c:4}}).ready,false,'requesting open does not erase animated closed doors');assert.equal(entrance,true);assert.equal(gate,true);
entry.doors.forEach(d=>d.fraction=1);assert.equal(access({destinationId:'district',from:{r:8,c:4}}).ready,true);
access({destinationId:'district',action:'close',from:{r:8,c:4}});assert.equal(entrance,false);assert.equal(gate,false);
console.log('PASS physical hospital bay/corridor, absent/blocked hospital, actual detention gate progress and proximity');
