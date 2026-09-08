import assert from 'node:assert/strict';
import {HOLD_SECONDS,EXIT_HOLD_SECONDS,TRANSITION_SECONDS,advanceEntryHold,entryPose} from './car_entry.mjs';
assert.equal(HOLD_SECONDS,.3);assert.equal(EXIT_HOLD_SECONDS,.3);assert(TRANSITION_SECONDS>HOLD_SECONDS);
for(const duration of [HOLD_SECONDS,EXIT_HOLD_SECONDS]){
 let h=advanceEntryHold(0,true,true,.1,duration);h=advanceEntryHold(h.elapsed,true,true,.1,duration);assert(!h.ready);
 h=advanceEntryHold(h.elapsed,true,true,.1,duration);assert(h.ready);
 assert.equal(advanceEntryHold(.2,false,true,.1,duration).elapsed,0);
}
assert.equal(entryPose(.08).seat,0,'hand reaches while root remains outside');
assert(entryPose(.20).door>.5);assert.equal(entryPose(.20).seat,0,'open before crossing door');
assert(entryPose(.4).innerLeg>entryPose(.4).outerLeg,'inner leg enters first');
assert.equal(entryPose(.5).door,1,'door stays open during crossing');
assert(entryPose(.68).outerLeg>0&&entryPose(.68).outerLeg<1,'outer leg follows');
assert(entryPose(.9).closeReach>.5&&entryPose(.9).seat===1,'close from fully seated position');
assert.equal(entryPose(1).door,0);assert.equal(entryPose(1).fold,1);assert.equal(entryPose(1).phase,'seated');
assert.equal(entryPose(0,true).seat,1);assert.equal(entryPose(1,true).seat,0);
let previous=entryPose(0);for(let i=1;i<=1000;i++){const pose=entryPose(i/1000);for(const key of ['seat','fold','door','innerLeg','outerLeg','handReach','duck','closeReach']){assert(Number.isFinite(pose[key])&&pose[key]>=0&&pose[key]<=1);assert(Math.abs(pose[key]-previous[key])<.025,'continuous entry curve '+key)}previous=pose}
console.log('PASS .3s entry/exit hold, separate staged animation, door-before-crossing, asymmetric legs, seated close, continuous curves');
