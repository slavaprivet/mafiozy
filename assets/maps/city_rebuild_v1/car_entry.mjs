export const HOLD_SECONDS=.3, EXIT_HOLD_SECONDS=.3, TRANSITION_SECONDS=2.6;
export function advanceEntryHold(elapsed,pressed,eligible,dt,duration=HOLD_SECONDS){
 if(!pressed||!eligible)return {elapsed:0,ready:false};
 const next=Math.min(duration,elapsed+Math.max(0,Math.min(.1,dt)));
 return {elapsed:next,ready:next>=duration-1e-8};
}
const smooth=t=>{t=Math.max(0,Math.min(1,t));return t*t*(3-2*t)};
export function entryPose(progress,exiting=false){
 const p=Math.max(0,Math.min(1,progress)),u=exiting?1-p:p;
 // Preserve the collision-predicted moving-exit sweep. Entry has its own staged
 // timing so reaching the handle precedes moving through the open doorway.
 if(exiting)return {seat:smooth((u-.25)/.5),fold:smooth((u-.12)/.36),cabinSlide:smooth((u-.66)/.2),door:smooth(p/.2)*(1-smooth((p-.8)/.2)),reach:Math.sin(Math.PI*p)*.8,phase:'exit',done:p>=1};
 const innerLeg=smooth((p-.30)/.25),outerLeg=smooth((p-.55)/.25),handReach=smooth(p/.12)*(1-smooth((p-.24)/.13)),closeReach=smooth((p-.81)/.08)*(1-smooth((p-.93)/.07));
 const phase=p<.12?'reach':p<.26?'open':p<.35?'duck':p<.49?'inner_leg':p<.61?'sit':p<.8?'outer_leg':p<1?'close':'seated';
 return {seat:smooth((p-.29)/.44),fold:(innerLeg+outerLeg)/2,cabinSlide:smooth((p-.72)/.13),door:smooth((p-.10)/.17)*(1-smooth((p-.87)/.13)),reach:Math.max(handReach,closeReach)*.8,
  phase,handReach,duck:smooth((p-.20)/.16)*(1-smooth((p-.71)/.14)),innerLeg,outerLeg,closeReach,done:p>=1};
}
