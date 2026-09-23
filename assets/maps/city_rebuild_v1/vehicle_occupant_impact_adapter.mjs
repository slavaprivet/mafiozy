// Collision-only adapter from authoritative motion evidence to the existing
// vehicle_impact_reaction spring. This module owns no animation state and must
// never be updated per frame: the established reaction/cabin guard remains the
// sole spring and the sole owner of bounded occupant pose.
import {createOccupantCrashPulseEvent} from './vehicle_occupant_crash_pulse_event.mjs';
import {VEHICLE_IMPACT_REACTION} from './vehicle_impact_reaction.mjs';

const finite=value=>Number.isFinite(value);
const vector=value=>!!value&&finite(value.x)&&finite(value.y??0)&&finite(value.z);
const angular=value=>!!value&&finite(value.x??0)&&finite(value.y??0)&&finite(value.z??0);

function hasConfirmedMotion(input){
 const velocityPair=vector(input.beforeVelocity)&&vector(input.afterVelocity);
 const impulse=vector(input.contactImpulse)&&finite(input.massKg)&&input.massKg>0;
 const angularPair=angular(input.beforeAngularVelocity)&&angular(input.afterAngularVelocity);
 const angularImpulse=angular(input.angularImpulse)&&angular(input.inertia)&&[input.inertia.x??0,input.inertia.y??0,input.inertia.z??0].some(value=>finite(value)&&value>0);
 return velocityPair||impulse||angularPair||angularImpulse;
}

function exactPhysicalDeltaV(input){
 if(finite(input.physicalDeltaV)&&input.physicalDeltaV>=0)return input.physicalDeltaV;
 if(vector(input.beforeVelocity)&&vector(input.afterVelocity))return Math.hypot(input.afterVelocity.x-input.beforeVelocity.x,(input.afterVelocity.y??0)-(input.beforeVelocity.y??0),input.afterVelocity.z-input.beforeVelocity.z);
 if(vector(input.contactImpulse)&&finite(input.massKg)&&input.massKg>0)return Math.hypot(input.contactImpulse.x,input.contactImpulse.y??0,input.contactImpulse.z)/input.massKg;
 return 0;
}

// Returns two explicitly separated contracts. `physicalDeltaV` is immutable,
// exact authority data; presentation tuning can never overwrite or alias it.
// `impactSpeed` is deliberately neither read nor copied.
export function createConfirmedOccupantImpactEnvelope(input={},tuning={}){
 if(!input||typeof input!=='object'||('physicalDeltaV'in input&&(!finite(input.physicalDeltaV)||input.physicalDeltaV<0)))return null;
 if(!hasConfirmedMotion(input))return null;
 const pulse=createOccupantCrashPulseEvent(input);if(!pulse)return null;
 // Fold angular roll/pitch/yaw into the same bounded planar spring. Rollover
 // changes direction, not the cabin limits or the number of oscillators.
 const localX=pulse.localImpulse.lateral+pulse.angularImpulse.roll*.70+pulse.angularImpulse.yaw*.18;
 const localZ=pulse.localImpulse.longitudinal+pulse.angularImpulse.pitch*.70+pulse.localImpulse.vertical*.15;
 const length=Math.hypot(localX,localZ);if(length<1e-9)return null;
 const c=Math.cos(input.yaw||0),s=Math.sin(input.yaw||0);
 const normal=Object.freeze({x:(localX*c+localZ*s)/length,y:0,z:(-localX*s+localZ*c)/length});
 const presentationIntensity=Math.max(0,Math.min(1,pulse.severity*(finite(tuning.intensityScale)?Math.max(0,tuning.intensityScale):1)));
 const reactionDeltaV=VEHICLE_IMPACT_REACTION.minImpactSpeed+presentationIntensity*(VEHICLE_IMPACT_REACTION.fullImpactSpeed-VEHICLE_IMPACT_REACTION.minImpactSpeed);
 const presentation=Object.freeze({normal,presentationIntensity,reactionDeltaV,occupantPulse:pulse});
 return Object.freeze({eventId:pulse.eventId,vehicleId:pulse.vehicleId,occurredAt:pulse.occurredAt,physicalDeltaV:exactPhysicalDeltaV(input),confirmedMotion:true,presentation});
}

