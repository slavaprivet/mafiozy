import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const source=fs.readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8');
const start=source.indexOf('setInterval(()=>{if(!document.hidden');
assert.ok(start>=0);
const end=source.indexOf(',15000);',start)+9;
let poll,calls=0;
const context={document:{hidden:false},arsenalOpen:()=>false,busy:false,heroCover:{active:false},occupiedSeat:null,transition:null,jump:null,heroBlast:null,verticalNavigation:{active:false},aiming:false,triggerHeld:false,savedCameraOffset:null,carState:{speed:0},refresh(){calls++;},setInterval(fn,ms){assert.equal(ms,15000);poll=fn;}};
vm.runInNewContext(source.slice(start,end),context);
poll();assert.equal(calls,1,'free idle world still refreshes');
context.heroCover.active=true;
for(let i=0;i<20;i++)poll();
assert.equal(calls,1,'automatic refresh cannot raise busy and detach active cover');
context.heroCover.active=false;poll();assert.equal(calls,2,'pending world refresh resumes after leaving cover');
for(const key of ['busy','aiming','triggerHeld']){context[key]=true;poll();context[key]=false;}
assert.equal(calls,2,'existing refresh exclusions remain');
console.log('PASS actual 15-second world poll: active cover stays attached; refresh resumes on exit; existing guards preserved');
