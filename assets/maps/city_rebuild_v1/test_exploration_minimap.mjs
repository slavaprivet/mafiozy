import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {mapProjection,waypointInfo,boundedWaypoint,mapKind,normalizeNativeInstances,selectMapPOIs,layoutMapLabels,pointInMapPolygon,currentMapRegion,waypointScreenPosition,waypointMarkerHit,waypointDistanceText,BUILDING_MAP_KINDS,vehicleMapColor,mapObjectAt} from './exploration_minimap.mjs';
import {explorationNpcMapMarkers,npcMapMarkerStyle,squadMapHover} from './exploration_minimap.mjs';
const minimapSource=await readFile(new URL('./exploration_minimap.mjs',import.meta.url),'utf8');
assert.match(minimapSource,/if\(!force&&now-lastDraw<80\)return;/,'fresh actor snapshots must not bypass the 80 ms non-interactive draw cap');
const near=(a,b)=>assert.ok(Math.abs(a-b)<1e-8,`${a} ≠ ${b}`);
{
 const projection=mapProjection({center:{x:170,z:172},width:500,height:400,metresPerPixel:1});
 const live={position:{x:170,z:172},available:true,hp:100};let defending=false;
 const actor={id:'npc_crew_merc_resident_43',source:{name:'Лука',mercenary:{profession:'medic',status:'active'}},object:{position:{x:0,z:0},visible:true}};
 const host={isMercenary:id=>id==='merc_resident_43',getMember:()=>live,isDefending:()=>defending};
 let markers=explorationNpcMapMarkers([actor],host);const pointer=projection.toScreen(live.position);
 assert.equal(squadMapHover(pointer,markers,projection,false),null,'Small map never adds squad labels');
 assert.equal(squadMapHover(pointer,markers,projection,true).text,'Лука\nВаш отряд\nМедик\nГотов');
 assert.equal(squadMapHover({x:pointer.x+11,y:pointer.y},markers,projection,true),null,'Hover requires the actual marker');
 defending=true;markers=explorationNpcMapMarkers([actor],host);assert.match(squadMapHover(pointer,markers,projection,true).text,/Защищает отряд/);
 live.downed=true;markers=explorationNpcMapMarkers([actor],host);assert.match(squadMapHover(pointer,markers,projection,true).text,/Нужна помощь/);
 live.available=false;markers=explorationNpcMapMarkers([actor],host);assert.equal(squadMapHover(pointer,markers,projection,true),null);
 assert.equal(squadMapHover(pointer,[{...markers[0],active:true,ownSquad:false}],projection,true),null,'Candidates and other gangs never get squad tooltip');
}
{
 const position={x:164,z:164},live={id:'merc_resident_43',position:{x:170,z:172},available:true,hp:100};let hired=true;
 const host={isMercenary:id=>hired&&id===live.id,getMember:id=>id===live.id?live:null};
 const actor=(id,source={},visible=true)=>({id,source,object:{position,visible}});
 for(const id of ['crew_merc_resident_43','npc_crew_merc_resident_43','npc:npc_crew_merc_resident_43']){
  const [marker]=explorationNpcMapMarkers([actor(id)],host);assert.equal(marker.ownSquad,true);assert.equal(marker.position,live.position);assert.deepEqual(npcMapMarkerStyle(marker),{color:'#32ed69',radius:5.4});
 }
 const ordinary=explorationNpcMapMarkers([actor('npc_resident_44',{mercenaryCandidate:true,mercenary:{profession:'medic'}}),actor('npc_crew_enemy',{gang:true}),actor('police',{police:true}),actor('boss',{empireBoss:true}),actor('hidden',{},false)],host);
 assert.equal(ordinary.length,4);assert(ordinary.every(m=>!m.ownSquad));assert.deepEqual(ordinary.map(m=>npcMapMarkerStyle(m).color),['#dfdab5','#dfdab5','#7ec0ee','#cf746c']);
 assert.equal(explorationNpcMapMarkers([actor('npc_crew_merc_resident_43',{},false)],host)[0].active,true,'Own roster stays locatable when render actor is culled');
 live.hp=0;assert.equal(explorationNpcMapMarkers([actor('npc_crew_merc_resident_43')],host)[0].active,true,'Downed member still belongs to squad');
 live.available=false;assert.equal(explorationNpcMapMarkers([actor('npc_crew_merc_resident_43')],host)[0].active,false,'Hospitalized member has no street marker');
 hired=false;assert.equal(explorationNpcMapMarkers([actor('npc_crew_merc_resident_43')],host)[0].ownSquad,false,'Dismissal immediately removes green style on next mapped snapshot');
 assert.equal(explorationNpcMapMarkers([actor('npc_crew_merc_resident_43')])[0].ownSquad,false,'Missing host never assumes ownership');
}
// Projection has no grid/world ambiguity, including expanded negative coordinates.
let checked=0;
for(const center of [{x:0,z:0},{x:610.9,z:32.8},{x:-183,z:-304}])for(const metresPerPixel of [.13,.8,2,12])for(const [width,height] of [[230,194],[1000,620]]){
  const pr=mapProjection({center,width,height,metresPerPixel});
  for(const p of [{x:-240,z:-420},{x:978,z:900},{x:0,z:0},center]){const q=pr.toWorld(pr.toScreen(p));near(q.x,p.x);near(q.z,p.z);checked++}
  const north=pr.toScreen({x:center.x,z:center.z-10}),east=pr.toScreen({x:center.x+10,z:center.z});assert.ok(north.y<height/2);assert.ok(east.x>width/2);
}
assert.throws(()=>mapProjection({center:{x:0,z:0},width:0,height:1,metresPerPixel:1}));
const bounds={minX:-240,maxX:978,minZ:-420,maxZ:900};
assert.deepEqual(boundedWaypoint({x:-500,z:1000},bounds),{x:-240,z:900});assert.equal(boundedWaypoint({x:NaN,z:0},bounds),null);assert.equal(boundedWaypoint(null,bounds),null);
near(waypointInfo({x:0,z:0},{x:3,z:4}).distance,5);assert.equal(waypointInfo({x:0,z:0},{x:3,z:4}).arrived,false);assert.equal(waypointInfo({x:1,z:1},{x:1,z:1}).arrived,true);
for(const yaw of [0,.5,Math.PI/2,-Math.PI/2,Math.PI,Math.PI*5]){const info=waypointInfo({x:10,z:20},{x:10+Math.sin(yaw)*100,z:20+Math.cos(yaw)*100},yaw);near(info.distance,100);near(info.relativeBearing,0)}
assert.equal(waypointInfo(null,{x:0,z:0}),null);
const b=JSON.parse(await readFile(new URL('./buildings_placement.v1.json',import.meta.url))),d=JSON.parse(await readFile(new URL('./decor_placement.v1.json',import.meta.url)));
const all=[...b.instances,...d.instances],normalized=normalizeNativeInstances(all);
assert.equal(normalized.length,all.length);assert.equal(new Set(normalized.map(x=>x.id)).size,normalized.length);
for(let i=0;i<all.length;i++){const source=all[i],out=normalized[i];near(out.x,source.transform.positionM[0]);near(out.z,source.transform.positionM[2]);if(source.footprint){assert.equal(out.building,true);near(out.polygon[0][0],source.footprint.minC*4.1);near(out.polygon[0][1],source.footprint.minR*4.1)}assert.ok(out.polygon.flat().every(Number.isFinite))}
assert.deepEqual(normalizeNativeInstances([{userData:{instance:all[0]}}]),[normalized[0]]);
assert.equal(mapKind('bank_canon_v2'),'bank');assert.equal(mapKind('pine_cluster'),'tree');assert.equal(mapKind('Обзорная беседка'),'landmark');assert.equal(mapKind('bench_civic'),'bench');
const fallback=normalizeNativeInstances([{id:'rc',c:2,r:3,assetId:'bench_civic'}]);near(fallback[0].x,8.2);near(fallback[0].z,12.3);
console.log(`PASS exploration minimap: ${checked} projection round trips, world bounds / bearings / arrival, ${normalized.length} actual placed objects with native 4.1 scale, group/raw adapter parity.`);
const fixtures=[
  {id:'bank1',kind:'bank',name:'Банк',x:210,z:210},
  {id:'bank2',kind:'bank',name:'Банк',x:280,z:320},
  {id:'hall',kind:'landmark',name:'Общественный зал',x:300,z:280},
  {id:'hill',kind:'mountain',name:'Северный хребет',x:280,z:210},
  {id:'lake',kind:'water',name:'Кедровое озеро',x:420,z:200},
  {id:'forest',kind:'forest',name:'Кедровый бор',x:430,z:260},
  {id:'station',kind:'station',name:'Северная станция',x:235,z:215},
  {id:'station',kind:'station',name:'Северная станция',x:235,z:215},
];
const selected=selectMapPOIs(fixtures);assert.equal(selected[0].id,'station');assert.equal(selected.length,7);assert.equal(selected.filter(p=>p.name==='Банк').length,2,'same name does not erase distinct physical banks');assert.ok(selected.findIndex(p=>p.id==='hill')<selected.findIndex(p=>p.id==='bank1'));
const pr=mapProjection({center:{x:300,z:250},width:600,height:400,metresPerPixel:1.5});
const labels=layoutMapLabels({pois:selected,projection:pr,width:600,height:400,metresPerPixel:1.5});
assert.equal(labels[0].obj.id,'station');assert.equal(labels.some(l=>l.obj.kind==='bank'),false,'overview labels prioritize stations and scenery; bank icons remain');
for(const [i,a]of labels.entries()){assert.ok(a.box.x>=5&&a.box.x+a.box.w<=595);for(const b of labels.slice(i+1))assert.ok(!(a.box.x<b.box.x+b.box.w&&a.box.x+a.box.w>b.box.x&&a.box.y<b.box.y+b.box.h&&a.box.y+a.box.h>b.box.y),'measured label bounds never overlap')}
assert.equal(mapKind('railway_station'),'station');assert.equal(mapKind('Поезд'),'train');
console.log(`PASS railway minimap: stations prioritized, distinct repeated-name POIs retained, duplicate ids removed, ${labels.length} measured nonoverlapping overview labels.`);
const districts=[{id:'city',name:'Старый город',polygon:[[0,0],[20,0],[20,20],[0,20]]}],regions=[{id:'woods',name:'Сосновый лес',polygon:[[-20,-20],[30,-20],[30,30],[-20,30]]}];
assert.equal(currentMapRegion({x:10,z:10},{districts,regions}).id,'city','native district takes priority over large forest overlap');assert.equal(currentMapRegion({x:-10,z:-10},{districts,regions}).id,'woods');assert.equal(currentMapRegion({x:90,z:0},{districts,regions}),null);
assert.equal(pointInMapPolygon({x:0,z:10},districts[0].polygon),true,'district boundary is included');assert.equal(pointInMapPolygon({x:2,z:2},[[0,0],[5,0],[5,1],[1,1],[1,5],[0,5]]),false,'concave region is exact polygon, not AABB');assert.equal(pointInMapPolygon({x:0,z:0},[[0,0]]),false);
const mini=mapProjection({center:{x:0,z:0},width:230,height:194,metresPerPixel:1});
for(const target of[{x:0,z:0},{x:500,z:-500}]){const marker=waypointScreenPosition(target,mini,230,194);assert.ok(waypointMarkerHit({x:marker.x+11,y:marker.y},target,mini,230,194));assert.equal(waypointMarkerHit({x:marker.x+13,y:marker.y},target,mini,230,194),false,'right click elsewhere preserves marker')}
assert.equal(waypointMarkerHit({x:50,y:50},null,mini,230,194),false);
assert.equal(waypointDistanceText({x:0,z:0},{x:3,z:4}),'До метки: 5 м');assert.equal(waypointDistanceText({x:0,z:0},{x:0,z:0}),'До метки: 0 м');
for(const source of b.instances){assert.ok(BUILDING_MAP_KINDS.includes(mapKind(source.assetId)),source.assetId+' requires semantic building icon')}
assert.equal(mapKind('pine_ridge_cottage_v1'),'residential','pine in a house name does not classify it as a tree');assert.equal(mapKind('gun_shop'),'gunshop');assert.equal(mapKind('hospital'),'hospital');assert.equal(mapKind('bookmaker'),'bookmaker');
assert.equal(vehicleMapColor({color:'#8c293e'}),'#8c293e');assert.equal(vehicleMapColor({skinColor:'#ff0000'}),'#ff0000');assert.equal(vehicleMapColor({color:0x005522}),'#005522');assert.equal(vehicleMapColor({color:'invalid'}),'#f2c48a');
const hoverObj={id:'shop',name:'Магазин',x:20,z:20,polygon:[[10,10],[40,10],[40,40],[10,40]]};assert.equal(mapObjectAt(mini.toScreen({x:20,z:20}),[hoverObj],mini).id,'shop');assert.equal(mapObjectAt(mini.toScreen({x:37,z:37}),[hoverObj],mini).id,'shop','hover also recognizes actual footprint');assert.equal(mapObjectAt(mini.toScreen({x:50,z:50}),[hoverObj],mini),null);
console.log('PASS minimap district polygons, edge-marker right-click radius, metre-only distance, all native building semantic icons, actual car paint and footprint hover.');
