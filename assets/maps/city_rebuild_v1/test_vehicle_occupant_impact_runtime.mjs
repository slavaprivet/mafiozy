import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createOccupantCrashPulseEvent} from './vehicle_occupant_crash_pulse_event.mjs';
import {createConfirmedOccupantImpactEnvelope,createOccupantReactionContact,pushConfirmedOccupantImpact} from './vehicle_occupant_impact_adapter.mjs';
import {createFleetPairOccupantContracts,deliverFleetOccupantContact} from './vehicle_occupant_impact_fleet_seam.mjs';
import {createVehicleImpactReaction,VEHICLE_IMPACT_REACTION as R} from './vehicle_impact_reaction.mjs';
import {resolveVehiclePairImpulse} from './vehicle_pair_impulse.mjs';
import {createVehicleFleet} from './vehicle_fleet.mjs';
import {CAR} from './car_drive.mjs';

const motion=(eventId,extra={})=>({eventId,vehicleId:'car',yaw:0,beforeVelocity:{x:0,y:0,z:0},afterVelocity:{x:8,y:0,z:0},...extra});

test('runtime accepts angular-only authority and rejects missing or non-finite evidence',()=>{
 const angularOnly={eventId:'angular',vehicleId:'car',yaw:.2,beforeAngularVelocity:{z:0},afterAngularVelocity:{z:5}};
 const pulse=createOccupantCrashPulseEvent(angularOnly),envelope=createConfirmedOccupantImpactEnvelope(angularOnly);
 assert(pulse);assert(envelope);assert.equal(envelope.physicalDeltaV,0);assert(envelope.presentation.presentationIntensity>0&&envelope.presentation.presentationIntensity<=1);
 for(const bad of [
  {eventId:'missing',vehicleId:'car',massKg:1500},
  {eventId:'impulse',vehicleId:'car',contactImpulse:{x:Infinity,z:0},massKg:1500},
  {eventId:'angular-nan',vehicleId:'car',beforeAngularVelocity:{z:0},afterAngularVelocity:{z:NaN}},
 ])assert.equal(createOccupantCrashPulseEvent(bad),null);
 for(const bad of [
  {eventId:'raw',vehicleId:'car',impactSpeed:90,normal:{x:0,z:1}},
  motion('velocity-nan',{beforeVelocity:{x:NaN,z:0}}),
  motion('physical-nan',{physicalDeltaV:NaN}),
  motion('physical-infinity',{physicalDeltaV:Infinity}),
  motion('physical-negative',{physicalDeltaV:-1}),
 ])assert.equal(createConfirmedOccupantImpactEnvelope(bad),null);
});

test('physical delta-V is immutable and independent from bounded presentation tuning',()=>{
 const input=motion('tuning',{physicalDeltaV:11,beforeVelocity:{x:0,y:0,z:15},afterVelocity:{x:0,y:0,z:4}}),low=createConfirmedOccupantImpactEnvelope(input,{intensityScale:.35}),high=createConfirmedOccupantImpactEnvelope(input,{intensityScale:1.8});
 assert.equal(low.physicalDeltaV,11);assert.equal(high.physicalDeltaV,11);assert.notEqual(low.presentation.presentationIntensity,high.presentation.presentationIntensity);
 for(const envelope of [low,high]){assert(envelope.presentation.presentationIntensity>=0&&envelope.presentation.presentationIntensity<=1);assert(Object.isFrozen(envelope)&&Object.isFrozen(envelope.presentation)&&Object.isFrozen(envelope.presentation.normal));const contact=createOccupantReactionContact(envelope);assert(contact.presentationOnly);assert(!('physicalDeltaV'in contact));assert.equal(contact.deltaV,contact.reactionDeltaV)}
});

