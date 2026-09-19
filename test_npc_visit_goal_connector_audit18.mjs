import {createCivilianNativeFixture} from './assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs';
const f=await createCivilianNativeFixture({assetId:'old_town_narrow_townhouse_v1'}),b=f.box,door=b._residentBuildingDoors()[0];
const set=b._setNpcRoute;b._setNpcRoute=(n,path,kind)=>{n.auditPath=path;return set(n,path,kind);};
const rows=[];
for(let angle=0;angle<16;angle++){
 const a=angle*Math.PI/8,r=door.r+Math.sin(a)*3,c=door.c+Math.cos(a)*3;
 if(!b._npcBodyPassable(r,c,b.npcPassableForSnitch))continue;
 const n={id:'audit_'+angle,r,c,_civilianPlan:{phase:'walk_to_shop'}};let ok=false,frames=0;
 do{f.nextFrame();frames++;ok=b._civilianRouteTo(n,door.r,door.c,'building_entry');}while(n._routeSearchPending&&frames<150);
 const tail=n.auditPath?.at(-1);
 rows.push({angle,ok,pending:!!n._routeSearchPending,frames,expanded:n._routeSearchExpanded,tailDistance:tail?Math.hypot(tail.r-door.r,tail.c-door.c):null,tailConnectorClear:tail?b._npcPathPassable(tail.r,tail.c,door.r,door.c,b.npcPassableForSnitch):null});
}
console.log(JSON.stringify({rows,scope:'read-only actual townhouse source route and exact final entrance connection'},null,2));
