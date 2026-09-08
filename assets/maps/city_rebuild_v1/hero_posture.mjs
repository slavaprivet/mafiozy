// Presentation-only posture controller. The host keeps authority over movement,
// collision admission, stamina and combat. Values are expressed in metres and
// seconds so the 5.16-unit Artist13 demo never leaks into the 1.9 m runtime.
export const HERO_POSTURES=Object.freeze({
 stand:Object.freeze({value:0,height:1.90,eyeHeight:1.64,walkSpeed:3.20,runSpeed:5.80}),
 crouch:Object.freeze({value:1,height:1.25,eyeHeight:1.02,walkSpeed:1.55,runSpeed:1.55}),
 prone:Object.freeze({value:2,height:.62,eyeHeight:.43,walkSpeed:.80,runSpeed:.80})
});

const clamp=(value,min,max)=>Math.max(min,Math.min(max,value));
const smooth=value=>{value=clamp(value,0,1);return value*value*(3-2*value)};
const valid=name=>Object.prototype.hasOwnProperty.call(HERO_POSTURES,name);

export function createHeroPosture(initial='stand'){
 if(!valid(initial))throw Error('Unknown hero posture '+initial);
 const value=HERO_POSTURES[initial].value;
 return {target:initial,value,crouch:smooth(value)*(1-smooth(value-1)),prone:smooth(value-1),blocked:false};
}

export function posturePresentation(state,{running=false}={}){
 if(!state||!Number.isFinite(state.value))throw Error('Hero posture state required');
 const value=clamp(state.value,0,2),crouch=smooth(value)*(1-smooth(value-1)),prone=smooth(value-1);
 const stand=HERO_POSTURES.stand,crouchSpec=HERO_POSTURES.crouch,proneSpec=HERO_POSTURES.prone;
 const standingSpeed=running?stand.runSpeed:stand.walkSpeed;
 const speed=(standingSpeed+(crouchSpec.walkSpeed-standingSpeed)*crouch)*(1-prone)+proneSpec.walkSpeed*prone;
 const height=(stand.height+(crouchSpec.height-stand.height)*crouch)*(1-prone)+proneSpec.height*prone;
 const eyeHeight=(stand.eyeHeight+(crouchSpec.eyeHeight-stand.eyeHeight)*crouch)*(1-prone)+proneSpec.eyeHeight*prone;
 return Object.freeze({target:state.target,value,crouch,prone,height,eyeHeight,maxSpeed:speed,speedMultiplier:speed/standingSpeed,crawl:prone>.5,blocked:!!state.blocked});
}

// canOccupyHeight(height, target) is supplied by the host's real collision
// query. A missing callback means presentation may transition freely.
export function requestHeroPosture(state,target,{canOccupyHeight}={}){
 if(!state||!Number.isFinite(state.value))throw Error('Hero posture state required');
 if(!valid(target))throw Error('Unknown hero posture '+target);
 const current=posturePresentation(state),requested=HERO_POSTURES[target];
 if(requested.height>current.height&&typeof canOccupyHeight==='function'&&!canOccupyHeight(requested.height,target)){
  state.blocked=true;return false;
 }
 state.target=target;state.blocked=false;return true;
}

export function stepHeroPosture(state,dt,{canOccupyHeight}={}){
 if(!state||!valid(state.target)||!Number.isFinite(state.value))throw Error('Hero posture state required');
 if(!Number.isFinite(dt)||dt<0)throw Error('Posture dt must be finite and non-negative');
 const targetValue=HERO_POSTURES[state.target].value,step=dt*2.1;
 let next=state.value+clamp(targetValue-state.value,-step,step),blocked=false;
 if(next<state.value&&typeof canOccupyHeight==='function'){
  const probe={...state,value:next},height=posturePresentation(probe).height;
  if(!canOccupyHeight(height,state.target)){next=state.value;blocked=true;}
 }
 state.value=clamp(next,0,2);state.prone=smooth(state.value-1);state.crouch=smooth(state.value)*(1-state.prone);state.blocked=blocked;
 return posturePresentation(state);
}

export function resetHeroPosture(state,target='stand'){
 if(!state||!valid(target))throw Error('Hero posture state/target required');
 state.target=target;state.value=HERO_POSTURES[target].value;state.blocked=false;
 const view=posturePresentation(state);state.crouch=view.crouch;state.prone=view.prone;return view;
}
