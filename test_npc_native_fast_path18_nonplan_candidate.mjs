// Staged exact transform only; root owns the production edit window.
export function stageStableNonplanPass(source){
 const before="  const ok=plan?_civilianRouteTo(npc,door.r,door.c,'building_entry'):_planNpcRouteTo(npc,door.r,door.c,(r,c)=>npcWaypointOk(npc,r,c),.18,1200,'building_entry');";
 const after="  if(!plan&&npc._residentVisitPass?.pointPass!==npcWaypointOk)npc._residentVisitPass={pointPass:npcWaypointOk,pass:(r,c)=>npcWaypointOk(npc,r,c)};\n  const ok=plan?_civilianRouteTo(npc,door.r,door.c,'building_entry'):_planNpcRouteTo(npc,door.r,door.c,npc._residentVisitPass.pass,.18,1200,'building_entry');";
 if(!source.includes(before))throw Error('Expected single non-plan visit callsite changed; review fresh source');
 if(source.indexOf(before)!==source.lastIndexOf(before))throw Error('Ambiguous non-plan callsite');
 return source.replace(before,after);
}
