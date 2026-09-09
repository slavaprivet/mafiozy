import test from 'node:test';
import assert from 'node:assert/strict';
import {
  CRASH_PART_IDS,createCrashMechanicsState,applyCrashMechanicsImpact,crashCrushLimits,
  stepCrashMechanics,sampleCrashDeformation,crashDriveEffects,
  resetCrashMechanics,createCrashDebrisState,stepCrashDebris,
} from './vehicle_crash_mechanics.mjs';

const front=(speed=18,extra={})=>({point:{x:0,y:.80,z:2.15},normal:{x:0,y:0,z:1},impactSpeed:speed,...extra});
const offset=(speed=28,side=1)=>front(speed,{point:{x:side*.98,y:.55,z:1.93},normal:{x:side*.22,y:0,z:1}});
const approx=(a,b,tol=1e-7)=>assert.ok(Math.abs(a-b)<=tol,`${a} != ${b} (tolerance ${tol})`);
const settle=(state,fps=60,seconds=3)=>{for(let i=0;i<fps*seconds;i++)stepCrashMechanics(state,1/fps);return state;};

test('pristine and low parking bumps preserve cage, mounts and drivetrain',()=>{
  const state=createCrashMechanicsState(),snapshot=JSON.stringify(state);
  for(const speed of [0,.2,1,2.49])assert.equal(applyCrashMechanicsImpact(state,front(speed)).applied,false);
  assert.equal(JSON.stringify(state),snapshot);
  assert.equal(stepCrashMechanics(state,1/60),false);
  const e=crashDriveEffects(state);
  assert.deepEqual(sampleCrashDeformation(state,{x:0,y:1,z:1}),{x:0,y:0,z:0});
  for(const id of ['speedFactor','powerFactor','frontGrip','rearGrip','steerFactor','brakeFactor'])assert.equal(e[id],1);
  assert.equal(e.rollingDrag,0);assert.equal(e.pull,0);assert.equal(e.engineDisabled,false);
});

test('frontal crush is permanent, localized, energy-bounded and hurts engine',()=>{
  const state=createCrashMechanicsState(),hit=applyCrashMechanicsImpact(state,front(22));
  assert.equal(hit.applied,true);assert.ok(hit.deformedNodes>5);
  assert.ok(state.engine<.4);assert.ok(state.radiator<.2);
  assert.ok(state.detachedParts.includes('hood'));assert.ok(state.detachedParts.includes('bumper_front'));
  assert.ok(state.parts.trunk.health>.95);
  settle(state);
  const nose=sampleCrashDeformation(state,{x:0,y:.95,z:2.1}),rear=sampleCrashDeformation(state,{x:0,y:.95,z:-2.1});
  assert.ok(nose.z<-.30);assert.ok(Math.abs(rear.z)<.015);
  assert.ok(state.maxCrush>1.2&&state.maxCrush<=1.548001);
  assert.ok(state.absorbedEnergyJ>0&&state.absorbedEnergyJ<=state.totalEnergyJ);
  assert.ok(state.beams.some(b=>b.plasticStrain>.02));
  const settled=JSON.stringify(state.nodes.map(n=>n.position));settle(state,60,2);
  assert.equal(JSON.stringify(state.nodes.map(n=>n.position)),settled);
});

test('rear impact deforms trunk without directly harming front engine or radiator',()=>{
  const state=createCrashMechanicsState();
  applyCrashMechanicsImpact(state,front(24,{point:{x:0,y:.8,z:-2.15},normal:{x:0,y:0,z:-1}}));
  assert.equal(state.engine,1);assert.equal(state.radiator,1);
  assert.ok(state.detachedParts.includes('trunk'));assert.ok(state.detachedParts.includes('bumper_rear'));
  assert.ok(!state.detachedParts.includes('hood'));
  assert.ok(sampleCrashDeformation(state,{x:0,y:.95,z:-2.1}).z>.3);
});

