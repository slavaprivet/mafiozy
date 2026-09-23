// Event-only extraction of the tested crash pulse converter. No reaction,
// spring, frame update or presentation owner lives in this module.
const clamp=(value,min,max)=>Math.max(min,Math.min(max,value));
const finite=(value,fallback=0)=>Number.isFinite(value)?value:fallback;
const vector=(value={})=>({x:finite(value.x),y:finite(value.y),z:finite(value.z)});
export const OCCUPANT_CRASH_PULSE_EVENT=Object.freeze({minDeltaV:.32,fullDeltaV:16,maxLocalImpulse:4.6,maxAngularImpulse:2.8,onsetSeconds:.018,minDecaySeconds:.24,maxDecaySeconds:.72});
function validVector(value){return!!value&&Number.isFinite(value.x)&&Number.isFinite(value.y??0)&&Number.isFinite(value.z)}
function validAngularVector(value){return!!value&&[value.x??0,value.y??0,value.z??0].every(Number.isFinite)}
function worldToLocal(value,yaw){const c=Math.cos(yaw),s=Math.sin(yaw);return{x:value.x*c-value.z*s,y:value.y,z:value.x*s+value.z*c}}
function deltaFromMotion(input){
 if(validVector(input.beforeVelocity)&&validVector(input.afterVelocity)){const before=vector(input.beforeVelocity),after=vector(input.afterVelocity);return{x:after.x-before.x,y:after.y-before.y,z:after.z-before.z}}
 if(validVector(input.contactImpulse)&&Number.isFinite(input.massKg)&&input.massKg>0){const impulse=vector(input.contactImpulse);return{x:impulse.x/input.massKg,y:impulse.y/input.massKg,z:impulse.z/input.massKg}}
 return null;
}
function angularDelta(input){
 if(validAngularVector(input.beforeAngularVelocity)&&validAngularVector(input.afterAngularVelocity)){const before=vector(input.beforeAngularVelocity),after=vector(input.afterAngularVelocity);return{x:after.x-before.x,y:after.y-before.y,z:after.z-before.z}}
 if(validAngularVector(input.angularImpulse)&&validAngularVector(input.inertia)){const impulse=vector(input.angularImpulse),body=vector(input.inertia);return{x:body.x>0?impulse.x/body.x:0,y:body.y>0?impulse.y/body.y:0,z:body.z>0?impulse.z/body.z:0}}
 return null;
}
export function createOccupantCrashPulseEvent(input={}){
 if(!input||typeof input!=='object')return null;
 const vectorFields=['beforeVelocity','afterVelocity','contactImpulse'],angularFields=['beforeAngularVelocity','afterAngularVelocity','angularImpulse','inertia'];
 if(vectorFields.some(key=>key in input&&!validVector(input[key]))||angularFields.some(key=>key in input&&!validAngularVector(input[key]))||
  ('massKg'in input&&(!Number.isFinite(input.massKg)||input.massKg<=0))||('yaw'in input&&!Number.isFinite(input.yaw))||('occurredAt'in input&&!Number.isFinite(input.occurredAt)))return null;
 const yaw=finite(input.yaw),deltaV=deltaFromMotion(input),angular=angularDelta(input);if(!deltaV&&!angular)return null;
 const linear=deltaV||{x:0,y:0,z:0},turn=angular||{x:0,y:0,z:0},localDelta=worldToLocal(linear,yaw),linearMagnitude=Math.hypot(linear.x,linear.y,linear.z),angularMagnitude=Math.hypot(turn.x,turn.y,turn.z);
 const severity=clamp(Math.max((linearMagnitude-OCCUPANT_CRASH_PULSE_EVENT.minDeltaV)/(OCCUPANT_CRASH_PULSE_EVENT.fullDeltaV-OCCUPANT_CRASH_PULSE_EVENT.minDeltaV),angularMagnitude/4.5),0,1);
 if(!input.eventId||!input.vehicleId||severity<=0)return null;
 const linearScale=clamp(linearMagnitude/7,0,OCCUPANT_CRASH_PULSE_EVENT.maxLocalImpulse)/(linearMagnitude||1),angularScale=clamp(angularMagnitude/2.2,0,OCCUPANT_CRASH_PULSE_EVENT.maxAngularImpulse)/(angularMagnitude||1);
 return Object.freeze({eventId:String(input.eventId),vehicleId:String(input.vehicleId),occurredAt:finite(input.occurredAt),localImpulse:Object.freeze({lateral:-localDelta.x*linearScale,vertical:-localDelta.y*linearScale,longitudinal:-localDelta.z*linearScale}),angularImpulse:Object.freeze({pitch:-turn.x*angularScale,yaw:-turn.y*angularScale,roll:-turn.z*angularScale}),severity,onset:OCCUPANT_CRASH_PULSE_EVENT.onsetSeconds,decay:OCCUPANT_CRASH_PULSE_EVENT.minDecaySeconds+(OCCUPANT_CRASH_PULSE_EVENT.maxDecaySeconds-OCCUPANT_CRASH_PULSE_EVENT.minDecaySeconds)*severity});
}

