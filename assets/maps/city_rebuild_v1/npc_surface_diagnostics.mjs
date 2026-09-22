// QA-only caller; no snapshot serialization, vertex sampling or actor mutation.
export function summarizeNpcSurfaces(records){
 const result={cached:0,visible:0,alive:0,dead:0,inWater:0,wet:0,drying:0,bleeding:0,activeBleedingWounds:0,particles:0,reactions:{},lastPoseAt:null};
 for(const record of records){
  const state=record.actor.surface.performanceState();result.cached++;
  if(record.actor.object.visible)result.visible++;
  if(state.reaction==='dead')result.dead++;else result.alive++;
  result.reactions[state.reaction]=(result.reactions[state.reaction]||0)+1;
  if(state.inWater)result.inWater++;
  if(state.wetMeshes>0){result.wet++;if(!state.inWater)result.drying++;}
  if(state.activeBleedingWounds>0)result.bleeding++;
  result.activeBleedingWounds+=state.activeBleedingWounds;result.particles+=state.particles;
  if(Number.isFinite(record.lastPoseAt))result.lastPoseAt=Math.max(result.lastPoseAt??-Infinity,record.lastPoseAt);
 }
 return result;
}
