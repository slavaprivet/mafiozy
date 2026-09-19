export function stageNpcBenchApproach(source){
 return source
 .replace("const native=typeof _walkNpcNavigationResolver==='function'&&kind==='building_entry';\n  const pointPass=native?npcPassableForSnitch:(rr,cc)=>npcWaypointOk(n,rr,cc);", "const native=typeof _walkNpcNavigationResolver==='function'&&['building_entry','civilian_bench'].includes(kind);\n  if(kind==='civilian_bench'&&!n._civilianBenchPointPass)n._civilianBenchPointPass=(rr,cc)=>npcWaypointOk(n,rr,cc);\n  const pointPass=kind==='civilian_bench'?n._civilianBenchPointPass:native?npcPassableForSnitch:(rr,cc)=>npcWaypointOk(n,rr,cc);")
 .replace("(kind==='building_entry'||kind==='civilian_road_exit')", "(kind==='building_entry'||kind==='civilian_road_exit'||kind==='civilian_bench')")
 .replaceAll('(.6/4.1)','(1.8/4.1)');
}
