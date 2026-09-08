// Local preview admission only. No DOM, collision, damage, inventory or server authority.
import {ARTIST14_MELEE_DURATIONS,selectArtist14OrdinaryAttack} from './hero_artist14_melee.mjs';
export function createArtist14Input({now=()=>Date.now()/1000,random=Math.random}={}){
 let clock=-Infinity,held=false,pressedAt=null,spent=false,blocking=false,current=null,sequence=0,side=1,pendingHeavy=false;
 let context={allowed:true,armed:false,airborne:false,yaw:0,airHeight:0};
 const timeOf=value=>{const valueNow=Number.isFinite(value)?value:now();if(!Number.isFinite(valueNow))throw Error('Expected finite seconds');clock=Math.max(clock,valueNow);return clock};
 const clearHold=()=>{held=false;pressedAt=null;spent=false;pendingHeavy=false};
 const clearAll=()=>{clearHold();current=null;blocking=false};
 const updateContext=options=>{for(const k of ['allowed','armed','airborne','yaw','airHeight'])if(options[k]!==undefined)context[k]=options[k];if(options.blocked===true)context.allowed=false};
 const permitted=()=>context.allowed!==false&&!context.armed;
 const expire=time=>{if(current&&time-current.time>=ARTIST14_MELEE_DURATIONS[current.type])current=null};
 function begin(type,time){side*=-1;current={id:++sequence,type,time,side,yaw:Number.isFinite(context.yaw)?context.yaw:0,airHeight:Math.max(0,Number.isFinite(context.airHeight)?context.airHeight:0)};return true;}
 function snapshot(time,started=false){
  const active=current&&time-current.time<ARTIST14_MELEE_DURATIONS[current.type];
  const charge=held&&!spent&&!blocking&&pressedAt!==null?Math.max(0,Math.min(1,(time-pressedAt)/1.2)):0;
  return {action:active?{type:current.type,progress:Math.max(0,Math.min(1,(time-current.time)/ARTIST14_MELEE_DURATIONS[current.type])),side:current.side,blocking,charge}:{type:'none',progress:0,side,blocking,charge},start:active?{...current}:null,started,held,sequence};
 }
 function press(options={}){
  const time=timeOf(options.time);updateContext(options);expire(time);
  if(!permitted()){clearAll();return snapshot(time)}
  if(blocking||held)return snapshot(time);
  // Each real press owns a new hold timer. Repeated down events cannot re-arm it.
  clearHold();
  if(context.airborne){if(!current)return snapshot(time,begin('dropkick',time));return snapshot(time)}
  held=true;pressedAt=time;
  return snapshot(time,!current?begin(selectArtist14OrdinaryAttack(random()),time):false);
 }
 function release(options={}){
  const time=timeOf(options.time);updateContext(options);expire(time);
  if(!permitted()){clearAll();return snapshot(time)}
  const earned=held&&pressedAt!==null&&!spent&&!blocking&&!context.airborne&&!options.cancelled&&time-pressedAt>=1.2-1e-9;
  clearHold();pendingHeavy=earned;
  let started=false;if(pendingHeavy&&!current){pendingHeavy=false;started=begin('heavy',time)}
  return snapshot(time,started);
 }
 function step(options={}){
  const time=timeOf(options.time);updateContext(options);expire(time);
  if(!permitted()){clearAll();return snapshot(time)}
  // Browser bridge supplies e.buttons where available: a missing up event cannot charge.
  if(Number.isInteger(options.buttons)&&!(options.buttons&1))clearHold();
  if(context.airborne){clearHold();return snapshot(time)}
  let started=false;
  if(!blocking&&!current&&(pendingHeavy||(held&&!spent&&pressedAt!==null&&time-pressedAt>=1.2-1e-9))){pendingHeavy=false;spent=true;started=begin('heavy',time)}
  return snapshot(time,started);
 }
 function cancel(){clearAll();return snapshot(Number.isFinite(clock)?clock:0)}
 function block(value){blocking=!!value&&permitted();if(blocking){clearHold();current=null}return snapshot(Number.isFinite(clock)?clock:0)}
 return {press,release,step,cancel,block};
}

