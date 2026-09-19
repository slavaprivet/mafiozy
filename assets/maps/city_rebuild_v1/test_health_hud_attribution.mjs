import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const source=fs.readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8');
const line=source.split(/\r?\n/).find(line=>line.includes("performanceProbe.measure('healthSync'"));
assert(line,'actual frame instrumentation exists');
let count=0;
for(const enabled of [false,true])for(const hasHud of [false,true])for(const blocked of [false,true]){
 const calls=[],stages=[],context={dt:.031,performance:{now:()=>123},updateWorldWalkHealth(){calls.push('health')},walkPlayerHud:hasHud?{update(now){assert.equal(now,123);calls.push('hud')}}:null,updateMercenaries(dt){assert.equal(dt,.031);calls.push('mercenaries')},hudInputBlocked(){calls.push('guard');return blocked},releaseControls(){calls.push('release')},performanceProbe:enabled?{begin(){stages.push('begin')},measure(name,fn){stages.push(name);return fn()},mark(name){stages.push(name)}}:null};
 vm.runInNewContext(line,context);
 assert.deepEqual(calls,['health',...(hasHud?['hud']:[]),'mercenaries','guard',...(blocked?['release']:[])]);
 assert.deepEqual(stages,enabled?['begin','healthSync','playerHud','mercenaryUpdate','healthHud']:[]);count++;
}
for(const failing of ['health','hud','mercenaries']){
 const error=new Error(failing),calls=[];
 const invoke=name=>{calls.push(name);if(name===failing)throw error};
 const context={dt:.02,performance:{now:()=>1},updateWorldWalkHealth:()=>invoke('health'),walkPlayerHud:{update:()=>invoke('hud')},updateMercenaries:()=>invoke('mercenaries'),hudInputBlocked:()=>false,performanceProbe:{begin(){},measure(name,fn){return fn()},mark(){assert.fail('must preserve original exception')}}};
 assert.throws(()=>vm.runInNewContext(line,context),value=>value===error);
 assert.deepEqual(calls,['health','hud','mercenaries'].slice(0,['health','hud','mercenaries'].indexOf(failing)+1));count++;
}
console.log(JSON.stringify({passed:count,scope:'actual frame line; exact order/count/dt; optional probe/HUD; exception identity; no LIVE'}));
