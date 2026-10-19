import assert from 'node:assert/strict';
import fs from 'node:fs';
import {gunzipSync} from 'node:zlib';
import {createCivilianNativeFixture} from './test_civilian_native_fixture.mjs';
import {createPrintShopServiceStation} from './native_print_shop_service_station.mjs';
import {createServiceSpawnVisibility23} from './service_pilot23_candidate/visibility.mjs';
const snapshot=JSON.parse(gunzipSync(fs.readFileSync(new URL('test_fixtures/native_static_collision19.json.gz',import.meta.url))));
const f=await createCivilianNativeFixture({assetId:'print_shop',snapshot}),T=f.THREE,station=createPrintShopServiceStation({THREE:T,entry:f.entry,siteRevision:'visibility23',validateLayout:()=>true}),layout=station.layout;
const camera=new T.PerspectiveCamera(55,1.6,.05,1500),room=layout.spawn;
const visibility=createServiceSpawnVisibility23({THREE:T,getCamera:()=>camera,getOccluders:()=>[f.entry.visual],isCurrentSite:l=>l===layout,ready:()=>true});
let now=1000;const results=[];
function look(position,target=room){camera.position.set(position.x,position.y,position.z);camera.lookAt(target.x,target.y+.8,target.z);camera.updateMatrixWorld(true);now+=300;const hidden=visibility(layout,now);results.push({position,hidden});return hidden;}
assert.equal(look({x:room.x,y:room.y+1,z:room.z}),false,'camera inside spawn body cannot certify hidden');
assert.equal(look({x:room.x,y:room.y+1.6,z:room.z+2}),false,'inside storeroom looking at birth denies');
assert.equal(look({x:room.x,y:room.y+1.6,z:room.z+2},{x:room.x,y:room.y,z:room.z+20}),true,'whole birth volume outside current frustum');
for(const position of [layout.work,{x:room.x+15,y:room.y+2,z:room.z},{x:room.x,y:room.y+15,z:room.z}])look(position);
// Isolated opaque planar rectangle: exact convex coverage, not nine unrelated rays.
const wall=new T.Mesh(new T.PlaneGeometry(20,20),new T.MeshStandardMaterial({side:T.DoubleSide}));wall.position.set(room.x,room.y+1,room.z+2);f.scene.add(wall);camera.position.set(room.x,room.y+1,room.z+5);camera.lookAt(room.x,room.y+1,room.z);camera.updateMatrixWorld(true);
const proof=createServiceSpawnVisibility23({THREE:T,getCamera:()=>camera,getOccluders:()=>[wall],isCurrentSite:()=>true,ready:()=>true});
assert.equal(proof(layout,now+=300),true,'opaque convex triangle pair covers complete spawn box');
wall.visible=false;assert.equal(proof(layout,now+=300),false,'hidden/cutaway wall does not occlude');wall.visible=true;
wall.material.transparent=true;wall.material.opacity=.5;assert.equal(proof(layout,now+=300),false,'transparent glass is not proof');wall.material.transparent=false;wall.material.opacity=1;
wall.scale.set(.03,1,1);assert.equal(proof(layout,now+=300),false,'centre ray hit alone does not hide body corners');
wall.removeFromParent();wall.geometry.dispose();wall.material.dispose();station.dispose();f.entry.dispose();
console.log(JSON.stringify({pass:true,actualBuildingCameraObservations:results,limits:'CPU actual camera projection/opaque triangle geometry. No rendered-frame or whole-scene FPS acceptance.'},null,2));
