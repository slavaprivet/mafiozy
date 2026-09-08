import assert from 'node:assert/strict';
import {stepCar,carOverlapsCircle} from './car_drive.mjs';
import {EXIT,exitKind,planMovingExit,departurePoint,launchExitBody,stepExitBody} from './car_exit.mjs';
const clear=()=>true,base={x:0,z:0,yaw:0,speed:0};
assert.equal(exitKind(0),'walk');assert.equal(exitKind(EXIT.tumbleSpeed),'walk');assert.equal(exitKind(EXIT.tumbleSpeed+.01),'tumble');assert.equal(exitKind(-8),'tumble');
assert(carOverlapsCircle(base,.9,0,.4));assert(!carOverlapsCircle(base,1.9,0,.58));
assert(carOverlapsCircle(base,0,0,0),'point probes inside the car must be blocked');
assert(carOverlapsCircle({...base,yaw:Math.PI/2},2,0,0),'point probes respect car rotation');
assert(!carOverlapsCircle(base,2,0,0),'point probes outside the car remain clear');
let checks=0;
for(const speed of [0,2.2,8,22,-2.2,-6])for(const yaw of [0,Math.PI/2])for(const side of [-1,1]){
 const initial={...base,speed,yaw},plan=planMovingExit(initial,side,clear,clear);assert(plan&&plan.side===side);assert.equal(initial.speed,speed,'planning must not mutate/stop car');
 let car={...initial};for(let i=0;i<33;i++)car=stepCar(car,{},EXIT.releaseSeconds/33,clear);
 assert(Math.abs(speed)<.5||Math.abs(car.speed)>0,'car coasts while opening door');
 const release=departurePoint(car,side,plan.distance,1);assert(!carOverlapsCircle(car,release.x,release.z,EXIT.radius));
 let body=launchExitBody(release,car,side,plan.kind),sawAir=false;const carAtRelease={...car};
 for(let i=0;i<180&&!body.done;i++){
  const safeCar=(x,z)=>clear(x,z);safeCar.poseAllowed=(x,z,yaw)=>!carOverlapsCircle({x,z,yaw},body.x,body.z,EXIT.radius);
  car=stepCar(car,{},1/60,safeCar);body=stepExitBody(body,1/60,(x,z)=>!carOverlapsCircle(car,x,z,0));sawAir||=body.y>0;
  assert(!carOverlapsCircle(car,body.x,body.z,EXIT.radius-.01),'detached body stays outside the car');assert(Number.isFinite(body.y)&&body.y>=0);
 }
 assert(body.done&&body.y===0&&body.vx===0&&body.vz===0);assert.equal(sawAir,plan.kind==='tumble');
 if(Math.abs(speed)>1)assert(Math.hypot(car.x-carAtRelease.x,car.z-carAtRelease.z)>.1,'car keeps rolling after player is out');checks++;
}
// A wall beside the left door selects the right; both sides blocked keeps the player inside.
assert.equal(planMovingExit({...base,speed:8},1,clear,(x,z)=>x<1.3)?.side,-1);
assert.equal(planMovingExit({...base,speed:8},1,clear,(x,z)=>Math.abs(x)<1.3),null);
assert.equal(planMovingExit({...base,speed:18},1,clear,(x,z)=>z<3),null,'predict upcoming blocked exit before committing');
let falling=launchExitBody({x:0,z:0},{...base,speed:22},1,'tumble');
for(let i=0;i<150&&!falling.done;i++){falling=stepExitBody(falling,1/60,(x,z)=>z<2);assert(falling.z<2-EXIT.radius+.01,'rolling cannot tunnel through wall')}
assert(falling.done);
assert.throws(()=>stepExitBody(falling,NaN,clear));
console.log(`PASS ${checks} moving exits: low/high/reverse, both doors, coast, collision-safe landing, blocked-side fallback, wall and recovery`);
