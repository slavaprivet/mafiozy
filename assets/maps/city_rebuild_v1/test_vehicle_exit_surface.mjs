import assert from 'node:assert/strict';
import {createVehicleExitSurface,createExitPoseFloorSampler,createExitSwimHandoff} from './vehicle_exit_surface.mjs';

for(const fps of [30,60,144]){
  const dt=1/fps,waterAt=x=>x>=1?{level:-.18,depth:6.82,floor:-7}:null;
  const surface=createVehicleExitSurface({position:{x:.99,y:0,z:0},groundHeight:x=>x>=1?-7:0,waterAt});
  let result=surface.update({x:1.01,z:0,dt});
  assert.ok(result.y>-.02,'entering deep water must not teleport onto its bed');
  assert.equal(result.grounded,false);
  for(let i=0;i<fps;i++){
    result=surface.update({x:1.01,z:0,dt,hop:Math.max(0,.28*Math.sin(Math.min(Math.PI,i/fps*Math.PI*4)))});
    assert.ok(result.y>=-.23-1e-8,'recovering body stays at water surface');
    assert.ok(result.water);
  }
  assert.equal(result.grounded,true);assert.equal(result.velocityY,0);assert.ok(Math.abs(result.y+.23)<1e-8);
  const floating=createVehicleExitSurface({position:{x:2,y:-7,z:0},groundHeight:()=>-7,waterAt});
  assert.ok(Math.abs(floating.state.y+.23)<1e-8,'water departure clamps above seabed immediately');
  assert.ok(Math.abs(floating.floorHeight(2,0)+.23)<1e-8);

  const cliff=createVehicleExitSurface({position:{x:.99,y:4,z:0},groundHeight:x=>x<1?4:0});
  result=cliff.update({x:1.01,z:0,dt});assert.equal(result.grounded,false);assert.ok(result.y>3.98);
  let age=dt;
  while(!result.grounded&&age<2){const before=result.y;result=cliff.update({x:1.01,z:0,dt});assert.ok(result.y<=before&&result.y>=0);age+=dt;}
  assert.equal(result.y,0);assert.equal(result.grounded,true);
  assert.ok(Math.abs(age-Math.sqrt(8/18))<=dt+.00001,'edge gravity is consistent across frame rates');
}

const references=[];
const roof=createVehicleExitSurface({position:{x:0,y:6,z:0},groundHeight:(x,z,referenceY)=>{references.push(referenceY);return referenceY>5?6:0;}});
const roofHop=roof.update({x:.1,z:0,dt:1/60,hop:.28});assert.equal(roofHop.y,6.28);assert.equal(roof.state.y,6.28);
assert.equal(roof.floorHeight(.1,0),6);assert.ok(references.every(y=>y===6),'support uses floor reference, not zero or visual hop');
const wall=createVehicleExitSurface({position:{x:.9,y:0,z:0},groundHeight:x=>x<1?0:2});
let blocked=wall.update({x:1.1,z:0,dt:1/60});assert.equal(blocked.blocked,true);assert.equal(blocked.x,.9);assert.equal(blocked.y,0);
blocked=wall.update({x:2,z:0,dt:.1});assert.equal(blocked.blocked,true);assert.equal(wall.state.x,.9);
const ramp=createVehicleExitSurface({position:{x:0,y:0,z:0},groundHeight:x=>x*.35});
for(let i=1;i<=40;i++){const p=ramp.update({x:i*.05,z:0,dt:1/60});assert.equal(p.grounded,true);assert.ok(Math.abs(p.y-i*.05*.35)<1e-9);}

for(const floor of [(x,z)=>.3*x-.2*z,(x,z)=>x>.17?.2:0]){
  let calls=0;
  const sample=createExitPoseFloorSampler({x:0,z:0},(x,z)=>{calls++;return floor(x,z);});
  for(let iz=0;iz<=180;iz++)for(let ix=0;ix<=180;ix++){
    const x=-1.8+ix*.02,z=-1.8+iz*.02;
    assert.ok(sample(x,z)>=floor(x,z)-1e-9,'conservative cells clear slopes and steps');
  }
  assert.equal(sample.stats.outside,0);assert.ok(calls<=289,'terrain query cost is bounded by grid, not vertex count');assert.equal(calls,sample.stats.samples);
  const before=calls;for(let i=0;i<10000;i++)sample(.1,.2);assert.equal(calls,before,'repeat skin points reuse terrain nodes');
}
assert.throws(()=>createVehicleExitSurface({position:{x:0,y:0,z:0},groundHeight:()=>NaN}));
assert.throws(()=>roof.update({x:0,z:0,dt:1/60,hop:-1}));
console.log('PASS exit surface: deep-water recovery, ballistic ledges at 30/60/144 fps, roof references, hop separation, walls and slopes; conservative skin grid <=289 floor samples');

for(const fps of [30,60,144]){
  const handoff=createExitSwimHandoff({fromY:-.23,waterLevel:-.18});
  let previous=-.23,result=previous;
  for(let i=1;i<=Math.ceil(fps*.6);i++){
    const age=i/fps,target=-7+6.1*Math.min(1,age/.4);
    result=handoff.update(target,1/fps);
    assert.ok(result>=-1.23-1e-8,'warming swim target cannot pull exit pose to seabed');
    assert.ok(Math.abs(result-previous)<.2*60/fps,'swim handoff stays smooth at supported frame rates');
    if(age<.45)assert.equal(handoff.done,false);
    previous=result;
  }
  assert.equal(handoff.done,true);assert.ok(Math.abs(result+.9)<1e-8,'handoff ends at the current warm swim height');
}
const cold=createExitSwimHandoff({fromY:-.23,waterLevel:-.18});
for(let i=0;i<120;i++)assert.ok(cold.update(-7,1/60)>=-1.23-1e-8);
assert.equal(cold.done,false,'elapsed blend time alone cannot release a cold target');
let warm=cold.update(-.9,1/60);assert.equal(cold.done,false,'a suddenly warm late target cannot snap on release');
for(let i=0;i<10&&!cold.done;i++)warm=cold.update(-.9,1/60);
assert.ok(Math.abs(warm+.9)<1e-8);assert.equal(cold.done,true);
const shallow=createExitSwimHandoff({fromY:-.23,waterLevel:-.18});
assert.equal(shallow.update(.1,.45),.1,'a shallow target may lift the root');assert.equal(shallow.done,true);
assert.throws(()=>cold.update(NaN,1/60));assert.throws(()=>cold.update(0,-1));
console.log('PASS exit swim handoff: changing -7 to -.9 target, no seabed drop, smooth frames, exact endpoint, cold-target hold and shallow lift');
