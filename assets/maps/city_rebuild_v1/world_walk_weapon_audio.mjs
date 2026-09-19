// Route admitted source-world shots to its original, cached weapon palette.
// Coordinates and attenuation are in source tiles, independent of render LOD.
export function createWorldWalkWeaponAudio({getListener,getVolume,isReady,play,unlock,events=globalThis.window,now=()=>performance.now(),maxDistance=8.5,npcBudget=12,windowMs=100}={}){
 const seen=new Map();let disposed=false,budgetAt=-Infinity,npcCount=0;
 const stats={played:0,player:0,npc:0,muted:0,locked:0,distant:0,duplicate:0,budget:0};
 function gesture(event){if(disposed||event?.isTrusted!==true)return;try{Promise.resolve(unlock?.()).catch(()=>{});}catch{}}
 events?.addEventListener?.('pointerdown',gesture,{capture:true,passive:true});events?.addEventListener?.('keydown',gesture,{capture:true});
 function shot(event){
  if(disposed||!event||event.accepted===false||typeof event.weapon!=='string'||['none','fists','unarmed','melee','knife','bat','grenade','molotov','c4'].includes(event.weapon))return false;
  const stamp=now(),id=event.id==null?null:String(event.id);
  if(id&&seen.has(id)){stats.duplicate++;return false;}
  // Consume muted/locked/distant receipts too: never replay old shots on unlock.
  if(id){seen.set(id,stamp);while(seen.size>256)seen.delete(seen.keys().next().value);}
  const volume=Math.max(0,Math.min(1,Number(getVolume?.())||0));if(!volume){stats.muted++;return false;}
  let gain=volume;
  if(!event.player){const listener=getListener?.();if(!listener||![event.r,event.c,listener.r,listener.c].every(Number.isFinite))return false;const distance=Math.hypot(event.r-listener.r,event.c-listener.c);if(distance>=maxDistance){stats.distant++;return false;}gain*=Math.max(0,1-distance/maxDistance);}
  if(isReady?.()!==true){stats.locked++;return false;}
  if(!event.player){if(stamp-budgetAt>=windowMs||stamp<budgetAt){budgetAt=stamp;npcCount=0;}if(npcCount>=npcBudget){stats.budget++;return false;}npcCount++;}
  try{if(play(event.weapon,gain)!==true)return false;}catch{return false;}
  stats.played++;stats[event.player?'player':'npc']++;return true;
 }
 return{shot,stats:()=>({...stats,remembered:seen.size}),dispose(){if(disposed)return;disposed=true;seen.clear();events?.removeEventListener?.('pointerdown',gesture,true);events?.removeEventListener?.('keydown',gesture,true);}};
}
