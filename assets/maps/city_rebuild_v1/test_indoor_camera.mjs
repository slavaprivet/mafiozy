import assert from 'node:assert/strict';
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
const root='C:/Users/Слава/Desktop/Мафиози/';
const base=pathToFileURL(root+'assets/maps/city_rebuild_v1/');
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,next){
 if(s==='three')return next(pathToFileURL(vendor+'build/three.module.js').href,c);
 if(c.parentURL?.includes('/.perf-camera/')&&['./building_entry_profiles.mjs','./building_room_profiles.mjs','./building_floor_surface.mjs'].includes(s))return next(new URL(s,base).href,c);
 return next(s,c);
}});
const T=await import(pathToFileURL(vendor+'build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const {createBuildingEntry,resolveBuildingCameraPosition:solve}=await import('./building_entry.mjs');
const before=solve;
const placements=JSON.parse(fs.readFileSync(new URL('buildings_placement.v1.json',base)));
const results=[];
for(const id of ['strip_club','old_town_narrow_townhouse_v1','eastside_garden_walkup_v1','eastside_stepped_apartment_v1','coastal_orchard_house_v1','garden_lane_house_v1','hillstep_chalet_v1','pine_ridge_cottage_v1','veranda_bungalow_v1','woodland_crosswing_house_v1']){
 const item=placements.instances.find(i=>i.assetId===id),buf=fs.readFileSync(root+item.binding.url.slice(1));
 const visual=(await new GLTFLoader().parseAsync(buf.buffer.slice(buf.byteOffset,buf.byteOffset+buf.byteLength),'')).scene;
 const group=new T.Group(),t=item.transform;visual.position.fromArray(t.modelLocalOffsetM);group.position.fromArray(t.positionM);group.rotation.y=t.yawDegrees*Math.PI/180;group.scale.setScalar(t.uniformScale);group.add(visual);group.updateMatrixWorld(true);
 const entry=createBuildingEntry({THREE:T,visual,instance:item});group.updateMatrixWorld(true);
 const point=entry.roomCenterPoint?.()||entry.roomPoint(),from=point.clone();from.y=entry.floorHeight(point.x,point.z)+1.1;
 const ceilingY=entry.ceilingHeight(point),rows=[];
 for(let angle=0;angle<Math.PI*2;angle+=Math.PI/4){
  const desired=from.clone().add(new T.Vector3(Math.sin(angle)*7,6,Math.cos(angle)*7));
  const args={THREE:T,from,desired,objects:[visual]},a=before(args),b=solve({...args,ceilingY});
  assert.deepEqual(solve(args).toArray(),a.toArray(),'ordinary/aim path unchanged');
  assert(b.y<=ceilingY-.28+.001,'below ceiling');
  // Resolving the final segment again must find no intervening walls.
  assert(solve({...args,desired:b}).distanceTo(b)<1e-6,'final segment unobstructed');
  assert(b.distanceTo(from)+.001>=a.distanceTo(from),'no stronger indoor zoom');
  rows.push({before:a.distanceTo(from),after:b.distanceTo(from)});
 }
 results.push({id,ceilingY,rows});entry.dispose();
}

console.log('PASS 80 real-room directions: no stronger zoom, clear final segment, below ceiling; unchanged default/aim path');
