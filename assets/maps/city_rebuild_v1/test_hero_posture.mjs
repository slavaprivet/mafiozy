import assert from 'node:assert/strict';
import {HERO_POSTURES,createHeroPosture,requestHeroPosture,stepHeroPosture,posturePresentation,resetHeroPosture} from './hero_posture.mjs';

const state=createHeroPosture();
assert.equal(posturePresentation(state).height,HERO_POSTURES.stand.height);
assert.equal(requestHeroPosture(state,'crouch'),true);
stepHeroPosture(state,1/2.1);
let view=posturePresentation(state);assert.equal(state.value,1);assert.equal(view.maxSpeed,1.55);assert.equal(view.height,HERO_POSTURES.crouch.height);assert.equal(view.eyeHeight,1.40);
assert.equal(requestHeroPosture(state,'prone'),true);for(let i=0;i<40;i++)stepHeroPosture(state,1/60);
view=posturePresentation(state);assert.equal(state.value,2);assert.equal(view.crawl,true);assert.equal(view.maxSpeed,.8);assert.equal(view.eyeHeight,.43);
let highestProbe=0;assert.equal(requestHeroPosture(state,'stand',{canOccupyHeight:height=>(highestProbe=Math.max(highestProbe,height))<1.5}),false);
assert.equal(state.target,'prone');assert.equal(state.blocked,true);assert.equal(highestProbe,1.9);
assert.equal(requestHeroPosture(state,'crouch',{canOccupyHeight:()=>true}),true);
const before=state.value;view=stepHeroPosture(state,.1,{canOccupyHeight:height=>height<=.7});assert.equal(state.value,before);assert.equal(view.blocked,true);
for(let i=0;i<20;i++)view=stepHeroPosture(state,.1,{canOccupyHeight:()=>true});assert.equal(state.value,1);assert.equal(view.blocked,false);
assert(view.speedMultiplier<1&&view.speedMultiplier>0);
assert.throws(()=>requestHeroPosture(state,'sit'),/Unknown hero posture/);assert.throws(()=>stepHeroPosture(state,-1),/finite/);
assert.equal(resetHeroPosture(state).height,1.9);assert.equal(state.target,'stand');
console.log(JSON.stringify({passed:true,checks:['stand_crouch_prone_transition','source_speed_units','capsule_eye_metrics','request_clearance_guard','per_step_clearance_guard','reset']}));
