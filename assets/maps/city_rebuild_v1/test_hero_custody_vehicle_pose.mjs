import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {performance} from 'node:perf_hooks';
import {createHeroWalker} from './hero_walk.mjs';
import {NPC_ASSETS} from './npc_actor.mjs';
import {createHeroCustodyVehiclePose} from './hero_custody_vehicle_pose.mjs';
import {createArtistVehicle} from './vehicle_fleet_models.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c);}});
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const glb=async url=>{const b=fs.readFileSync(url);return(await new GLTFLoader().parseAsync(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),'')).scene;};
class Box extends THREE.BoxGeometry{constructor(w,h,d){super(w,h,d);}}
const carSource=await glb(new URL('./models/artist_vehicle_pack/police_interceptor.glb',import.meta.url));
const code=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8');
const a=code.indexOf('function _threeCustodyPassengerSeat('),b=code.indexOf('window.Mafiozi3DBridge',a);assert(a>=0&&b>a);
const c={cityCops:[{_transportVehicleId:'qa_convoy',_transportBoarded:true,_transportSeatId:'front_left'},{_transportVehicleId:'qa_convoy',_transportBoarded:true,_transportSeatId:'front_right'}]};vm.createContext(c);vm.runInContext(code.slice(a,b),c);
const ar={phase:'transport',vehicleId:'qa_convoy',playerBoarded:true,playerAttachedVehicleId:'qa_convoy'};
assert.equal(c._threeCustodyPassengerSeat(ar).seatId,'rear_left');
c.cityCops.push({_transportVehicleId:'qa_convoy',_transportBoarded:true,_transportSeatId:'rear_left'});assert.equal(c._threeCustodyPassengerSeat(ar).seatId,'rear_right');
c.cityCops.push({_transportVehicleId:'qa_convoy',_transportBoarded:true,_transportSeatId:'rear_right'});assert.equal(c._threeCustodyPassengerSeat(ar),null,'no overlapping occupied rear seats');
assert.equal(c._threeCustodyPassengerSeat({...ar,playerBoarded:false}),null);assert.equal(c._threeCustodyPassengerSeat({...ar,playerAttachedVehicleId:'other'}),null);
const results=[];
for(const sex of ['male','female']){
 const scene=new THREE.Scene(),car=createArtistVehicle(THREE,Box,carSource,'police_interceptor');scene.add(car.object);car.object.position.set(628.5,0,405);car.object.rotation.y=.75;
 const walker=createHeroWalker({THREE,scene:await glb(new URL(NPC_ASSETS[sex].url)),targetHeight:sex==='male'?1.9:1.75});scene.add(walker.object);walker.object.position.set(628.637,0,405.285);walker.object.rotation.y=-.9;
 const root=walker.object.position.clone(),rotation=walker.object.quaternion.clone(),ctx=walker.artistContext();
 let available=true;const helper=createHeroCustodyVehiclePose({THREE,getVehicle:id=>available&&id==='service_qa_convoy'?car:null});
 const source={arrestPhase:'transport',custodyVehicleId:'service_qa_convoy',custodySeatId:'rear_left',healthDead:false,dead:false};
 walker.update(.016,false,false,null,{},{});const standingHead=ctx.worldPosition('head').clone();
 for(const seatId of ['rear_left','rear_right']){
  source.custodySeatId=seatId;walker.update(.016,false,false,null,{},{});helper.prepare(walker,source);assert(helper.apply(walker,source,.016).bound);scene.updateMatrixWorld(true);
  const head=ctx.worldPosition('head'),local=car.object.worldToLocal(head.clone()),anchor=car.seats.find(s=>s.id===seatId).anchor;
  assert(head.y<standingHead.y-.05&&local.y<car.profile.height-.35,'head leaves the standing pose and fits inside the cabin');
  assert(Math.abs(local.x-anchor.side)<.4,'head belongs to its exact rear seat');assert(local.z<0,'passenger stays behind the front crew');
  assert(walker.object.position.distanceTo(root)<1e-8,'source hero root is not reparented or moved');assert(walker.object.quaternion.angleTo(rotation)<1e-8);
  const thigh=ctx.worldPosition('thigh_l'),knee=ctx.worldPosition('shin_l'),foot=ctx.worldPosition('foot_l');
  assert(knee.distanceTo(foot)>.15);assert(Math.abs(thigh.y-knee.y)<.38,'thigh is folded forward into seated pose');
 }
 available=false;helper.apply(walker,source,.016);assert.equal(walker.object.visible,false,'unavailable exact car hides roof-standing fallback');available=true;assert(helper.apply(walker,source,.016).bound);assert(walker.object.visible);
 const beforeMove=ctx.worldPosition('head').clone();car.object.position.x+=1;helper.apply(walker,source,.016);assert(Math.abs(ctx.worldPosition('head').x-beforeMove.x-1)<.001,'seat tracks the current traffic transform');
 helper.prepare(walker,{arrestPhase:'unloading'});walker.update(.016,false,false,null,{},{});assert(walker.object.visible);assert(ctx.visualPivot.position.length()<1e-8);assert(ctx.worldPosition('head').distanceTo(standingHead)<.01,'unload restores normal on-foot skeleton at authoritative root');
 helper.prepare(walker,source);helper.apply(walker,source,.016);helper.prepare(walker,{...source,healthDead:true});assert.equal(helper.apply(walker,{...source,healthDead:true},.016).active,false,'death owns presentation priority');
 const measure=fn=>{const times=[];for(let i=0;i<300;i++){const t=performance.now();fn();if(i>=50)times.push(performance.now()-t);}times.sort((a,b)=>a-b);return {p50:times[125],p95:times[237]};};
 helper.prepare(walker,source);const before=measure(()=>walker.update(.016,false,false,null,{},{})),after=measure(()=>helper.apply(walker,source,.016));
 const stableHead=ctx.worldPosition('head').clone();for(let i=0;i<20;i++)helper.apply(walker,source,.016);assert(ctx.worldPosition('head').distanceTo(stableHead)<.001,'custody pose without idle reset never accumulates seat offsets');
 results.push({sex,before,after});
}
console.log('PASS actual male/female custody rear seat, source identity, follow, async loading, exit and death restore',JSON.stringify(results));
