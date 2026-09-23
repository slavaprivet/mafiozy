// Exact fleet-facing packaging seam. Damage receives `contact`; occupant
// reaction receives only `presentationContact` created after roll authority.
import {createConfirmedOccupantImpactEnvelope,createOccupantReactionContact} from './vehicle_occupant_impact_adapter.mjs';

export function createFleetPairOccupantContracts({eventId,occurredAt=0,aId,bId,result,incoming,otherIncoming,contact}={}){
 if(!result?.resolved||!eventId||!aId||!bId||!incoming||!otherIncoming||!contact?.normal)return null;
 const finite=value=>Number.isFinite(value)?value:0;
 const finiteValues=[result.deltaVA,result.deltaVB,result.a?.vx,result.a?.vz,result.b?.vx,result.b?.vz,incoming.mass,otherIncoming.mass,contact.normal.x,contact.normal.z];
 if(!finiteValues.every(Number.isFinite)||result.deltaVA<0||result.deltaVB<0||incoming.mass<=0||otherIncoming.mass<=0)return null;
 const first=Object.freeze({...contact,impactSpeed:result.deltaVA,physicalDeltaV:result.deltaVA,slideSpeed:0,velocity:Object.freeze({x:result.a.vx,y:0,z:result.a.vz}),eventId});
 const second=Object.freeze({...contact,normal:Object.freeze({x:-contact.normal.x,y:-(Number.isFinite(contact.normal.y)?contact.normal.y:0),z:-contact.normal.z}),impactSpeed:result.deltaVB,physicalDeltaV:result.deltaVB,slideSpeed:0,velocity:Object.freeze({x:result.b.vx,y:0,z:result.b.vz}),eventId});
 // Match the solver's optional velocity/yaw normalization. Presentation may
 // reject other invalid evidence later, but the physical contacts above stay
 // available to damage and roll independently.
 const motion=(body,next,impulse,physicalDeltaV)=>[occurredAt,impulse?.x,impulse?.z,next.yawRate].every(Number.isFinite)?Object.freeze({eventId,occurredAt,physicalDeltaV,beforeVelocity:Object.freeze({x:finite(body.vx),y:0,z:finite(body.vz)}),afterVelocity:Object.freeze({x:next.vx,y:0,z:next.vz}),contactImpulse:Object.freeze({x:impulse.x,y:0,z:impulse.z}),massKg:body.mass,beforeYawRate:finite(body.yawRate),afterYawRate:next.yawRate}):null;
 return Object.freeze({a:Object.freeze({contact:first,motion:motion(incoming,result.a,result.impulseA,result.deltaVA)}),b:Object.freeze({contact:second,motion:motion(otherIncoming,result.b,result.impulseB,result.deltaVB)})});
}

export function createFleetOccupantPresentation({recordId,yaw,motion,rollBefore=0,rollAfter=0}={}){
 if(!recordId||!motion)return Object.freeze({envelope:null,presentationContact:null});
 const envelope=createConfirmedOccupantImpactEnvelope({...motion,eventId:String(motion.eventId)+':'+recordId,vehicleId:recordId,yaw,beforeAngularVelocity:{x:0,y:motion.beforeYawRate??0,z:rollBefore},afterAngularVelocity:{x:0,y:motion.afterYawRate??0,z:rollAfter}});
 return Object.freeze({envelope,presentationContact:createOccupantReactionContact(envelope)});
}

// Exact notify seam: physical contact stays with damage/roll; only the
// explicitly presentation-only facade enters the established reaction.
export function deliverFleetOccupantContact({record,contact,motion=null,confirmed=motion!=null}={}){
 if(!record||!contact)return Object.freeze({handled:false,damaged:false,rolled:false,reacted:false,envelope:null,presentationContact:null});
 const yaw=record.state?.yaw??0,rollBefore=record.roll?.stats?.().angularVelocity??0;
 const damaged=record.damage?.contactImpact?.(contact),rolled=record.roll?.impact?.(contact,yaw),rollAfter=record.roll?.stats?.().angularVelocity??0;
 const presentation=motion?createFleetOccupantPresentation({recordId:record.id,yaw,motion,rollBefore,rollAfter}):Object.freeze({envelope:null,presentationContact:null});
 // A confirmed path never falls through to legacy contact.impactSpeed.
 const reacted=confirmed?(presentation.presentationContact&&record.impactReaction?.impact?.(presentation.presentationContact,{yaw})):record.impactReaction?.impact?.(contact,{yaw});
 return Object.freeze({handled:!!(damaged||rolled||reacted),damaged:!!damaged,rolled:!!rolled,reacted:!!reacted,envelope:presentation.envelope,presentationContact:presentation.presentationContact});
}
