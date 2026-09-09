// Presentation classification only: never infer a fatal event from HP or a
// removed/alive=false transport actor. The source owns damage and respawns.
export function normalizeNpcLifecycle(src={}, {time=0,sourceNowMs}={}){
 const now=Number.isFinite(sourceNowMs)?sourceNowMs:(Number.isFinite(time)?time*1000:0),state=String(src.lifeState||'').toLowerCase();
 const nonfatal=src.meleeStunned===true||src.downed===true||state==='downed';
 const confirmed=src.deathConfirmed===true||src.fatal===true||state==='dead'||state==='corpse';
 const dead=confirmed||(src.deathConfirmed!==false&&src.dead===true&&!nonfatal),at=Number(src.deadAt);
 return {dead,explicitAlive:!dead&&!nonfatal&&src.dead===false,key:dead?(Number.isFinite(at)&&at>0?String(at):'dead'):null,age:dead&&Number.isFinite(at)&&at>0?Math.max(0,(now-at)/1000):undefined,side:src.deathSide===-1?-1:1};
}
