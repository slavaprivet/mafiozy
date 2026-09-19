import {createCivilianNativeFixture} from './assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs';
const assets=['hospital','print_shop','pawnshop','gun_shop','old_town_narrow_townhouse_v1','eastside_garden_walkup_v1'];
const report=[];
for(const assetId of assets){
 const f=await createCivilianNativeFixture({assetId}),b=f.box;
 for(const door of b._residentBuildingDoors()){
  f.nextFrame();let candidates=0,bodyClear=0,connected=0;
  for(let r=Math.floor(door.r-.9);r<=Math.floor(door.r+.9);r++)for(let c=Math.floor(door.c-.9);c<=Math.floor(door.c+.9);c++){
   const rr=r+.5,cc=c+.5;if(Math.hypot(rr-door.r,cc-door.c)>.9)continue;candidates++;
   if(!b._npcBodyPassable(rr,cc,b.npcPassableForSnitch))continue;bodyClear++;
   if(b._npcPathPassable(rr,cc,door.r,door.c,b.npcPassableForSnitch))connected++;
  }
  report.push({assetId,id:door.id,doorClear:b._npcBodyPassable(door.r,door.c,b.npcPassableForSnitch),candidates,bodyClear,connected});
 }
}
console.log(JSON.stringify({report,scope:'read-only actual GLB entrance and exact footprint connection to source cardinal grid; no renderer'},null,2));
