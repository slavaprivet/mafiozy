// Interrupt presentation using host lifecycle receipts. Never infer death from HP,
// emit combat events, reset artist poses, or hide DOM without its owning close API.
export function createWalkLifeInterrupt({closeDialogs=()=>{},cancelScriptedActions=()=>{},releaseInput=()=>{},onError=()=>{}}={}){
 let dead=false,epoch=0,episodes=0,disposed=false;
 function apply(state){
  const s=state?.snapshot||state;if(disposed||!s||s.available===false)return false;
  const next=s.dead===true||s.deathConfirmed===true;
  if(!next){dead=false;return false;}
  if(dead)return false;dead=true;epoch++;episodes++;
  // Clear scripted locks before the caller delivers the real death receipt to
  // Artist14. A broken dialog must not prevent the other owners from cancelling.
  const reason={reason:'death',epoch};
  for(const callback of [cancelScriptedActions,closeDialogs,releaseInput])try{callback(reason);}catch(error){try{onError(error);}catch{}}
  return true;
 }
 function guard(callback){const token=epoch,blocked=dead;return function(...args){if(disposed||blocked||dead||token!==epoch)return;return callback.apply(this,args);};}
 return {apply,guard,stats:()=>({dead,epoch,episodes,disposed}),dispose(){if(disposed)return;disposed=true;epoch++;}};
}