test('offset crash breaks near wheel while shielding far wheel and causing alignment pull',()=>{
  const state=createCrashMechanicsState();applyCrashMechanicsImpact(state,offset(28));
  assert.equal(state.wheels.front_left.detached,true);
  assert.equal(state.wheels.front_right.detached,false);
  assert.ok(state.wheels.front_right.health>.96);
  const e=crashDriveEffects(state);
  assert.ok(e.frontGrip<.55);assert.ok(e.speedFactor<.32);assert.ok(e.rollingDrag>3);
  assert.ok(Math.abs(e.pull)>.1);assert.ok(e.wheels.front_left.sag>.1);
  assert.ok(state.parts.door_rear_left.health>.9);
});

test('left/right mirrored impacts give equal damage and opposite steering pull',()=>{
  const left=createCrashMechanicsState(),right=createCrashMechanicsState();
  applyCrashMechanicsImpact(left,offset(19,1));applyCrashMechanicsImpact(right,offset(19,-1));
  settle(left);settle(right);
  approx(left.engine,right.engine);approx(left.wheels.front_left.health,right.wheels.front_right.health);
  approx(crashDriveEffects(left).pull,-crashDriveEffects(right).pull);
  const a=sampleCrashDeformation(left,{x:.8,y:1,z:1.8}),b=sampleCrashDeformation(right,{x:-.8,y:1,z:1.8});
  approx(a.x,-b.x);approx(a.y,b.y);approx(a.z,b.z);
});

test('fixed structural integration agrees across 30, 60, 120 and 144 Hz',()=>{
  const states=[30,60,120,144].map(fps=>{
    const s=createCrashMechanicsState();applyCrashMechanicsImpact(s,offset(17));return settle(s,fps,3);
  });
  for(const s of states.slice(1))for(let i=0;i<s.nodes.length;i++)for(const axis of ['x','y','z'])approx(s.nodes[i].position[axis],states[0].nodes[i].position[axis],.0008);
  for(const s of states)assert.equal(s.active,false);
});

test('contact event IDs and detach events are idempotent; repeated real impacts accumulate',()=>{
  const s=createCrashMechanicsState(),first=applyCrashMechanicsImpact(s,front(22,{eventId:'wall-1'}));
  const snapshot=JSON.stringify(s);
  assert.equal(applyCrashMechanicsImpact(s,front(22,{eventId:'wall-1'})).applied,false);
  assert.equal(JSON.stringify(s),snapshot);
  const second=applyCrashMechanicsImpact(s,front(22,{eventId:'wall-2'}));
  assert.equal(second.applied,true);assert.equal(s.impacts,2);
  assert.equal(second.detached.some(id=>first.detached.includes(id)),false);
  assert.equal(new Set(s.detachedParts).size,s.detachedParts.length);
  assert.ok(s.maxCrush>JSON.parse(snapshot).maxCrush);
  assert.ok(s.detachedParts.every(id=>CRASH_PART_IDS.includes(id)));
});

test('no HP, glass, bullet, explosion or automatic fire side effects are invented',()=>{
  const s=createCrashMechanicsState();applyCrashMechanicsImpact(s,front(90));
  for(const key of ['hp','exploded','wrecked','burning','glass','bullet'])assert.equal(Object.hasOwn(s,key),false);
  assert.equal(crashDriveEffects(s).engineDisabled,true);
  assert.equal(crashDriveEffects(s).powerFactor,0);
});

test('radiator damage raises heat under load; repair resets full state and counters',()=>{
  const s=createCrashMechanicsState();applyCrashMechanicsImpact(s,front(14));
  const engine=s.engine;
  for(let i=0;i<600;i++)stepCrashMechanics(s,.1,{speed:5,throttle:1});
  assert.ok(s.temperature>.85);assert.ok(s.engine<=engine);
  const identity=s;resetCrashMechanics(s);assert.equal(s,identity);
  assert.deepEqual(s,createCrashMechanicsState(s.profile));
});

