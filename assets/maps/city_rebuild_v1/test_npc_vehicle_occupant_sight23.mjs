import assert from 'node:assert/strict';
import fs from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createDemoCar,CAR,DRIVER_SEAT} from './car_drive.mjs';
import {createHeroWalker,HERO_ASSET} from './hero_walk.mjs';
import {createNpcNativePerception} from './npc_native_perception.mjs';
import {vehicleWindowFrame,setVehicleWindowOpen} from './vehicle_window_fire.mjs';
import {VEHICLE_SEATS} from './vehicle_seats.mjs';
import {createGlassBreakage} from './glass_breakage.mjs';
import {createVehicleOccupantSight} from './npc_vehicle_occupant_sight.mjs';
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(specifier,context,next){return next(specifier==='three'?pathToFileURL(vendor+'/build/three.module.js').href:specifier,context);}});
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const {RoundedBoxGeometry}=await import('../../../tools/vehicle_fleet_qa/RoundedBoxGeometry.mjs');
const bytes=fs.readFileSync(new URL(HERO_ASSET.url)),source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
const hero=createHeroWalker({THREE,scene:source,targetHeight:1.9}),scene=new THREE.Scene(),car=createDemoCar(THREE,RoundedBoxGeometry);
car.profile={...CAR,id:'red_sedan',height:2.22};car.seats=VEHICLE_SEATS;scene.add(car.object,hero.object);car.object.position.set(612.95,0,59.45);
let local=true,time=0,frame=0,target,bodies=[],otherCars=[],physicalObstacles=[car.object];
const cops=new Map(Array.from({length:12},(_,i)=>[i===0?'cop':'cop'+(i+1),{id:'cop'+i,alive:true,hp:100,_shotSeq:0}]));
const world=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8');
const markSource=world.slice(world.indexOf('function _markPoliceShot('),world.indexOf('// One collision-aware mover',world.indexOf('function _markPoliceShot(')));
const markPoliceShot=Function(markSource+';return _markPoliceShot;')();
const external=createNpcNativePerception({getVehicles:()=>otherCars,bodiesAt:()=>bodies});
const candidate=createVehicleOccupantSight({THREE,getTarget:()=>target,getObserver:id=>cops.get(id),getActors:()=>[{id:'player',object:hero.object}],local:()=>local,now:()=>time,obstacles:()=>physicalObstacles,environmentClear:({origin,target:end,excludeVehicle})=>{
 assert.equal(excludeVehicle,car);external.beginFrame();return !external.query({fromR:origin.z/4.1,fromC:origin.x/4.1,toR:end.z/4.1,toC:end.x/4.1,eyeHeight:origin.y,targetHeight:end.y}).blocked;
}});
function pose(){car.object.updateMatrixWorld(true);const seat=car.object.localToWorld(new THREE.Vector3(DRIVER_SEAT.side,DRIVER_SEAT.y,DRIVER_SEAT.front));hero.object.position.copy(seat);hero.object.rotation.y=car.object.rotation.y;hero.vehiclePose(1,0,{driver:true,steeringGrips:car.getSteeringGrips(),dt:.1});hero.object.updateMatrixWorld(true);target={id:'player',phase:'drive',seatId:'front_left',car,actor:hero,r:seat.z/4.1,c:seat.x/4.1};}
function request(localOrigin=[10,1.45,-.15],sourceId='cop'){const origin=car.object.localToWorld(new THREE.Vector3(...localOrigin));Object.assign(cops.get(sourceId),{x:origin.x/4.1,y:origin.z/4.1});return {sourceId,targetId:'player',toR:target.r,toC:target.c,origin};}
function next(){time+=300;candidate.beginFrame(++frame);}
function inspect(r){candidate.beginFrame(++frame);return candidate.inspect(r);}
let checks=0;const check=(v,label)=>{assert(v,label);checks++;};pose();
const rows=[];
for(const p of [[10,1.45,-.15],[-10,1.45,-.15],[.43,1.45,10],[.43,1.45,-10]])rows.push({from:p,...inspect(request(p))});
const observed=inspect({...request(),origin:new THREE.Vector3(148.72532582532375*4.1,1.45,16.743298434422293*4.1)});check(observed.visible,'observed cop position has real glass LOS to actual posed driver in authored Kingswell pose');
const ownSide=request();const sight=inspect(ownSide);check(sight.visible,'actual posed driver visible through actual Kingswell driver window: '+JSON.stringify(sight));
check(sight.glassAhead,'closed actual driver pane remains a physical surface');
next();const pane=candidate.prepareAttack(ownSide);check(pane.accepted&&pane.kind==='vehicle_glass','first physical contact is glass, never player HP: '+JSON.stringify({kind:pane.kind,reason:pane.reason}));
check(candidate.prepareAttack({...ownSide,sourceId:'cop2'}).reason==='frame_budget','one physical skin probe per frame');
const glass=createGlassBreakage(THREE,scene,{groundHeight:()=>0});glass.prepare(car.object);
check(!candidate.consume(pane,()=>assert.fail('not a source shot')),'prepared geometry alone is not a source shot');
markPoliceShot(cops.get('cop'),'pistol',time);let effects=0,fractured;
check(candidate.consume(pane,proof=>{effects++;fractured=glass.hit(proof.hit,{direction:proof.direction,impulse:18,weaponId:'tt_pistol'});}), 'actual source shot sequence consumes physical outcome');
check(!candidate.consume(pane,()=>effects++)&&effects===1,'same proof/shot sequence cannot duplicate damage or glass effects');check(fractured.broken,'existing real glass adapter consumes physical first contact');
glass.update(.3);
let fracturedContact;for(let i=0;i<6;i++){next();fracturedContact=candidate.prepareAttack(request());if(fracturedContact.kind!=='vehicle_glass')break;const fracturedAgain=glass.hit(fracturedContact.hit,{direction:fracturedContact.direction,impulse:18,weaponId:'tt_pistol'});check(fracturedAgain.broken,'each remaining closed glass surface must fracture separately: '+JSON.stringify(fracturedAgain));glass.update(.3);}
check(fracturedContact.kind==='occupant','only a later fresh ray through actually fractured pane reaches skin: '+JSON.stringify({kind:fracturedContact.kind,reason:fracturedContact.reason,object:fracturedContact.hit?.object?.name}));
next();setVehicleWindowOpen(car,'front_left',true);const open=candidate.prepareAttack(request());check(open.accepted&&open.kind==='occupant','open driver aperture reaches current posed skin');
target.visibilityRevision=1;check(inspect(request()).reason==='visible_open_aperture','opened glass is not a remaining invisible shield');
// The same original vehicle still blocks every ray through its door metal.
const low=inspect(request([1.4,.5,-.15]));check(!low.visible&&low.reason==='own_opaque_cover','metal door blocks low incoming ray, despite excluded coarse hull: '+JSON.stringify(low));pose();
const head=hero.artistContext().worldPosition('head'),origin=request().origin,mid=head.clone().lerp(origin,.5),r=mid.z/4.1,c=mid.x/4.1;
bodies=[{polygonCR:[[c-.05,r-.6],[c+.05,r-.6],[c+.05,r+.6],[c-.05,r+.6]],minYM:0,maxYM:3}];check(!inspect(request()).visible,'native wall remains blocking');bodies=[];
otherCars=[{profile:{...CAR,height:2.22},object:{visible:true,position:{x:mid.x,y:0,z:mid.z},scale:{x:1,y:1,z:1},rotation:{y:0}}}];check(!inspect(request()).visible,'other car remains blocking');otherCars=[];
local=false;check(!inspect(request()).visible,'online cannot use local candidate');local=true;
target.phase='exit';check(!inspect(request()).visible,'exit is not stable seated');target.phase='drive';target.exitPending=true;check(!inspect(request()).visible,'pending exit rejected');target.exitPending=false;
check(!inspect({...request(),toR:target.r+1}).visible,'source target coordinates cannot refer to another actor');
const saved=target;target={...target,actor:{object:new THREE.Group()}};check(!inspect({...request(),targetId:'player'}).visible,'missing actual posed head rejects');target=saved;
car.object.position.x+=5;car.object.rotation.y=.8;check(!inspect(request()).visible,'moved car with stale target seat/pose rejected');pose();check(inspect(request()).visible,'fresh moving/turning car with fresh posed driver remains visible');
next();check(candidate.prepareAttack(request()).kind==='occupant','fresh moved skin contact, no old geometry proof');
check(candidate.prepareAttack(request()).reason==='probe_backoff','repeated source query does not consume another physical probe');
candidate.beginFrame(++frame);check(candidate.prepareAttack(request()).reason==='probe_backoff','rejected repeated observer cannot monopolize next frame');check(candidate.prepareAttack({...request(),sourceId:'cop2'}).accepted,'next observer can receive bounded probe');
const resolved=new Set();let pending=0,maxSight=0;
for(let tick=0;tick<8;tick++){
 time+=16;candidate.beginFrame(++frame);
 for(const id of cops.keys()){const result=candidate.inspect(request([10,1.45,-.15],id));if(result.pending){check(result.visible===null,'budget wait is explicit PENDING, not negative visual evidence');pending++;}else if(result.visible)resolved.add(id);}
 maxSight=Math.max(maxSight,candidate.stats().sightProbes);check(candidate.stats().sightProbes<=2,'12 cops cannot cause more than two exact car sight rays per frame');
}
check(resolved.size===12,'all 12 existing observers get a fair eventual sight result');
time+=200;candidate.beginFrame(++frame);check(candidate.inspect(request()).visible,'TTL refresh after the fair queue drains');
const freshCount=candidate.stats().sightProbes;check(candidate.inspect(request()).visible&&candidate.stats().sightProbes===freshCount,'unchanged source/car/head uses cheap cache');
candidate.beginFrame(++frame);const drift=request();drift.origin.x+=.1;check(candidate.inspect(drift).visible&&candidate.stats().sightProbes===1,'source position invalidates cached car sight');
candidate.beginFrame(++frame);hero.object.position.y+=.01;check(candidate.inspect(request()).visible&&candidate.stats().sightProbes===1,'posed head motion invalidates cache');hero.object.position.y-=.01;
candidate.beginFrame(++frame);target.visibilityRevision=(target.visibilityRevision||0)+1;check(candidate.inspect(request()).visible&&candidate.stats().sightProbes===1,'glass/door/damage revision invalidates car sight');
cops.get('cop').hp=0;check(candidate.inspect(request()).visible===false,'dead source cannot use live cached visibility');cops.get('cop').hp=100;
candidate.beginFrame(++frame);cops.set('cop',{...cops.get('cop')});check(candidate.inspect(request()).visible&&candidate.stats().sightProbes===1,'source identity reuse invalidates cache');
next();const stale=candidate.prepareAttack(request());check(stale.accepted,'fresh proof for timestamp guard');markPoliceShot(cops.get('cop'),'pistol',time);time+=51;check(!candidate.consume(stale,()=>assert.fail('expired proof')),'physical proof expires after50ms');
next();const moved=candidate.prepareAttack(request());check(moved.accepted,'fresh proof for pose guard');markPoliceShot(cops.get('cop'),'pistol',time);hero.object.position.y+=.01;check(!candidate.consume(moved,()=>assert.fail('stale body pose')),'pose movement between preparation and consumption rejects');hero.object.position.y-=.01;
check(!candidate.consume({...moved},()=>assert.fail('forged proof')),'copied/forged proof has no internal receipt');
next();const miss=candidate.prepareAttack({...request(),aimOffset:new THREE.Vector3(0,2.8,0)});check(miss.accepted&&miss.kind==='miss','actual source spread may miss; sight never manufactures a skin hit');markPoliceShot(cops.get('cop'),'pistol',time);let misses=0;check(candidate.consume(miss,p=>{check(p.hit===null,'miss has no physical victim');misses++;})&&misses===1,'real source miss consumes exactly one sequence with no HP target');
next();const sourceMoved=candidate.prepareAttack(request());check(sourceMoved.accepted,'fresh proof before cop movement');markPoliceShot(cops.get('cop'),'pistol',time);cops.get('cop').x+=.1;check(!candidate.consume(sourceMoved,()=>assert.fail('stale cop pose')),'source/cop movement after preparation invalidates physical proof');
const timings=[];for(let i=0;i<30;i++){const start=performance.now();candidate.inspect(request());if(i>=6)timings.push(performance.now()-start);}timings.sort((a,b)=>a-b);
console.log(JSON.stringify({status:'PASS production occupant geometry/sequence proof',checks,observedCop:observed,headInCar:car.object.worldToLocal(hero.artistContext().worldPosition('head')).toArray(),firstAttack:pane.kind,openAttack:open.kind,cardinalVisibility:rows.map(({from,visible,reason})=>({from,visible,reason})),inspectCachedCpuMs:{samples:timings.length,p50:timings[Math.floor(timings.length*.5)],p95:timings[Math.floor(timings.length*.95)]},fairness:{observers:resolved.size,pending,maxSight},budget:candidate.stats()},null,2));
glass.dispose();
