import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const source=fs.readFileSync(new URL('./world.html',import.meta.url),'utf8');
const start=source.indexOf('const _worldUpdateProfile =');
const end=source.indexOf('\nfunction frame() {',start);
assert(start>=0&&end>start);
const actual=source.slice(start,end);
function fixture(search='?perfqa=1',hostname='127.0.0.1'){
  let time=0,cost=1,error=null,calls=0,publications=0;
  const data={};
  const box={location:{hostname,search},URLSearchParams,Float64Array,Uint8Array,document:{documentElement:{dataset:new Proxy(data,{set(target,key,value){if(key==='worldUpdateProfile')publications++;target[key]=value;return true;}})}},performance:{now:()=>time},update(dt){assert.equal(dt,.04);calls++;time+=cost;if(error)throw error;}};
  vm.createContext(box);vm.runInContext(actual,box);
  return {box,data,tick(value=1,gap=1000,throwValue=null){cost=value;time+=gap;error=throwValue;return box._timedWorldUpdate(.04);},get calls(){return calls;},get publications(){return publications;},report:()=>JSON.parse(data.worldUpdateProfile)};
}

for(const [search,host] of [['','127.0.0.1'],['?perfqa=0','localhost'],['?perfqa=1','game.example']]){
  const f=fixture(search,host);f.tick(8);assert.equal(f.calls,1);assert.equal(f.data.worldUpdateMs,'8.0');assert.equal(f.data.worldUpdateProfile,undefined,'QA window must stay disabled outside explicit local perfqa');
}
{
  const f=fixture();for(let i=1;i<=120;i++)f.tick(i);
  let r=f.report();assert.equal(r.samples,120);assert.equal(r.p50Ms,60);assert.equal(r.p95Ms,114);assert.equal(r.meanMs,60.5);assert.equal(r.maxMs,120);
  for(let i=0;i<120;i++)f.tick(2);
  r=f.report();assert.equal(r.totalSamples,240);assert.equal(r.samples,120);assert.equal(r.p50Ms,2);assert.equal(r.p95Ms,2);assert.equal(r.maxMs,2,'previous window maximum must expire');assert.equal(f.data.worldUpdateMaxMs,'120.0','legacy sticky maximum remains compatible');
}
{
  const f=fixture(),failure=new TypeError('synthetic source failure');
  assert.throws(()=>f.tick(31,1000,failure),e=>e===failure,'original update exception must propagate unchanged');
  let r=f.report();assert.equal(r.failedUpdates,1);assert.equal(r.windowFailedUpdates,1);assert.equal(r.lastMs,31);
  for(let i=0;i<120;i++)f.tick(3);
  r=f.report();assert.equal(r.failedUpdates,1);assert.equal(r.windowFailedUpdates,0);assert.equal(r.p95Ms,3);assert.equal(f.calls,121,'no extra/retried updates');
}
{
  const f=fixture();f.tick(1,0);for(let i=0;i<119;i++)f.tick(1,0);
  assert.equal(f.publications,1,'per-frame capture must not publish/sort each frame');
  f.tick(1,1000);assert.equal(f.publications,2);assert.equal(f.report().totalSamples,121);
}
console.log('PASS actual source update profiling: local opt-in, bounded120 rolling p50/p95, error propagation/counts, 1Hz publication, unchanged update calls.');
