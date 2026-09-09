// Stateless samplers for host-authoritative animation events. The host supplies
// normalized progress; this module never starts attacks, awards hits or changes ammo.
const clamp01=value=>Math.max(0,Math.min(1,Number.isFinite(value)?value:0));
const smooth=(value,min=0,max=1)=>{const t=clamp01((value-min)/(max-min||1));return t*t*(3-2*t)};

export const HERO_ACTION_DURATIONS=Object.freeze({punch:.34,heavy:.50,kick:.62});

// Call exactly once for an already-admitted ordinary fists click. Keeping the
// roll explicit lets the authoritative host own event admission and replication.
export function selectOrdinaryMeleeType(randomValue){
 if(!Number.isFinite(randomValue)||randomValue<0||randomValue>=1)throw Error('Melee random value must be in [0,1)');
 return randomValue<.20?'kick':'punch';
}

export function sampleMeleePresentation({type='none',progress=0,side=1,blocking=false,charge=0}={}){
 if(!['none','punch','heavy','kick'].includes(type))throw Error('Unknown melee presentation '+type);
 progress=clamp01(progress);charge=clamp01(charge);side=side<0?-1:1;
 const active=type!=='none'&&progress<1,heavy=active&&type==='heavy',kick=active&&type==='kick';
 const duration=HERO_ACTION_DURATIONS[type]||1,age=progress*duration,peak=heavy?.10:.09;
 // Artist14 v3 supersedes checkpoint-10 for melee presentation only.
 const pulse=active?(kick?Math.sin(Math.PI*progress):smooth(age,0,peak)*(1-smooth(age,peak,duration-.07))):0;
 const blend=active?smooth(age,0,kick?.14:.055)*(1-smooth(age,duration-.14,duration)):0;
 const wind=heavy?1-smooth(age,0,.08):0,guard=Math.max(blocking?1:0,blend,heavy?1-smooth(progress,.68,1):0,charge);
 return Object.freeze({type,progress,side,active,heavy,kick,pulse,blend,wind,guard,charge});
}

export function sampleReloadPresentation(progress=0){
 progress=clamp01(progress);
 const lower=smooth(progress,0,.15)*(1-smooth(progress,.84,1));
 const grab=smooth(progress,0,.18)*(1-smooth(progress,.79,.96));
 const pull=smooth(progress,.20,.40)*(1-smooth(progress,.60,.78));
 const bolt=smooth(progress,.79,.83)*(1-smooth(progress,.85,.89));
 return Object.freeze({progress,active:progress>0&&progress<1,lower,grab,pull,bolt});
}
