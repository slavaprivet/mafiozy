// Pure staging transform; production integration belongs to root.
export function stageNpcRoadEgress(source){
 if(source.includes('const roadExit=_npcPlanRoadExit(npc,now);'))return source;
 const replace=(before,after)=>{if(!source.includes(before))throw Error('Road egress stage source changed: '+before.slice(0,90));source=source.replace(before,after);};
 replace('<script src="assets/maps/city_rebuild_v1/npc_native_directed_route_source.js"></script>','<script src="assets/maps/city_rebuild_v1/npc_native_directed_route_source.js"></script>\n<script src="assets/maps/city_rebuild_v1/npc_road_egress_source.js"></script>');
 replace("if(native&&kind==='building_entry'&&typeof _npcPlanNativeVisitRoute==='function')", "if(native&&(kind==='building_entry'||kind==='civilian_road_exit')&&typeof _npcPlanNativeVisitRoute==='function')");
 replace('function _civilianArrivalRadius(n){','function _civilianArrivalRadius(n){\n  if(n._routeKind===\'civilian_road_exit\')return .001;');
 replace('  const searchKey=[sr,sc,maxDepth,!!npc._allowBeach',"  const roadExit=_npcPlanRoadExit(npc,now);if(roadExit!==null)return roadExit;\n  const searchKey=[sr,sc,maxDepth,!!npc._allowBeach");
 replace("n._residentDoor?.native&&n._routeKind==='building_entry'?npcPassableForSnitch:npcPassable", "(n._routeKind==='civilian_road_exit'||n._residentDoor?.native&&n._routeKind==='building_entry')?npcPassableForSnitch:npcPassable");
 return source;
}
