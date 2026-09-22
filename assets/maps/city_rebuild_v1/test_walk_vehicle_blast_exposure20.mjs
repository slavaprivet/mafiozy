import assert from 'node:assert/strict';
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
import {createBlastResponse} from './blast_response.mjs';

const THREE=await import(pathToFileURL((process.env.MAFIOZI_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor')+'/build/three.module.js'));
const scene=new THREE.Scene(),staticRoot=new THREE.Group(),sourceObject=new THREE.Group(),otherObject=new THREE.Group();
const opaque=()=>new THREE.Mesh(new THREE.PlaneGeometry(4,4),new THREE.MeshStandardMaterial({side:THREE.DoubleSide}));
sourceObject.add(opaque());sourceObject.position.z=2;sourceObject.userData.sourceVehicleId='source-car';
otherObject.add(opaque());otherObject.position.z=3;otherObject.userData.sourceVehicleId='other-car';otherObject.visible=false;
scene.add(staticRoot,sourceObject,otherObject);
const sourceCar={object:sourceObject},otherCar={object:otherObject};
const vehicles=[{car:sourceCar,damage:{state:{wrecked:true,destroying:false}}},{car:otherCar,damage:{state:{wrecked:true,destroying:false}}}];
let callbacks=0,lastEvent=null,lastHeroExposure='unset';
const blast=createBlastResponse(THREE,scene,{getHero:()=>null,getVehicles:()=>vehicles,getRoots:()=>[staticRoot],getGlass:()=>({}),groundHeight:()=>0,
  onHeroLaunch:()=>assert.fail('no hero'),onBlast(event,heroExposure){callbacks++;lastEvent=event;lastHeroExposure=heroExposure;}});

blast.enqueue({point:{x:0,y:1,z:0},power:1,radius:10,source:sourceCar});
blast.update();
assert.equal(callbacks,1,'one dequeued explosion emits one gameplay callback');
assert(lastEvent?.source===sourceCar);assert.equal(lastHeroExposure,null,'callback is independent of hero presence');

let result=blast.resolveExposures({point:{x:0,y:1,z:0},sourceVehicleId:'source-car',targets:[
  {id:'near',point:{x:0,y:1.1,z:6}},
  {id:'far-unrendered',point:{x:100,y:1.1,z:60}},
  {id:'',point:{x:0,y:1,z:1}},
]});
assert.deepEqual(result.exposures,[{id:'near',transmission:1},{id:'far-unrendered',transmission:1}],
  'the source car never shields its own blast and distant logical targets are still resolved');

otherObject.visible=true;
result=blast.resolveExposures({point:{x:0,y:1,z:0},sourceVehicleId:'source-car',targets:[
  {id:'near',point:{x:0,y:1.1,z:6}},
  {id:'far-unrendered',point:{x:100,y:1.1,z:60}},
]});
assert.deepEqual(result.exposures,[{id:'near',transmission:0},{id:'far-unrendered',transmission:1}],
  'opaque cover blocks only the ray that actually crosses it');

const walk=fs.readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8');
assert(walk.includes('onBlast(event,heroExposure)'),'walk dispatches once per physical blast rather than from hero exposure');
assert(walk.includes('registerWalkBlastExposureResolver(request=>'),'walk registers the source-owned logical-target exposure provider');
assert(!walk.includes('onHeroExposure(event,exposure){\n // Source RPG/grenade damage'),'old hero-gated source dispatch is removed');

blast.dispose();
console.log('PASS walk vehicle blast provider: hero-independent event, source-car exclusion, opaque cover and distant logical target');