export function createOccupantReactionContact(envelope){
 if(!envelope?.presentation)return null;
 // Compatibility facade is presentation-only and is never returned to damage.
 // The old reaction reads `deltaV`; its explicitly named source remains visible.
 const p=envelope.presentation,presentationContact=Object.freeze({eventId:envelope.eventId,vehicleId:envelope.vehicleId,normal:p.normal,presentationIntensity:p.presentationIntensity,reactionDeltaV:p.reactionDeltaV,deltaV:p.reactionDeltaV,presentationOnly:true});
 return presentationContact;
}

export function pushOccupantImpactEnvelope(reaction,envelope,yaw=0){
 const presentationContact=createOccupantReactionContact(envelope);
 return presentationContact?{envelope,presentationContact,accepted:!!reaction?.impact?.(presentationContact,{yaw})}:{envelope:null,presentationContact:null,accepted:false};
}

export function pushConfirmedOccupantImpact(reaction,input,tuning){
 return pushOccupantImpactEnvelope(reaction,createConfirmedOccupantImpactEnvelope(input,tuning),input?.yaw||0);
}

// Pair impulse adapter. The physics solver remains authoritative; this merely
// packages each body's before/after velocity and impulse for presentation.
export function createPairOccupantImpactContacts({eventId,occurredAt=0,result,a,b,rollA=null,rollB=null}={}){
 if(!result?.resolved||!eventId||!a?.vehicleId||!b?.vehicleId)return null;
 const one=(body,next,contactImpulse,physicalDeltaV,roll)=>createConfirmedOccupantImpactEnvelope({
  eventId:String(eventId)+':'+body.vehicleId,vehicleId:body.vehicleId,occurredAt,yaw:body.yaw||0,
  physicalDeltaV,beforeVelocity:{x:body.vx,y:0,z:body.vz},afterVelocity:{x:next.vx,y:0,z:next.vz},contactImpulse:{x:contactImpulse?.x||0,y:0,z:contactImpulse?.z||0},massKg:body.massKg,
  beforeAngularVelocity:{x:0,y:body.yawRate||0,z:roll?.before||0},afterAngularVelocity:{x:0,y:next.yawRate||0,z:roll?.after||0},
 });
 const first=one(a,result.a,result.impulseA,result.deltaVA,rollA),second=one(b,result.b,result.impulseB,result.deltaVB,rollB);
 return first&&second?Object.freeze({a:first,b:second}):null;
}

export const OCCUPANT_IMPACT_ADAPTER_COVERAGE=Object.freeze({
 fleetPair:'ready: resolveVehiclePairImpulse supplies confirmed before/after velocity, yaw rate, impulses and mass',
 fleetWall:'needs host event id plus before/after state; do not use contact.impactSpeed alone',
 localFleetOccupants:'ready through the existing vehicle impact reaction and cabin pose guard',
 sourcePlayer:'gap: source drive controller has no impactReaction/occupant pose connection and walk_preview is actively owned',
 sourceNpc:'gap: source traffic has no per-vehicle confirmed delta-V presentation receipt or occupant reaction owner',
 rollover:'adapter-ready when host supplies before/after roll angular velocity from vehicle_rollover stats',
});

export const OCCUPANT_IMPACT_ADAPTER_ALLOCATION_NOTES=Object.freeze({
 cadence:'collision events only, never per-frame',
 envelopeCreationSourceObjects:13,
 pushAdditionalSourceObjects:2,
 pairCreationSourceObjects:39,
 explanation:'Envelope: 10 pulse objects plus normal, presentation, and immutable physical/presentation envelope. Push adds one presentation-only compatibility contact and one receipt. Pair packaging adds six input/vector objects per vehicle and one A/B wrapper: 2*(13+6)+1=39. Set entries belong to the existing reaction dedupe.',
 existingFrameCost:'unchanged: the existing reaction spring/update/sample and cabin certification remain the only per-frame work',
});