test('zero dt is no-op; invalid payloads cannot introduce NaN; stalls are bounded',()=>{
  const s=createCrashMechanicsState(),snap=JSON.stringify(s);
  for(const c of [front(NaN),front(10,{normal:{x:0,y:0,z:0}}),front(10,{point:{x:9000,y:0,z:0}}),front(10,{normal:{x:Infinity,y:0,z:1}})])assert.equal(applyCrashMechanicsImpact(s,c).applied,false);
  stepCrashMechanics(s,0);assert.equal(JSON.stringify(s),snap);
  assert.throws(()=>stepCrashMechanics(s,-1));assert.throws(()=>stepCrashMechanics(s,NaN));
  applyCrashMechanicsImpact(s,front(20));stepCrashMechanics(s,60);
  assert.ok(s.simulationTime<=.100001);
  assert.ok(s.nodes.every(n=>Object.values(n.position).every(Number.isFinite)));
});

test('600 deterministic varied impacts never exceed deformation or energy bounds',()=>{
  const s=createCrashMechanicsState();let seed=61832;
  const rand=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
  for(let i=0;i<600;i++){
    const side=rand()<.5?-1:1,frontHit=rand()<.5;
    const point=frontHit?{x:(rand()-.5)*1.98,y:.3+rand(),z:side*2.15}:{x:side,y:.3+rand(),z:(rand()-.5)*4.2};
    applyCrashMechanicsImpact(s,{point,normal:frontHit?{x:0,y:0,z:side}:{x:side,y:0,z:0},impactSpeed:rand()*90,eventId:i});
    stepCrashMechanics(s,1/60);
    const limit=crashCrushLimits(s.profile);
    assert.ok(s.maxCrush<=Math.max(limit.x,limit.y,limit.z)+1e-6);assert.ok(s.absorbedEnergyJ<=s.totalEnergyJ);
    for(const node of s.nodes)assert.ok(Math.hypot((node.plastic.x-node.rest.x)/limit.x,(node.plastic.y-node.rest.y)/limit.y,(node.plastic.z-node.rest.z)/limit.z)<=1.000001,'accumulated plastic displacement stays inside the directional envelope');
    assert.ok(s.nodes.every(n=>Object.values(n.position).every(Number.isFinite)));
    for(const k of ['speedFactor','powerFactor','frontGrip','rearGrip','steerFactor','brakeFactor'])assert.ok(crashDriveEffects(s)[k]>=0&&crashDriveEffects(s)[k]<=1);
  }
  assert.ok(s.detachedParts.length<=12);assert.ok(s.recentEvents.length<=128);
});

test('mass changes incoming energy, while equal delta-V produces equal specific crush',()=>{
  const a=createCrashMechanicsState({massKg:1500}),b=createCrashMechanicsState({massKg:12000});
  applyCrashMechanicsImpact(a,front(12));applyCrashMechanicsImpact(b,front(12));
  approx(b.totalEnergyJ/a.totalEnergyJ,8);approx(a.maxCrush,b.maxCrush);
});

test('speed curve keeps low-speed dents mild and strongly crumples high-speed impacts',()=>{
  const baseline={front:{3:.005929,6:.083888,16:.535361,22:.803171},side:{3:.004586,6:.069993,16:.495771,22:.762058}};
  for(const direction of ['front','side']){
    let previousCrush=0,previousEngine=1;
    for(const speed of [3,6,10,16,22]){
      const s=createCrashMechanicsState(),hit=direction==='front'?front(speed):{point:{x:1,y:.8,z:1.325},normal:{x:1,y:0,z:0},impactSpeed:speed};
      applyCrashMechanicsImpact(s,hit);settle(s);
      assert.ok(s.maxCrush>previousCrush,'plastic crush is monotonic with speed');
      assert.ok(s.engine<=previousEngine,'higher delta-V cannot preserve more engine health');
      previousCrush=s.maxCrush;previousEngine=s.engine;
      if(speed<=6){approx(s.maxCrush,baseline[direction][speed],.000001);assert.equal(s.detachedParts.length,0)}
      if(speed>=16){const gain=s.maxCrush/baseline[direction][speed];assert.ok(gain>=1.49&&gain<=2.0,`${direction} at ${speed}m/s must visibly gain 1.5–2x, got ${gain}`)}
      if(direction==='side')assert.ok(s.wheels.front_right.health>.999,'far wheel stays shielded');
      if(direction==='side'&&speed===16)assert.ok(s.wheels.front_left.detached,'high-speed wheel strike breaks the local mount');
      if(direction==='front'&&speed===22){assert.equal(crashDriveEffects(s).powerFactor,0);assert.ok(s.beams.some(b=>b.broken))}
      assert.equal(s.active,false,'stronger plastic crush still settles');
    }
  }
});

