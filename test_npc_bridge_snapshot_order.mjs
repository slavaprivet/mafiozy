import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const source=readFileSync(new URL('./world.html',import.meta.url),'utf8');
assert.match(source,/npcPools\[npcLifePool\(x\)\]\.push\(\{source:x,id,sticky:/);
assert.match(source,/const squaredOrder=a\.sortD2-b\.sortD2;return squaredOrder\|\|\(a\.sortDistance-b\.sortDistance\)\|\|a\.id\.localeCompare\(b\.id\)/);
assert.match(source,/const selected=npcSelected\[i\],x=selected\.source,id=selected\.id/);
assert.match(source,/const npcLifePoolDiagnostics=`mission:\$\{npcPoolMissionCount\}.*cap:\$\{NPC_LIFE_NPC_CAP\}`;\s*if\(document\.documentElement\.dataset\.npcLifePools!==npcLifePoolDiagnostics\)document\.documentElement\.dataset\.npcLifePools=npcLifePoolDiagnostics/s);
let diagnosticWrites=0,diagnosticValue='';
const publishPools=value=>{if(diagnosticValue!==value){diagnosticValue=value;diagnosticWrites++;}};
for(let i=0;i<600;i++)publishPools('mission:0,police:0,guard:0,gang:0,civilian:32,shown:32,cap:72');
assert.equal(diagnosticWrites,1,'unchanged inspection data must not cause repeated bridge-side DOM writes');
publishPools('mission:1,police:0,guard:0,gang:0,civilian:31,shown:32,cap:72');
assert.equal(diagnosticWrites,2,'a changed roster remains immediately observable');

const pools=['mission','police','guard','gang','civilian'];
const cap=72;
function legacy(rows,sticky){
  const by=Object.fromEntries(pools.map(key=>[key,[]]));
  for(const x of rows)by[x.pool].push(x);
  const distSq=x=>{const dr=x.r,dc=x.c;return dr*dr+dc*dc;};
  const compare=(a,b)=>{
    const stickyOrder=(sticky.has(a.id)?0:1)-(sticky.has(b.id)?0:1);
    if(stickyOrder)return stickyOrder;
    const squaredOrder=distSq(a)-distSq(b);
    return squaredOrder||(Math.hypot(a.r,a.c)-Math.hypot(b.r,b.c))||a.id.localeCompare(b.id);
  };
  for(const key of pools)by[key].sort(compare);
  return choose(by).map(x=>x.id);
}
function packed(rows,sticky){
  const by=Object.fromEntries(pools.map(key=>[key,[]]));
  for(const x of rows){const dr=x.r,dc=x.c;by[x.pool].push({source:x,id:x.id,sticky:sticky.has(x.id),sortD2:dr*dr+dc*dc,sortDistance:Math.hypot(dr,dc)});}
  const compare=(a,b)=>{const stickyOrder=(a.sticky?0:1)-(b.sticky?0:1);if(stickyOrder)return stickyOrder;const squaredOrder=a.sortD2-b.sortD2;return squaredOrder||(a.sortDistance-b.sortDistance)||a.id.localeCompare(b.id);};
  for(const key of pools)by[key].sort(compare);
  return choose(by).map(x=>x.id);
}
function choose(by){
  const civilianReserve=Math.min(24,by.civilian.length,cap),result=[],offset=Object.fromEntries(pools.map(key=>[key,0]));
  let critical=cap-civilianReserve;
  for(let i=0;i<4;i++){const key=pools[i],take=Math.min(critical,by[key].length);result.push(...by[key].slice(0,take));offset[key]=take;critical-=take;}
  result.push(...by.civilian.slice(0,civilianReserve));offset.civilian=civilianReserve;
  for(const key of pools){for(let i=offset[key];i<by[key].length&&result.length<cap;i++)result.push(by[key][i]);if(result.length>=cap)break;}
  return result;
}

for(let seed=1;seed<=20;seed++){
  let state=seed;
  const next=()=>{state=(state*1664525+1013904223)>>>0;return state/2**32;};
  const rows=Array.from({length:250},(_,index)=>({id:`npc_${String(index).padStart(3,'0')}`,pool:pools[Math.floor(next()*pools.length)],r:(next()-.5)*128,c:(next()-.5)*128}));
  const sticky=new Set(rows.filter((_,index)=>index%11===seed%11).map(x=>x.id));
  assert.deepEqual(packed(rows,sticky),legacy(rows,sticky),`selection changed for seed ${seed}`);
}
console.log('NPC_BRIDGE_SNAPSHOT_ORDER_OK');
