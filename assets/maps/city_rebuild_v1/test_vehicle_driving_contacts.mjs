import test from 'node:test';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {readFile} from 'node:fs/promises';
import {registerHooks} from 'node:module';
import {stepCar,CAR,createDemoCar,carCorners,carFits} from './car_drive.mjs';
import {createVehicleFleet} from './vehicle_fleet.mjs';
import {polygonVehicleContact} from './vehicle_contact.mjs';
import {moveVehicleWithContacts} from './vehicle_contact_motion.mjs';
import {buildVehicleCollisionShape} from './vehicle_collision_shape.mjs';
import {ARTIST_VEHICLE_PROFILES,createArtistVehicle} from './vehicle_fleet_models.mjs';
const vendor=process.env.MAFIOZY_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const T=await import(pathToFileURL(vendor+'build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js')),{RoundedBoxGeometry}=await import('../../../tools/vehicle_fleet_qa/RoundedBoxGeometry.mjs');
const fireProfile=ARTIST_VEHICLE_PROFILES.find(p=>p.id==='fire_engine'),bytes=await readFile(new URL('./models/artist_vehicle_pack/'+fireProfile.modelFile,import.meta.url)),fireSource=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
const cars=[createDemoCar(T,RoundedBoxGeometry),createArtistVehicle(T,RoundedBoxGeometry,fireSource,fireProfile)];
const shapes=cars.map(car=>({...CAR,...car.profile,...buildVehicleCollisionShape(T,car)}));
const rotate=(x,z,a)=>({x:x*Math.cos(a)+z*Math.sin(a),z:-x*Math.sin(a)+z*Math.cos(a)});
function wall(angle){const polygon=[[0,-100],[8,-100],[8,100],[0,100]].map(([x,z])=>{const p=rotate(x,z,angle);return[p.x,p.z]});const allowed=()=>true;allowed.contactAt=(x,z,yaw,p)=>polygonVehicleContact(carCorners(x,z,yaw,p),polygon);allowed.poseAllowed=(x,z,yaw,p)=>!allowed.contactAt(x,z,yaw,p);return allowed}
function stub(id,p,x=0,z=0,speed=0){const calls=[];return{id,car:{object:new T.Group(),profile:{...p,id},wheels:[],shell:[],doors:new Map(),seats:[],update(){}},state:{x,z,yaw:0,travelYaw:0,speed,vehicleProfile:p},damage:{state:{hp:100},contactImpact(c){calls.push(c);return true},update(){},dispose(){},stats(){return{}}},roll:{update(){},impact(){},stats(){return{angle:0}}},tyres:{state:[],effects:{},update(){},dispose(){}},trunk:{update(){},dispose(){},stats(){return{}}},hood:{update(){},dispose(){}},calls}}
const energy=(s,p,mass=1)=>mass*.5*(s.vx*s.vx+s.vz*s.vz+((p.collisionHalfWidth??p.halfWidth)**2+(p.collisionHalfLength??p.halfLength)**2)/3*(s.yawRate||0)**2);

