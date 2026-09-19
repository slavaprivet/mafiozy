// Presentation receipt only. This never admits a shot, spends ammo, or deals damage.
export function createNpcVisualShotLatch({maxAgeMs=750,duration=.22}={}){
 let initialized=false,lastSequence=0,lastStamp=0,lastSourceNow=-Infinity,active=null;
 function reset(){initialized=false;lastSequence=0;lastStamp=0;lastSourceNow=-Infinity;active=null;}
 function observe(row,sourceNowMs,time){
  const shot=row?._visualShot,seq=Number(shot?.sequence)||0,stamp=Number(shot?.at)||0;
  if(!Number.isFinite(sourceNowMs)||!Number.isFinite(time))return null;
  const baseline=!initialized||sourceNowMs<lastSourceNow||seq<lastSequence;
  const fresh=!baseline&&seq>lastSequence&&stamp>lastStamp;
  initialized=true;lastSequence=seq;lastStamp=stamp;lastSourceNow=sourceNowMs;
  if(baseline){active=null;return null;}
  if(!fresh||stamp<=0||sourceNowMs<stamp||sourceNowMs-stamp>maxAgeMs||row.dead||row.downed||row.hp===0||shot.shooterId!==row.id||!Number.isFinite(shot.target?.r)||!Number.isFinite(shot.target?.c))return null;
  active={...shot,target:{...shot.target},presentedAt:time};return active;
 }
 function sample(time){const age=active?time-active.presentedAt:Infinity;return age>=0&&age<duration?{shot:active,recoil:1-age/duration}:null;}
 return {observe,sample,reset};
}
