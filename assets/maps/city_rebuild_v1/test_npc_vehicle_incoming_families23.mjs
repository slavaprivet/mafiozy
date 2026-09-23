import assert from 'node:assert/strict';
import fs from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createDemoCar,CAR} from './car_drive.mjs';
import {createHeroWalker,HERO_ASSET} from './hero_walk.mjs';
import {createArtistVehicle,ARTIST_VEHICLE_PROFILES} from './vehicle_fleet_models.mjs';
import {decorateCityTaxi} from './vehicle_taxi.mjs';
import {clone} from './test_npc_death_offline_setup.mjs';
import {VEHICLE_SEATS} from './vehicle_seats.mjs';
import {vehicleWindowFrame,setVehicleWindowOpen} from './vehicle_window_fire.mjs';
import {createVehicleOccupantSight} from './npc_vehicle_occupant_sight.mjs';
import {createNpcNativePerception} from './npc_native_perception.mjs';
import {createNpcVehicleIncomingBridge} from './npc_vehicle_incoming.mjs';
import {createGlassBreakage} from './glass_breakage.mjs';
import {createLocalVehicleIncomingCapability} from './npc_vehicle_incoming_capability.mjs';
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c)}});
const T=await import(pathToFileURL(vendor+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const {RoundedBoxGeometry}=await import('../../../tools/vehicle_fleet_qa/RoundedBoxGeometry.mjs');
const loader=new GLTFLoader(),parse=async url=>{const b=fs.readFileSync(new URL(url));return (await loader.parseAsync(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),'')).scene;};
const sources={male:await parse(HERO_ASSET.url),female:await parse(new URL('./hero_models/player_female.298d50e6244a.glb',import.meta.url))};
const read=url=>fs.readFileSync(new URL(url,import.meta.url),'utf8');
const walk=read('./walk_preview.mjs'),anchor='npcVehicleIncoming=createNpcVehicleIncomingBridge({THREE,getTarget:',start=walk.indexOf(anchor)+anchor.length,end=walk.indexOf(',getActors:',start);
assert(start>=anchor.length&&end>start,'current actual Walk target getter exists');
const original=walk.slice(start,end),oldGate="if(car.profile?.id!=='red_sedan')return {unavailable:true,reason:'local-model-not-validated'};";
const newGate="const capability=npcVehicleIncomingCapability.check(car,occupiedSeat);if(!capability.supported)return {unavailable:true,reason:capability.reason};";
if(process.argv.includes('--require-fixed'))assert(!original.includes(oldGate)&&original.includes(newGate),'actual production must include capability gate');
else assert(original.includes(oldGate)!==original.includes(newGate),'one known actual model/capability gate required');
const proposed=original.replace(oldGate,newGate);
const world=read('../../../world.html'),markStart=world.indexOf('function _markPoliceShot('),markEnd=world.indexOf('// One collision-aware mover',markStart),mark=Function(world.slice(markStart,markEnd)+';return _markPoliceShot;')();
let checks=0,scenarioCount=0;const check=(v,s)=>{assert(v,s);checks++};
const rows=[],timings={capabilityCold:[],capabilityWarm:[],sightCold:[],physical:[]},started=performance.now(),capability=createLocalVehicleIncomingCapability();
const profiles=[{id:'red_sedan'},...ARTIST_VEHICLE_PROFILES,{...ARTIST_VEHICLE_PROFILES.find(p=>p.id==='compact_sedan'),id:'city_taxi',sourceId:'compact_sedan'}];
for(const profile of profiles){
 let car;if(profile.id==='red_sedan'){car=createDemoCar(T,RoundedBoxGeometry);car.profile={...CAR,id:'red_sedan',height:2.22};car.seats=VEHICLE_SEATS;}
 else {const p=profile.sourceId?ARTIST_VEHICLE_PROFILES.find(p=>p.id===profile.sourceId):profile;const source=await parse(new URL('./models/artist_vehicle_pack/'+p.modelFile,import.meta.url));car=createArtistVehicle(T,RoundedBoxGeometry,source,p);if(profile.sourceId)car=decorateCityTaxi(T,RoundedBoxGeometry,car);}
 const scene=new T.Scene();scene.add(car.object);const modelRow={model:profile.id,seats:car.seats.length,scenarios:0,closedGlass:0,openSkin:0,extraGlass:0,opaqueDoor:0,roof:0};
 for(const sex of ['male','female']){
  const hero=createHeroWalker({THREE:T,scene:clone(sources[sex]),targetHeight:1.9});scene.add(hero.object);
  for(const seat of car.seats)for(const yaw of [0,.73]){
   const label=profile.id+'/'+sex+'/'+seat.id+'/'+yaw;scenarioCount++;modelRow.scenarios++;
   car.object.position.set(612.95,0,59.45);car.object.rotation.set(0,yaw,0);
   function pose(){car.object.updateMatrixWorld(true);const root=car.object.localToWorld(new T.Vector3(seat.anchor.side,seat.anchor.y,seat.anchor.front));hero.object.position.copy(root);hero.object.rotation.y=car.object.rotation.y;if(car.poseOccupant)car.poseOccupant(hero,seat.id,{steer:0,dt:.1});else hero.vehiclePose(1,0,{driver:seat.canDrive,steeringGrips:car.getSteeringGrips(),dt:.1});hero.object.updateMatrixWorld(true);return root;}
   const root=pose();let time=0,frame=0,source=false,foot=false,transition=false,local=true,bodies=[],otherCars=[],friends=[];
   const glass={stats:()=>({brokenPanels:0})},scope={car,hero,glass,carDamage:{state:{hp:240}},worldHealthFrame:{snapshot:{dead:false}},heroCustodyActive:false,M:4.1,npcVehicleIncomingCapability:capability,sourceVehicleActive:()=>source,get occupiedSeat(){return foot?null:seat.id},get transition(){return transition}};
   const getTarget=Function('scope','with(scope){return ('+proposed+');}')(scope),cop={id:'cop',alive:true,hp:100,_shotSeq:0};
   const native=createNpcNativePerception({getVehicles:()=>otherCars,bodiesAt:()=>bodies});
   const sight=createVehicleOccupantSight({THREE:T,getTarget,getObserver:()=>cop,getActors:()=>[{id:'player',object:hero.object},...friends],environmentClear:({origin,target})=>{native.beginFrame();return native.query({fromR:origin.z/4.1,fromC:origin.x/4.1,toR:target.z/4.1,toC:target.x/4.1,eyeHeight:origin.y,targetHeight:target.y}).blocked===false},obstacles:()=>[car.object],local:()=>local,now:()=>time});
   const scansBefore=capability.stats().geometryScans;let t=performance.now();const admission=capability.check(car,seat.id),admissionMs=performance.now()-t;check(admission.supported,label+' authored capability '+JSON.stringify(admission));if(capability.stats().geometryScans>scansBefore)timings.capabilityCold.push(admissionMs);
   const scanCount=capability.stats().geometryScans;t=performance.now();for(let i=0;i<100;i++)capability.check(car,seat.id);timings.capabilityWarm.push((performance.now()-t)/100);check(capability.stats().geometryScans===scanCount,label+' warm capability has zero geometry scans');
   check(getTarget().phase==='drive',label+' proposed actual Walk getter admits current local seat');
   check(hero.object.position.distanceTo(root)<1e-8,label+' actual pose retains authored authority root');
   const head=car.object.worldToLocal(hero.artistContext().worldPosition('head')),window=vehicleWindowFrame(T,car,seat.id),plane=Math.max(Math.abs(window.min[0]),Math.abs(window.max[0]));
   function request(point=[seat.side*8,1.45,head.z]){const origin=car.object.localToWorld(new T.Vector3(...point));Object.assign(cop,{x:origin.x/4.1,y:origin.z/4.1});time+=300;sight.beginFrame(++frame);const target=getTarget();return {sourceId:'cop',targetId:'player',toR:target.r??root.z/4.1,toC:target.c??root.x/4.1,origin};}
   let q=request();t=performance.now();const closed=sight.inspect(q);timings.sightCold.push(performance.now()-t);check(closed.visible&&closed.glassAhead,label+' glass is visible, never silently removed');
   t=performance.now();const hit=sight.prepareAttack(q);timings.physical.push(performance.now()-t);check(hit.kind==='vehicle_glass',label+' closed first physical contact is glass');modelRow.closedGlass++;
   check(!sight.consume(hit,()=>assert.fail('unmarked shot')),label+' prepared ray alone never dispatches');mark(cop,'pistol',time);let dispatched=0;check(sight.consume(hit,()=>dispatched++),label+' actual source seq authorizes one dispatch');check(!sight.consume(hit,()=>dispatched++)&&dispatched===1,label+' consumed proof cannot duplicate');
   setVehicleWindowOpen(car,seat.id,true);const open=sight.prepareAttack(request());
   if(profile.id==='city_bus'){check(open.kind==='vehicle_glass',label+' bus extra physical pane survives opening own door window');modelRow.extraGlass++;}
   else {check(open.kind==='occupant',label+' actual aperture reaches current posed skin');modelRow.openSkin++;}
   const low=sight.inspect(request([seat.side*(plane+.08),.4,head.z]));check(!low.visible&&low.reason==='own_opaque_cover',label+' door metal blocks: '+JSON.stringify(low));modelRow.opaqueDoor++;
   const roof=sight.inspect(request([head.x,car.profile.height+2,head.z]));check(!roof.visible&&roof.reason==='own_opaque_cover',label+' roof blocks: '+JSON.stringify(roof));modelRow.roof++;
   q=request();car.object.position.x+=.2;check(!sight.inspect(q).visible,label+' moving car/stale hero seat rejected');car.object.position.x-=.2;pose();
   const oldRoot=hero.object.position.clone();hero.object.position.x+=.2;check(!sight.inspect(request()).visible,label+' source-like authority root separated from seat rejected');hero.object.position.copy(oldRoot);hero.object.updateMatrixWorld(true);
   source=true;check(getTarget().reason==='source-pose-stamp-unavailable',label+' source variant still fails closed before capability');source=false;transition=true;check(getTarget().reason==='vehicle-transition-or-life',label+' transition refuses');transition=false;foot=true;check(getTarget()===null,label+' foot uses existing perception fallback');foot=false;
   local=false;check(!sight.inspect(request()).visible,label+' online cannot use local physical proof');local=true;
   setVehicleWindowOpen(car,seat.id,false);
   if(sex==='male'&&seat.id==='front_left'&&yaw===0){
    check(!capability.check(car,'invented_seat').supported,label+' missing seat refused');
    const door=car.doors.get(seat.doorId)||car.doors.get(1),parent=door.parent;door.removeFromParent();check(!capability.check(car,seat.id).supported,label+' detached door refused');parent.add(door);
    const pane=door.children.find(n=>n.isMesh&&(n.name==='Fitted_door_glass_'+seat.doorId||n.name==='Door_window_'+seat.doorId||n.userData.bodyWindow===seat.doorId))||door.children.find(n=>n.isMesh&&n.material?.userData?.breakableGlass);pane.removeFromParent();check(!capability.check(car,seat.id).supported,label+' missing pane refused');door.add(pane);
    const previous=pane.userData.breakableGlass;pane.userData.breakableGlass=false;check(!capability.check(car,seat.id).supported,label+' opaque replacement pane cannot opt into glass');if(previous===undefined)delete pane.userData.breakableGlass;else pane.userData.breakableGlass=previous;
    const oldSeats=car.seats;car.seats=car.seats.map(s=>s===seat?{...s,anchor:{...s.anchor,y:NaN}}:s);check(!capability.check(car,seat.id).supported,label+' nonfinite authored seat refused');car.seats=oldSeats;
    const saved=pane.geometry;pane.geometry=saved.clone();const p=pane.geometry.attributes.position;p.setY(0,NaN);p.needsUpdate=true;check(!capability.check(car,seat.id).supported,label+' nonfinite real pane refused');pane.geometry.dispose();pane.geometry=saved;
    const originalId=car.profile.id;car.profile.id='renamed_same_geometry';check(capability.check(car,seat.id).supported,label+' model name is not authority');car.profile.id=originalId;
    const origin=request().origin,worldHead=hero.artistContext().worldPosition('head'),mid=origin.clone().lerp(worldHead,.5),r=mid.z/4.1,c=mid.x/4.1;
    bodies=[{polygonCR:[[c-.08,r-.6],[c+.08,r-.6],[c+.08,r+.6],[c-.08,r+.6]],minYM:0,maxYM:5}];check(sight.inspect(request()).reason==='environment_cover',label+' native wall remains authoritative');bodies=[];
    otherCars=[{profile:{...CAR,height:4},object:{visible:true,position:{x:mid.x,y:0,z:mid.z},scale:{x:1,y:1,z:1},rotation:{y:0}}}];check(sight.inspect(request()).reason==='environment_cover',label+' other vehicle hull remains');otherCars=[];
    const friend=createHeroWalker({THREE:T,scene:clone(sources.female),targetHeight:1.9});scene.add(friend.object);friend.object.position.copy(mid);friend.object.position.y-=1.1;friend.object.updateMatrixWorld(true);friends=[{id:'friend',object:friend.object}];check(sight.prepareAttack(request()).reason==='other_body_or_cover',label+' physical other actor blocks');friends=[];friend.object.removeFromParent();
    if(profile.id==='city_bus'){
     const realGlass=createGlassBreakage(T,scene,{groundHeight:()=>0});realGlass.prepare(car.object);let physical,panes=0;
     for(let i=0;i<5;i++){physical=sight.prepareAttack(request());if(physical.kind!=='vehicle_glass')break;mark(cop,'pistol',time);let broken=false;check(sight.consume(physical,p=>{broken=realGlass.hit(p.hit,{direction:p.direction,impulse:18,weaponId:'tt_pistol'}).broken}),label+' actual bus pane consumes real shot');check(broken,label+' real bus glass fracture owner');realGlass.update(.3);panes++;}
     check(panes>=1&&physical.kind==='occupant',label+' only actual bus fracture exposes posed skin');modelRow.fracturedPanes=panes;realGlass.dispose();
    }
    // Actual bridge authority and source rejection use the proposed actual getter.
    const bridge=createNpcVehicleIncomingBridge({THREE:T,getTarget,getActors:()=>[{id:'player',object:hero.object}],obstacles:()=>[car.object],getVehicles:()=>[car],bodiesAt:()=>[],local:()=>local});
    source=true;check(bridge.resolve({phase:'sight',localAllowed:true}).reason==='source-pose-stamp-unavailable',label+' actual bridge rejects source variant');source=false;local=false;check(bridge.resolve({phase:'sight',localAllowed:true}).reason==='local-authority',label+' actual bridge rejects online');foot=true;check(bridge.resolve({phase:'sight',localAllowed:true})===null,label+' actual bridge preserves online foot fallback');foot=false;local=true;
   }
  }
  hero.object.removeFromParent();
 }
 rows.push(modelRow);car.object.removeFromParent();
}
const percentiles=a=>{a.sort((x,y)=>x-y);return {samples:a.length,p50:a[Math.floor(a.length*.50)],p95:a[Math.floor(a.length*.95)],max:a.at(-1)}};
const result={status:'PASS actual geometry; see require-fixed for production gate; no LIVE',checks,scenarioCount,models:rows,capability:capability.stats(),cpuMs:Object.fromEntries(Object.entries(timings).map(([k,v])=>[k,percentiles(v)])),totalMs:performance.now()-started};
console.log(JSON.stringify(result,null,2));