test('actual solver A/B deltas reach damage exactly while presentation replay deduplicates',()=>{
 const incoming={x:0,z:0,yaw:0,vx:14,vz:0,yawRate:.3,mass:1500,halfWidth:1,halfLength:2},otherIncoming={x:2,z:0,yaw:0,vx:0,vz:0,yawRate:0,mass:3000,halfWidth:1,halfLength:2},contact={point:{x:1,y:0,z:.45},normal:{x:1,y:0,z:0}},result=resolveVehiclePairImpulse(incoming,otherIncoming,contact);
 assert(result.resolved);const contracts=createFleetPairOccupantContracts({eventId:'fleet:a|b:1',occurredAt:1,aId:'a',bId:'b',result,incoming,otherIncoming,contact});assert(contracts);
 assert.equal(contracts.a.contact.physicalDeltaV,result.deltaVA);assert.equal(contracts.b.contact.physicalDeltaV,result.deltaVB);assert.equal(contracts.a.motion.physicalDeltaV,result.deltaVA);assert.equal(contracts.b.motion.physicalDeltaV,result.deltaVB);
 assert(Object.isFrozen(contracts)&&Object.isFrozen(contracts.a.contact)&&Object.isFrozen(contracts.a.motion));
 for(const side of ['a','b']){
  const reaction=createVehicleImpactReaction(),calls=[],record={id:side,state:{yaw:0}};
  record.damage={contactImpact(value){assert.equal(this,record.damage);calls.push(['damage',value]);return true}};
  record.roll={angularVelocity:0,stats(){assert.equal(this,record.roll);return{angularVelocity:this.angularVelocity}},impact(value){assert.equal(this,record.roll);calls.push(['roll',value]);this.angularVelocity+=side==='a'?.8:-.4;return true}};
  record.impactReaction={impact(value,options){assert.equal(this,record.impactReaction);calls.push(['reaction',value]);return reaction.impact(value,options)}};
  const contract=contracts[side],first=deliverFleetOccupantContact({record,contact:contract.contact,motion:contract.motion}),replay=deliverFleetOccupantContact({record,contact:contract.contact,motion:contract.motion});
  assert(first.reacted);assert.equal(replay.reacted,false);assert.equal(first.envelope.physicalDeltaV,result[side==='a'?'deltaVA':'deltaVB']);assert.equal(calls[0][1],contract.contact);assert(!('presentationIntensity'in contract.contact));assert(!('reactionDeltaV'in contract.contact));assert(first.presentationContact.presentationOnly);assert(!('physicalDeltaV'in first.presentationContact));assert.equal(reaction.sample().impacts,1);
 }
});

test('legal fleet states without optional yawRate retain physical damage for both cars',()=>{
 class Matrix4{}class BatchedMesh{}class RoundedBox{}
 const T={Matrix4,BatchedMesh},scene={add(object){object.parent=this}},makeObject=()=>({parent:null,userData:{},position:{set(){}},rotation:{y:0},traverse(visitor){visitor(this)},updateWorldMatrix(){},removeFromParent(){this.parent=null}});
 const stub=(id,z,massKg)=>{const calls=[],profile={...CAR,id,massKg},car={object:makeObject(),profile,wheels:[],shell:[],doors:new Map(),seats:[],update(){}},state={x:0,z,yaw:0,speed:0,travelYaw:0,vehicleProfile:profile};return{id,car,state,calls,damage:{state:{maxHp:240,hp:240,smoking:false,burning:false,destroying:false,wrecked:false},contactImpact(contact){calls.push(contact);return true},stats(){return this.state}},roll:{unstable:false,angle:0,stats(){return{angle:0,angularVelocity:0}},impact(){return false},update(){},reset(){},dispose(){}},tyres:{state:[],effects:{speedFactor:1},update(){},reset(){},dispose(){}},trunk:{update(){},reset(){},dispose(){},stats(){return{}}},hood:{update(){},reset(){},dispose(){},stats(){return{}}}}};
 const fleet=createVehicleFleet(T,{scene,RoundedBox,world:()=>()=>true}),aa=stub('a',0,1500),bb=stub('b',4.48,12000),a=fleet.addCar(aa),b=fleet.addCar(bb);
 assert(!('yawRate'in aa.state));assert(!('yawRate'in bb.state));
 const before={...a.state,speed:16},after={...before,speed:0},contact={point:{x:0,y:.8,z:2.24},normal:{x:0,y:0,z:1},otherVehicle:'b'},result=fleet.resolve(before,after,contact);
 assert(result.resolved);assert.equal(aa.calls.length,1);assert.equal(bb.calls.length,1);assert.equal(aa.calls[0].physicalDeltaV,result.deltaVA);assert.equal(bb.calls[0].physicalDeltaV,result.deltaVB);assert.equal(a.impactReaction.sample().impacts,1);assert.equal(b.impactReaction.sample().impacts,1);fleet.dispose();
});

