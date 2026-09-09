// Renderer input projection. Source bridge alone chooses/admit attacks and times charge.
export function createWorldWalkMeleeInput({bridge,now=()=>performance.now()/1000}={}){
 if(!bridge?.beginWalkMelee||!bridge?.setWalkMeleeCharge||!bridge?.setWalkMeleeBlock)throw Error('World melee bridge required');
 let clock=0,held=false,pressedAt=null,spent=false,blocking=false,current=null,sequence=0,side=1,reservedHeavy=false;
 const context={allowed:true,armed:false,airborne:false,yaw:0,airHeight:0};
 const timeOf=value=>{const t=Number.isFinite(value)?value:now();if(!Number.isFinite(t))throw Error('Finite input time required');clock=Math.max(clock,t);return clock};
 const update=options=>{for(const key of Object.keys(context))if(options[key]!==undefined)context[key]=options[key];if(options.blocked===true)context.allowed=false};
 const permitted=()=>context.allowed!==false&&!context.armed;
 const clearHold=()=>{if(!reservedHeavy&&(held||pressedAt!==null))bridge.setWalkMeleeCharge(false);held=false;pressedAt=null;spent=false};
 const clearAll=()=>{if(reservedHeavy)bridge.setWalkMeleeCharge(false);reservedHeavy=false;clearHold();bridge.setWalkMeleeBlock(false);blocking=false;current=null};
 const expire=time=>{if(current&&time-current.time>=current.duration){if(reservedHeavy)bridge.setWalkMeleeCharge(false);reservedHeavy=false;current=null}};
 function begin(time,heavy=false){
  const yaw=Number.isFinite(context.yaw)?context.yaw:0;
  const result=bridge.beginWalkMelee({angle:Math.PI/2-yaw,airborne:!!context.airborne,heavy});
  if(!result?.accepted||!Number.isFinite(result.duration)||result.duration<=0)return false;
  reservedHeavy=heavy;
  side=result.side<0?-1:1;sequence=result.seq;
  current={id:result.seq,seq:result.seq,type:result.type,time,sourceStartAt:result.startAt,duration:result.duration,side,yaw,airHeight:Math.max(0,Number(context.airHeight)||0),contactWindow:[...(result.contactWindow||[])]};
  return true;
 }
 function snapshot(time,started=false){
  const active=current&&time-current.time<current.duration,charge=held&&!spent&&!blocking&&pressedAt!==null?Math.max(0,Math.min(1,(time-pressedAt)/1.2)):0;
  return {action:{type:active?current.type:'none',progress:active?Math.max(0,Math.min(1,(time-current.time)/current.duration)):0,side,blocking,charge},start:active?{...current,contactWindow:[...current.contactWindow]}:null,started,held,sequence};
 }
 function press(options={}){
  const time=timeOf(options.time);update(options);expire(time);
  if(!permitted()){clearAll();return snapshot(time)}
  if(held||blocking)return snapshot(time);
  if(context.airborne)return snapshot(time,!current&&begin(time));
  held=true;pressedAt=time;spent=false;
  bridge.setWalkMeleeCharge(true);
  return snapshot(time,!current&&begin(time));
 }
 function release(options={}){
  const time=timeOf(options.time);update(options);expire(time);
  if(!permitted()){clearAll();return snapshot(time)}
  // Submit earned heavy before releasing the source timer; never pass elapsed time.
  const earned=held&&!spent&&!blocking&&!context.airborne&&!options.cancelled&&pressedAt!==null&&time-pressedAt>=1.2;
  const started=earned&&!current?begin(time,true):false;clearHold();
  return snapshot(time,started);
 }
 function step(options={}){
  const time=timeOf(options.time);update(options);expire(time);
  if(!permitted()){clearAll();return snapshot(time)}
  if(Number.isInteger(options.buttons)&&!(options.buttons&1))clearHold();
  if(context.airborne){clearHold();return snapshot(time)}
  let started=false;
  if(held&&!spent&&!blocking&&!current&&pressedAt!==null&&time-pressedAt>=1.2){spent=true;started=begin(time,true);if(!started)bridge.setWalkMeleeCharge(false);}
  return snapshot(time,started);
 }
 function cancel(){clearAll();return snapshot(clock)}
 function block(value){blocking=!!value&&permitted()&&bridge.setWalkMeleeBlock(true)===true;if(!value)bridge.setWalkMeleeBlock(false);if(blocking){if(reservedHeavy)bridge.setWalkMeleeCharge(false);reservedHeavy=false;clearHold();current=null}return snapshot(clock)}
 return {press,release,step,cancel,block};
}