test('actual red/fire closed hulls coast through a 2cm wall clearance at six world headings',()=>{
 for(const p of shapes)for(const angle of [0,.3,.78,1.3,2.4,-2.1]){const offset=-Math.max(...p.collisionHull.map(v=>v[0]))-.02,start={...rotate(offset,0,angle),yaw:angle,travelYaw:angle,speed:8,vehicleProfile:p};let s=start;const world=wall(angle);assert(carFits(s.x,s.z,s.yaw,world,p));for(let i=0;i<120;i++){s=stepCar(s,{},1/120,world);assert(!s.bumped,'clear hull must not collide');assert(carFits(s.x,s.z,s.yaw,world,p))}assert(Math.hypot(s.x-start.x,s.z-start.z)>6.5)}
});
test('actual red/fire hulls scrape rotated walls without energy gain, and can reverse out of contact',()=>{
 for(const p of shapes)for(const angle of [0,.51,1.2,2.4]){const world=wall(angle),offset=-Math.max(...p.collisionHull.map(v=>v[0]))-.035;let s={...rotate(offset,0,angle),yaw:angle,travelYaw:angle+Math.atan2(2,8),speed:Math.hypot(2,8),vehicleProfile:p};let contacts=0;for(let i=0;i<120;i++){const before=Math.abs(s.speed);s=stepCar(s,{},1/120,world);contacts+=Number(s.bumped);assert(carFits(s.x,s.z,s.yaw,world,p),'scrape remains outside wall');assert(Math.abs(s.speed)<=before+1e-8)}assert(contacts>0);assert(Math.hypot(s.vx,s.vz)>2,'tangent motion survives');
  // Place the nose against a wall using this hull's actual support plane.
  const nose=Math.max(...carCorners(0,0,Math.PI/2,p).map(v=>v[0]));let reverse={x:-nose+.01,z:0,yaw:Math.PI/2,travelYaw:Math.PI/2,speed:0,vehicleProfile:p};for(let i=0;i<120;i++)reverse=stepCar(reverse,{reverse:true},1/120,wall(0));assert(reverse.x<-nose-.5,'reverse moves away from shallow initial overlap');assert(reverse.speed<0);
 }
});
test('active actual-shape car transfers its contact-time velocity to passive true mass exactly once',()=>{
 const open=()=>true,fleet=createVehicleFleet(T,{scene:new T.Scene(),RoundedBox:RoundedBoxGeometry,world:()=>open});
 try{const pa={...shapes[0],massKg:1500},pb={...shapes[1],massKg:10500},gap=.035,zA=Math.max(...pa.collisionHull.map(v=>v[1])),zB=-Math.min(...pb.collisionHull.map(v=>v[1]));const a=fleet.addCar(stub('active',pa,0,0,16)),b=fleet.addCar(stub('fire',pb,0,zA+zB+gap));const before={...a.state},after=stepCar(before,{},1/60,fleet.blockingWorld(open));assert.equal(after.contact?.otherVehicle,b.id);const c=after.contact;assert(c.velocity.z>15.8);assert(c.incomingPose.z>0);const result=fleet.resolve(before,after,c);assert(result.resolved);assert(Math.abs(result.deltaVA/result.deltaVB-7)<1e-8);
  assert(Math.abs(1500*c.velocity.z-1500*after.vz-10500*b.state.vz)<1e-6,'contact-time momentum preserved');assert(energy(after,pa,1500)+energy(b.state,pb,10500)<=energy({vx:c.velocity.x,vz:c.velocity.z,yawRate:c.incomingYawRate},pa,1500)+1e-6);assert.equal(fleet.stats().contacts,1);
 }finally{fleet.dispose()}
});
test('a faster receding passive vehicle cannot brake an active car when the two-body impulse is separating',()=>{
 const open=()=>true,fleet=createVehicleFleet(T,{scene:new T.Scene(),RoundedBox:RoundedBoxGeometry,world:()=>open});
 try{const p={...CAR,massKg:1500},a=fleet.addCar(stub('active',p,0,0,5)),b=fleet.addCar(stub('away',p,0,4.48+.015,8)),before={...a.state},after=stepCar(before,{},1/60,fleet.blockingWorld(open));assert(after.contact?.otherVehicle);const speedAtContact=Math.hypot(after.contact.velocity.x,after.contact.velocity.z),result=fleet.resolve(before,after,after.contact);assert.equal(result.resolved,false);assert(Math.abs(after.speed)>speedAtContact-.001,'separating pair must restore the incoming velocity instead of keeping temporary wall response');assert.equal(fleet.stats().contacts,0);assert.equal(b.state.speed,8);
 }finally{fleet.dispose()}
});
test('contact helper preserves total translation+rotation energy for deterministic off-centre scrapes',()=>{
 for(const p of shapes)for(let i=0;i<80;i++){const angle=i*.27,world=wall(angle),offset=-Math.max(...p.collisionHull.map(v=>v[0]))-.01,velocity=rotate(1+(i%7),5+(i%11),angle),s={...rotate(offset,0,angle),yaw:angle,travelYaw:Math.atan2(velocity.x,velocity.z),speed:Math.hypot(velocity.x,velocity.z),vx:velocity.x,vz:velocity.z,yawRate:Math.sin(i)*1.2};const out=moveVehicleWithContacts(s,s,1/120,{shape:p,fits:(x,z,yaw)=>carFits(x,z,yaw,world,p),contactAt:world.contactAt});assert(energy(out,p)<=energy(s,p)+1e-8);assert([out.x,out.z,out.yaw,out.speed,out.travelYaw].every(Number.isFinite))}
});
