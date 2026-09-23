import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {empireTargetFootprintCandidate23} from './npc_empire_target_footprint23_candidate.mjs';
const world=fs.readFileSync('world.html','utf8'),start=world.indexOf('function _nearestEmpireWalkPoint('),actualNearest=world.slice(start,world.indexOf('\n}',start)+2),deployed=world.includes('function _empireTargetFootprintPassable23(');
// Explicit pre-fix reference for RED and unordered parity. The fixed branch below
// always reads the actual deployed helper and nearest function when installed.
const legacyNearest=`function _nearestEmpireWalkPoint(r,c) {
  if(_npcBodyPassable(r,c,_empireBossPassable))return {r,c};
  let best=null,bestD=Infinity;
  for(let radius=1;radius<=12;radius++)for(let dr=-radius;dr<=radius;dr++)for(let dc=-radius;dc<=radius;dc++){
    if(Math.abs(dr)!==radius&&Math.abs(dc)!==radius)continue;
    const rr=Math.floor(r+dr)+.5,cc=Math.floor(c+dc)+.5,d=Math.hypot(rr-r,cc-c);
    if(d<bestD&&_npcBodyPassable(rr,cc,_empireBossPassable)){best={r:rr,c:cc};bestD=d;}
  }
  return best;
}`;
const helperStart=world.indexOf('function _empireTargetFootprintPassable23('),helper=deployed?world.slice(helperStart,world.indexOf('\n}',helperStart)+2):'';
const nearest=deployed?legacyNearest:actualNearest,candidate=deployed?helper+'\n'+actualNearest:empireTargetFootprintCandidate23(nearest);
if(process.argv.includes('--require-fixed'))assert(deployed,'actual production footprint helper installed');
const r=25.647106432580646,c=148.93801954695365;
function make(fixed,{native=true,unsupported=false,body=false,alwaysBlocked=false}={}){
 let sweeps=0,points=0;
 const b={Math,Number,_empireBossPassable:()=>true,_npcBodyPassable:()=>{points++;return !body;}};
 if(native)b._walkNpcNavigationResolver=q=>{sweeps++;assert.equal(q.mode,'sweep');assert.equal(q.radius,.18);assert.deepEqual(q.from,q.to);return unsupported?{swept:false}:{swept:true,blocked:alwaysBlocked||q.from.r===r&&q.from.c===c};};
 vm.createContext(b);vm.runInContext(fixed?candidate:nearest,b);return{b,get sweeps(){return sweeps},get points(){return points}};
}
const before=make(false),after=make(true),old=before.b._nearestEmpireWalkPoint(r,c),fixed=after.b._nearestEmpireWalkPoint(r,c);
assert.equal(old.r,r);assert.equal(old.c,c);assert.notDeepEqual(fixed,old,'thin obstacle missed by five points is rejected by full footprint');
for(const options of [{native:false},{unsupported:true}]){const f=make(true,options),target=f.b._nearestEmpireWalkPoint(r,c);assert.equal(target.r,r);assert.equal(target.c,c);}
const clear=make(true);assert.deepEqual(JSON.parse(JSON.stringify(clear.b._nearestEmpireWalkPoint(40.5,40.5))),{r:40.5,c:40.5});assert.equal(clear.sweeps,1);
const blockedBody=make(true,{body:true});assert.equal(blockedBody.b._nearestEmpireWalkPoint(r,c),null);assert.equal(blockedBody.sweeps,0,'existing body/water/terrain gates retain priority');
const blockedAll=make(true,{alwaysBlocked:true});assert.equal(blockedAll.b._nearestEmpireWalkPoint(r,c),null);assert(blockedAll.sweeps<=blockedAll.points);assert(blockedAll.points<=650,'existing finite 12-ring search retained');
// Ordering full-footprint probes must return the exact same closest target as
// the original ring order, including ties and a closer point on the next ring.
for(let seed=1;seed<=300;seed++){
 const pass=(rr,cc)=>Math.abs(Math.sin(rr*7.37+cc*3.13+seed))>.8;
 const b={Math,Number,_empireBossPassable:pass,_npcBodyPassable:(rr,cc,fn)=>fn(rr,cc),_walkNpcNavigationResolver:()=>({swept:true,blocked:false})};vm.createContext(b);
 const rr=20+(seed%10)*.137,cc=30+(seed%13)*.091;
 vm.runInContext(empireTargetFootprintCandidate23(nearest,{ordered:false}),b);const expected=b._nearestEmpireWalkPoint(rr,cc);
 vm.runInContext(candidate,b);const actual=b._nearestEmpireWalkPoint(rr,cc);assert.equal(JSON.stringify(actual),JSON.stringify(expected),'same nearest target '+seed);
}
const report={pass:true,actualDeployedSource:deployed,before:old,after:fixed,checks:'actual nearest function; full static footprint veto; legacy and unsupported sweep parity; clear target unchanged; body rejection never queries sweep; bounded no-target result; 300 ordered/unordered parity cases',limits:'Controlled geometry contracts. Separate actual pavilion002 replay provides the captured Nico route/physical walk proof. CPU, not LIVE.'};
fs.writeFileSync('outputs/empire_target_footprint23_candidate.json',JSON.stringify(report,null,2));console.log(report);
