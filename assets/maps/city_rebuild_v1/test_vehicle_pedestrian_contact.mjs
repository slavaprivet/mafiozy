import assert from 'node:assert/strict';
import {sweptVehiclePedestrianContact,vehiclePedestrianImpact,createVehiclePedestrianContact} from './vehicle_pedestrian_contact.mjs';

const body={halfLength:.75,halfWidth:.4,pedestrianRadius:.2};
assert(sweptVehiclePedestrianContact({r:0,c:0},{r:0,c:1,angle:0},{r:0,c:1.55},body),'bonnet reaches actor before centre');
assert(sweptVehiclePedestrianContact({r:0,c:0},{r:0,c:2,angle:0},{r:.55,c:1},body),'swept side contact');
assert.equal(sweptVehiclePedestrianContact({r:0,c:0},{r:0,c:2,angle:0},{r:.7,c:1},body),null,'clear lateral gap stays clear');
assert.equal(vehiclePedestrianImpact(.2),null);
assert.equal(vehiclePedestrianImpact(1).tier,'shove');
assert.equal(vehiclePedestrianImpact(3).tier,'fall');
assert.equal(vehiclePedestrianImpact(8).tier,'hard');
assert.equal(vehiclePedestrianImpact(18).tier,'severe');
assert(vehiclePedestrianImpact(18).damage>vehiclePedestrianImpact(8).damage);

let now=1000,events=[];const car={},person={},tracker=createVehiclePedestrianContact({worldScale:4.1,cooldownMs:900});
const poses=new Map([[car,{r:0,c:0,angle:0,halfLength:.75,halfWidth:.4}]]),people=new Map([[person,{r:0,c:1.2}]]);
const step=()=>tracker.step({vehicles:[car],actors:[person],dt:.1,now,vehiclePose:v=>poses.get(v),actorPose:a=>people.get(a),onImpact:event=>events.push(event)});
assert.equal(step(),0,'first pose only seeds sweep');
poses.set(car,{r:0,c:.6,angle:0,halfLength:.75,halfWidth:.4});now+=100;assert.equal(step(),1);assert.equal(events[0].impact.tier,'severe');
poses.set(car,{r:0,c:1,angle:0,halfLength:.75,halfWidth:.4});now+=100;assert.equal(step(),0,'overlap cooldown prevents repeated damage');
poses.set(car,{r:0,c:10,angle:0,halfLength:.75,halfWidth:.4});now+=100;assert.equal(step(),0,'teleport cannot run over the city');
assert.equal(tracker.stats().contacts,1);assert.equal(tracker.stats().skippedTeleports,1);
console.log('PASS: swept bonnet/side geometry, speed tiers, cooldown and teleport rejection');
