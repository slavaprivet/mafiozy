import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {pathToFileURL} from 'node:url';
import {sourceVehicleCoverBodies} from './hero_source_vehicle_cover.mjs';
import {sourceVehicleEscapeId} from './hero_source_vehicle_escape.mjs';
import {trafficActorBlocks} from './world_traffic_presentation.mjs';
import {findCover} from './hero_cover.mjs';
import {circleFits,movePedestrian} from './walk_motion.mjs';
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const T=await import(pathToFileURL(vendor+'/build/three.module.js'));
const scene=new T.Scene(),object=new T.Group();scene.add(object);
object.add(new T.Mesh(new T.BoxGeometry(2,1.1,4),new T.MeshBasicMaterial()));object.children[0].position.y=.55;
const actor={object,profile:{halfWidth:1,halfLength:2,height:1.1,bounds:{min:[-1,0,-2],max:[1,1.1,2]}}};
const records=[{id:'source-van',actor,object}],traffic={getActors:()=>records,getActor:id=>records.find(r=>r.id===id)?.actor,blocks:(x,z,r=0,options={})=>records.some(v=>v.id!==options.ignoreId&&trafficActorBlocks(v.actor,x,z,r,options))};
const source=fs.readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8');
const body=source.match(/function pedestrianAllowed\(x,z,ignoreSourceId=null\)\{([^\n]+)\}/)[0];
const context={worldTrafficPresentation:traffic,hero:{object:{position:{y:0}}},canWalk:()=>true,fleet:{overlaps:()=>false}};
vm.createContext(context);vm.runInContext(body,context);
const allowed=context.pedestrianAllowed;
assert.equal(allowed(0,0),false,'actual walk blocks the source car even with an empty local fleet');
assert.equal(allowed(3,0),true);
let position={x:-3,y:0,z:0};for(let i=0;i<180;i++){const next=movePedestrian(position,{x:.08,z:0},allowed);position={x:next.x,y:0,z:next.z};}
assert.ok(position.x<-1.3,'the swept pedestrian capsule stops outside the rendered body');
// A hero already inside the streamed car can walk toward the nearest exit,
// but cannot use recovery to walk deeper into it or pass through another car.
assert.equal(sourceVehicleEscapeId(traffic,{x:-.8,y:0,z:0},{x:-.1,z:0}),'source-van');
assert.equal(sourceVehicleEscapeId(traffic,{x:-.8,y:0,z:0},{x:.1,z:0}),null);
let trapped={x:-.8,y:0,z:0};for(let i=0;i<30;i++){
 const delta={x:-.08,z:0},ignore=sourceVehicleEscapeId(traffic,trapped,delta),next=movePedestrian(trapped,delta,(x,z)=>allowed(x,z,ignore));trapped={x:next.x,y:0,z:next.z};
}
assert.ok(trapped.x<-2,'recovery exits continuously without teleporting');
context.canWalk=x=>x>-.95;
const stopped=movePedestrian({x:-.8,y:0,z:0},{x:-.2,z:0},(x,z)=>allowed(x,z,'source-van'));
assert.ok(stopped.x>-.95,'source recovery still obeys walls');context.canWalk=()=>true;
const start={x:-1.8,y:0,z:0},bodies=sourceVehicleCoverBodies(T,traffic,start),canOccupy=p=>circleFits(p.x,p.z,allowed);
assert.equal(bodies.length,1);assert.equal(bodies[0].source.car,actor,'cover uses the original actor, never a fleet clone');
const cover=findCover({position:start,direction:{x:1,z:0},bodies,canOccupy});assert.ok(cover);assert.equal(cover.id,'source-vehicle:source-van');assert.ok(cover.height>.9&&cover.height<1.1);assert.equal(cover.body.valid(),true);
object.position.x+=.2;assert.equal(cover.body.valid(),false,'moving source invalidates old attachment');object.position.x=0;
object.userData.sourceMotion={speed:2,turnRate:0};assert.equal(sourceVehicleCoverBodies(T,traffic,start).length,0,'moving cars cannot acquire stationary cover');object.userData.sourceMotion.speed=0;
object.position.y=5;assert.equal(allowed(0,0),true,'a vehicle on an upper level does not block the player below it');object.position.y=0;
object.visible=false;assert.equal(allowed(0,0),true);assert.equal(sourceVehicleCoverBodies(T,traffic,start).length,0);object.visible=true;
records.length=0;assert.equal(cover.body.valid(),false,'source removal releases attachment');
const host=fs.readFileSync(new URL('./hero_cover_host.mjs',import.meta.url),'utf8');
assert.ok(host.includes('Ctrl — в укрытие'));assert.ok(!host.includes('C — присесть'));
assert.ok(source.includes('sourceVehicleCoverBodies(THREE,worldTrafficPresentation,position)'));
assert.ok(source.includes('blocksDynamic:(x,z,y,height)=>!!worldTrafficPresentation?.blocks(x,z,0,{y,height})'));
console.log('PASS actual walk source vehicle collision, swept approach, native actor cover, movement/removal/height guards and Ctrl hint');