test('directional travel bounds retain a finite passenger-cell envelope at extreme speeds',()=>{
  const s=createCrashMechanicsState(),limits=crashCrushLimits(s.profile);
  approx(limits.x,1.2);approx(limits.y,.8);approx(limits.z,1.548);
  for(const axis of ['x','y','z']){
    const point={x:0,y:.8,z:0};point[axis]=axis==='x'?1:axis==='y'?1.9:2.15;
    const normal={x:0,y:0,z:0};normal[axis]=1;
    for(let i=0;i<12;i++)applyCrashMechanicsImpact(s,{point,normal,impactSpeed:90});
    for(const node of s.nodes)assert.ok(Math.hypot((node.plastic.x-node.rest.x)/limits.x,(node.plastic.y-node.rest.y)/limits.y,(node.plastic.z-node.rest.z)/limits.z)<=1.000001);
  }
});

test('authored truck mounts and rear-engine bus layouts override sedan assumptions',()=>{
  const profile={halfWidth:1.4,halfLength:5,height:3,wheelTrack:2.5,wheelBase:5.9,
    partPoints:{door_front_left:{x:1.25,y:1.4,z:3.3}},
    wheelPositions:{front_left:{x:1.25,y:.58,z:3.4}},
    componentPoints:{engine:{x:0,y:.9,z:-4.2},radiator:{x:0,y:.9,z:-4.65}}};
  const state=createCrashMechanicsState(profile);
  assert.deepEqual(state.parts.door_front_left.point,profile.partPoints.door_front_left);
  assert.deepEqual(state.parts.wheel_front_left.point,profile.wheelPositions.front_left);
  applyCrashMechanicsImpact(state,{point:{x:1.25,y:.6,z:3.6},normal:{x:1,y:0,z:0},impactSpeed:27});
  assert.ok(state.wheels.front_left.detached);assert.equal(state.wheels.front_right.detached,false);
  assert.equal(state.engine,1,'front wheel strike does not damage rear engine');
  applyCrashMechanicsImpact(state,{point:{x:0,y:.9,z:-5},normal:{x:0,y:0,z:-1},impactSpeed:25});
  assert.ok(state.engine<.3);assert.ok(state.radiator<.2);
  resetCrashMechanics(state);assert.deepEqual(state.parts.wheel_front_left.point,profile.wheelPositions.front_left);
  assert.equal(state.engine,1);
});

test('real debris moves and settles in world space, persisting until explicit cleanup',()=>{
  const debris=createCrashDebrisState({position:{x:100,y:1.1,z:200},velocity:{x:8,y:3,z:2},angularVelocity:{x:3,y:1,z:2},radius:.15});
  for(let i=0;i<1200;i++)stepCrashDebris(debris,1/60,()=>2);
  assert.equal(debris.settled,true);assert.ok(debris.position.x>102);assert.ok(debris.position.z>200);
  approx(debris.position.y,2.15);approx(Math.hypot(...Object.values(debris.quaternion)),1);
  const stored=JSON.stringify(debris);stepCrashDebris(debris,100,()=>0);assert.equal(JSON.stringify(debris),stored);
});

test('renderer quaternion getters and invalid quaternion inputs stay finite',()=>{
  class Quaternion {get x(){return .2} get y(){return .4} get z(){return .1} get w(){return .8}}
  for(const quaternion of [new Quaternion(),{x:NaN,y:0,z:0,w:Infinity},{x:0,y:0,z:0,w:0},null]){
    const state=createCrashDebrisState({position:{x:1,y:2,z:3},quaternion});
    stepCrashDebris(state,.1);assert.ok(Object.values(state.quaternion).every(Number.isFinite));
    approx(Math.hypot(...Object.values(state.quaternion)),1);
  }
});