test('invalid confirmed presentation skips reaction but preserves A/B physical damage',()=>{
 const a={x:0,z:0,vx:14,vz:0,mass:1500,halfWidth:1,halfLength:2},b={x:2,z:0,vx:0,vz:0,mass:3000,halfWidth:1,halfLength:2},contact={point:{x:1,y:0,z:0},normal:{x:1,y:0,z:0}},result=resolveVehiclePairImpulse(a,b,contact),contracts=createFleetPairOccupantContracts({eventId:'bad-presentation',occurredAt:NaN,aId:'a',bId:'b',result,incoming:a,otherIncoming:b,contact});
 assert(contracts);for(const side of ['a','b']){let damage=0,reaction=0;const record={id:side,state:{yaw:0},damage:{contactImpact(value){assert.equal(value,contracts[side].contact);damage++;return true}},roll:{stats(){return{angularVelocity:0}},impact(){return false}},impactReaction:{impact(){reaction++;return true}}},receipt=deliverFleetOccupantContact({record,contact:contracts[side].contact,motion:contracts[side].motion,confirmed:true});assert.equal(damage,1);assert.equal(reaction,0);assert.equal(receipt.reacted,false);assert.equal(receipt.envelope,null)}
});

test('corrupt presentation-only impulse cannot suppress physical A/B damage or trigger raw fallback',()=>{
 const a={x:0,z:0,vx:14,vz:0,mass:1500,halfWidth:1,halfLength:2},b={x:2,z:0,vx:0,vz:0,mass:3000,halfWidth:1,halfLength:2},contact={point:{x:1,y:0,z:0},normal:{x:1,y:0,z:0}},solved=resolveVehiclePairImpulse(a,b,contact),result={...solved,impulseA:{x:NaN,z:solved.impulseA.z}},contracts=createFleetPairOccupantContracts({eventId:'bad-impulse',occurredAt:1,aId:'a',bId:'b',result,incoming:a,otherIncoming:b,contact});
 assert(contracts);assert.equal(contracts.a.motion,null);assert(contracts.b.motion);for(const side of ['a','b']){let damage=0,reaction=0;const record={id:side,state:{yaw:0},damage:{contactImpact(value){assert.equal(value,contracts[side].contact);damage++;return true}},roll:{stats(){return{angularVelocity:0}},impact(){return false}},impactReaction:{impact(){reaction++;return true}}},receipt=deliverFleetOccupantContact({record,contact:contracts[side].contact,motion:contracts[side].motion,confirmed:true});assert.equal(damage,1);assert.equal(reaction,side==='a'?0:1);assert.equal(receipt.reacted,side!=='a')}
});

test('existing analytical reaction retains exact 30/60/120/144 Hz parity',()=>{
 const input=motion('parity',{yaw:.63,beforeVelocity:{x:3,y:0,z:17},afterVelocity:{x:-5,y:1,z:2},beforeAngularVelocity:{x:0,y:0,z:0},afterAngularVelocity:{x:1,y:2,z:-3}}),results=[];
 for(const fps of [30,60,120,144]){const reaction=createVehicleImpactReaction();assert(pushConfirmedOccupantImpact(reaction,input).accepted);for(let i=0;i<fps;i++)reaction.update(1/fps);const sample=reaction.sample();assert(Math.hypot(sample.local.x,sample.local.z)<=R.maxOffset+1e-12);results.push(sample)}
 for(const sample of results.slice(1)){assert(Math.abs(sample.local.x-results[0].local.x)<1e-10);assert(Math.abs(sample.local.z-results[0].local.z)<1e-10)}
});

test('vehicle fleet remains a thin callback into the tested seam',()=>{
 const source=readFileSync(new URL('./vehicle_fleet.mjs',import.meta.url),'utf8');
 assert(source.includes("import {createFleetPairOccupantContracts,deliverFleetOccupantContact} from './vehicle_occupant_impact_fleet_seam.mjs'"));
 assert(source.includes('return deliverFleetOccupantContact({record,contact,motion:confirmedMotion,confirmed}).handled'));
 assert(source.includes('notifyContact(a,contracts.a.contact,contracts.a.motion,true)'));
 assert(source.includes('const contracts=createFleetPairOccupantContracts({eventId:'));
 assert(!source.includes('contactImpact?.(reactionContact)'));
});
