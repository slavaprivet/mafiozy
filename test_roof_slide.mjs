import assert from 'node:assert/strict';
import {roofLadderDescriptor,createLadderClimbController,sampleLadderPose} from './assets/maps/city_rebuild_v1/roof_ladder.mjs';
const ladder=roofLadderDescriptor({id:'test',lower:{x:0,y:0,z:1},upper:{x:0,y:5,z:-.9},outward:{x:0,z:1}}),original=JSON.stringify(ladder),landed={x:0,y:5,z:-1.65};
let blocked=false,probes=0;const create=()=>createLadderClimbController({validatePosition:p=>{probes++;return !blocked||p.y>=2.5},validateSegment:()=>true});
function finish(c){let t=0,s,poses=[];while(c.locked&&t<20){s=c.update(1/60);poses.push(s.pose);t+=1/60;}assert(!c.locked,'finishes automatically');return {s,t,poses}}
let c=create();assert(c.begin(ladder.lower,ladder,'lower'));let up=finish(c);assert.deepEqual(up.s.position,landed);assert(up.s.done);assert(up.poses.some(p=>p.phaseName==='dismount'&&p.handBlend<.5));assert(up.s.pose.handBlend<1e-9);assert.equal(c.prompt(landed,[ladder]).end,'upper');assert.equal(c.prompt({x:0,y:0,z:-.9},[ladder]),null,'Ctrl is hidden below the roof approach band');
assert(c.begin(landed,ladder,'upper'));const slow=finish(c);assert.deepEqual(slow.s.position,ladder.lower);
assert(c.begin(landed,ladder,'upper',{sliding:true}));const fast=finish(c);assert.deepEqual(fast.s.position,ladder.lower);assert(fast.t<slow.t*.65,JSON.stringify({fast:fast.t,slow:slow.t}));assert(fast.poses.every(p=>p.sliding));
assert(c.begin(ladder.lower,ladder));for(let i=0;i<100;i++)c.update(1/60);const before=c.state.position;assert(c.slideDown());assert.deepEqual(c.state.position,before,'Ctrl never teleports');assert.equal(c.state.direction,-1);assert.deepEqual(finish(c).s.position,ladder.lower);
assert(c.begin(landed,ladder,'upper',{sliding:true}));while(c.state.position.y>3.8)c.update(1/60);blocked=true;const held=c.update(.25);assert(held.blocked&&c.locked);assert(held.position.y>=2.5,'dynamic obstacle stops even fast slide');blocked=false;finish(c);
assert(c.begin(ladder.lower,ladder));c.update(.2);assert(c.cancel());assert(!c.state.sliding);finish(c);assert.equal(JSON.stringify(ladder),original,'authored descriptor/geometry route unchanged');
const slidePose=sampleLadderPose(ladder,{x:0,y:3,z:1},3,-1,{sliding:true});assert.equal(slidePose.angles.thigh_l.x,slidePose.angles.thigh_r.x);assert.equal(slidePose.handL.y,slidePose.handR.y);
console.log(JSON.stringify({status:'PASS',autoStepOff:landed,slowSeconds:slow.t,slideSeconds:fast.t,probes},null,2));
c=create();assert(c.begin(ladder.lower,ladder));for(let i=0;i<60;i++)c.update(1/60);assert(c.slideDown());c.update(.1);assert(c.cancel());assert(!c.state.sliding);const cancelledSlide=finish(c);assert.deepEqual(cancelledSlide.s.position,ladder.lower,'cancel after Ctrl never releases in midair');
console.log('PASS E after mid-ascent Ctrl slows to safe ground landing');
