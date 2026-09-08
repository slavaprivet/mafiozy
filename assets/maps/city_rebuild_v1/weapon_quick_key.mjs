// Tap toggles the last equipped weapon; holding opens the picker only once.
export function createWeaponQuickKey({onTap,onHold,enabled=()=>true,now=()=>performance.now(),schedule=setTimeout,cancel=clearTimeout,holdMs=200}){
 let press=null;
 function reset(){if(press?.timer!==null&&press?.timer!==undefined)cancel(press.timer);press=null}
 function down(repeat=false){
  if(repeat||press||!enabled())return false;
  const state={started:now(),fired:false,timer:null};press=state;
  state.timer=schedule(()=>{if(press!==state||state.fired||!enabled())return;state.fired=true;onHold()},holdMs);return true;
 }
 function up(){
  if(!press)return false;const state=press;reset();if(!enabled()||state.fired)return true;
  if(now()-state.started>=holdMs)onHold();else onTap();return true;
 }
 return {down,up,cancel:reset,get pressed(){return !!press}};
}
