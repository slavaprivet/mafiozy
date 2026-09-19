import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {performance} from 'node:perf_hooks';
const source=fs.readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8').replace(/\r\n/g,'\n');
const a=source.indexOf('function updateNpcPopulation(dt){'),b=source.indexOf('\nlet exitSwimHandoff',a);
assert(a>=0&&b>a);const actual=source.slice(a,b);
class Vec{constructor(x=0,y=0,z=0){Object.assign(this,{x,y,z});}set(x,y,z){Object.assign(this,{x,y,z});return this;}clone(){return new Vec(this.x,this.y,this.z);}add(v){this.x+=v.x;this.y+=v.y;this.z+=v.z;return this;}sub(v){this.x-=v.x;this.y-=v.y;this.z-=v.z;return this;}array(){return [this.x,this.y,this.z];}}
let locked=true,restores=0,reset=0;
const state={r:98.8499164424,c:153.3260940234,ang:.7};
const context={performance,M:4.1,keys:new Set(),heroPosture:{target:'stand'},
 hero:{object:{position:new Vec(164,0,164),rotation:{y:0}}},controls:{target:new Vec(164,1.1,164)},camera:{position:new Vec(167,2.74,168)},
 npcNativeNavigation:null,npcVehicleNavigation:null,npcServiceDestinations:null,npcNativePerception:null,npcInspection:null,
 transportDiagnosticAt:Infinity,npcDiagnosticsAt:Infinity,groundHeight:()=>0,
 npcPopulation:{update(){}},releaseControls(){},restoreBuildingCamera(){restores++;},
 npcBridge:{syncWalkPlayer:()=>({locked,state}),getWorldClock:()=>1000}};
const surface={position:context.hero.object.position.clone()};context.resetFootSupport=()=>{surface.position=context.hero.object.position.clone();reset++;};
vm.createContext(context);vm.runInContext(actual,context);
const offset=context.camera.position.clone().sub(context.controls.target).array();
context.updateNpcPopulation(.016);
assert(Math.abs(context.hero.object.position.x-state.c*4.1)<1e-8);
assert.deepEqual(context.controls.target.array(),[state.c*4.1,1.1,state.r*4.1],'custody camera target must follow authoritative hero immediately');
assert.deepEqual(context.camera.position.clone().sub(context.controls.target).array(),offset,'source takeover preserves current camera orbit');
assert.deepEqual(surface.position.array(),context.hero.object.position.array(),'floor support must not restore the old source location next frame');
assert.equal(reset,1);assert.equal(restores,1);
const first=context.camera.position.array();context.updateNpcPopulation(.016);assert.deepEqual(context.camera.position.array(),first,'same source position never adds duplicate camera offset');
state.r+=.03;state.c+=.05;context.updateNpcPopulation(.016);
assert(Math.abs(context.controls.target.x-state.c*4.1)<1e-8);assert(Math.abs(context.controls.target.z-state.r*4.1)<1e-8);
locked=false;state.r+=20;const camera=context.camera.position.array();context.updateNpcPopulation(.016);assert.deepEqual(context.camera.position.array(),camera,'ordinary unlocked movement remains owned by walking controller');
const branchStart=actual.indexOf('  if(receipt?.locked'),branchEnd=actual.indexOf('\n }\n const sourceClock',branchStart);
assert(branchStart>=0&&branchEnd>branchStart);
const baseline=(actual.slice(0,branchStart)+"  if(receipt?.locked&&receipt.state){const s=receipt.state;releaseControls();hero.object.position.set(s.c*M,groundHeight(s.c*M,s.r*M),s.r*M);}"+actual.slice(branchEnd)).replace('function updateNpcPopulation','function baselineUpdate');
vm.runInContext(baseline,context);locked=true;
const sample=fn=>{const times=[];for(let i=0;i<1200;i++){const t=performance.now();fn(.016);if(i>=200)times.push(performance.now()-t);}times.sort((a,b)=>a-b);return {p50:times[500],p95:times[950]};};
console.log('PASS actual source custody/teleport camera and floor-support sync',JSON.stringify({before:sample(context.baselineUpdate),after:sample(context.updateNpcPopulation),limits:'CPU source callback only; no renderer/GPU'}));
