import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createMercenaryPickingProbe,mercenaryPickingRootCategory} from './mercenary_picking_probe.mjs';
import {createMercenaryTargets} from './mercenary_targets.mjs';
const THREE=await import(pathToFileURL((process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor')+'/build/three.module.js'));

let time=1000,clockCalls=0,domWrites=0;
const dataset=new Proxy({}, {set(o,k,v){domWrites++;o[k]=v;return true;}}),doc={documentElement:{dataset}};
const probe=createMercenaryPickingProbe({enabled:true,document:doc,now:()=>{clockCalls++;return time+=.01;}});
const off=createMercenaryPickingProbe({enabled:false,document:new Proxy({}, {get(){throw Error('QA-off DOM access');}}),now(){throw Error('QA-off timer');}});
assert.equal(off,null);
const scene=new THREE.Scene(),root=new THREE.Group();root.name='Город · покрытия, трава и дорожное оформление';scene.add(root);
const hitsByName=new Map(),called=[];
function node(name,distance,parent=root){const object=new THREE.Object3D();object.name=name;const hit={object,distance,point:new THREE.Vector3(),faceIndex:7};hitsByName.set(name,hit);object.raycast=function(ray,intersections){assert.equal(this,object);called.push(name);intersections.push(hit);};parent.add(object);return object;}
const a=node('a',2),b=node('b',2),near=node('near',1),hidden=new THREE.Group();hidden.visible=false;root.add(hidden);node('hidden-parent',3,hidden);
const stop=new THREE.Group();stop.raycast=function(){assert.equal(this,stop);called.push('stop');return false;};root.add(stop);node('never',.1,stop);
const excluded=node('excluded',.05);excluded.layers.set(5);
const ray=new THREE.Raycaster();ray.set(new THREE.Vector3(0,0,5),new THREE.Vector3(0,0,-1));
const baseline=ray.intersectObjects([root],true),baselineCalls=called.slice();called.length=0;
const descriptors=new Map([a,b,near,stop,excluded].map(n=>[n,Object.getOwnPropertyDescriptor(n,'raycast')]));
assert(probe.begin(time));probe.mark('registryMs');const measured=probe.intersect(ray,[root]);probe.selected({id:'expected'},measured[0]);probe.finish();
assert.deepEqual(called,baselineCalls,'exact traversal, false propagation and layer behavior');assert.equal(measured.length,baseline.length);
for(let i=0;i<baseline.length;i++)assert.equal(measured[i],baseline[i],'original hit identity and stable equal-distance order');
for(const[n,d]of descriptors)assert.deepEqual(Object.getOwnPropertyDescriptor(n,'raycast'),d,'own descriptor restored');
assert.equal(Object.hasOwn(root,'raycast'),false,'unmodified Group never receives own callback');
let profile=JSON.parse(dataset.mercenaryPickingProfile);assert.equal(profile.intersections,4);assert.equal(profile.candidateCount,1);assert.equal(profile.categories.environment.calls,5);assert.equal(profile.firstAcceptedHit.name,'near');assert.equal(profile.selectedTargetId,'expected');assert.equal(profile.ray.far,null);assert.equal(profile.ray.farKind,'infinite');assert.equal(profile.instrumentationComplete,true);assert(profile.timings.traversalSortProbeResidualMs>=0);assert.equal(domWrites,1);

// Throttled QA is the original call, with no candidate traversal/wrapping/timer.
const beforeClock=clockCalls;assert.equal(probe.begin(time+200),false);const rootAccess=[];
const passthrough={intersectObjects(roots,recursive){rootAccess.push({roots,recursive});return baseline;}};
const forbiddenRoots=new Proxy([], {get(){throw Error('unsampled probe traversed roots');}});
assert.equal(probe.intersect(passthrough,forbiddenRoots),baseline);assert.equal(clockCalls,beforeClock);assert.equal(rootAccess.length,1);assert.equal(rootAccess[0].roots,forbiddenRoots);probe.finish();assert.equal(domWrites,1);

// A throwing custom callback keeps the same error, and every installed method
// is restored before caller code handles it.
const error=Error('original raycast failure'),thrower=new THREE.Object3D();thrower.raycast=function(){assert.equal(this,thrower);throw error;};root.add(thrower);const throwingDescriptor=Object.getOwnPropertyDescriptor(thrower,'raycast');
time=2500;probe.begin(time);let caught;
try{probe.intersect(ray,[root]);}catch(e){caught=e;}finally{probe.finish({failed:true});}
assert.equal(caught,error);assert.deepEqual(Object.getOwnPropertyDescriptor(thrower,'raycast'),throwingDescriptor);for(const[n,d]of descriptors)assert.deepEqual(Object.getOwnPropertyDescriptor(n,'raycast'),d);assert(JSON.parse(dataset.mercenaryPickingProfile).failed);thrower.removeFromParent();

// Mesh's inherited raycast is restored by deleting the temporary own property.
const mesh=new THREE.Mesh(new THREE.BoxGeometry(1,1,1),new THREE.MeshBasicMaterial());mesh.name='actual-mesh';mesh.updateMatrixWorld();const meshMethod=mesh.raycast;
time=4000;probe.begin(time);const meshHits=probe.intersect(ray,[mesh]);probe.finish();assert(meshHits.length);assert.equal(mesh.raycast,meshMethod);assert.equal(Object.hasOwn(mesh,'raycast'),false);

// Nested custom raycast callbacks are accounted exclusively, without changing
// their return value or taking over Three's recursion/sort.
const nested=new THREE.Object3D(),child=new THREE.Object3D();nested.raycast=function(rc,out){child.raycast(rc,out);};child.raycast=function(rc,out){out.push(hitsByName.get('near'));};nested.add(child);
const nestedBaseline=ray.intersectObjects([nested],true);time=5500;probe.begin(time);assert.deepEqual(probe.intersect(ray,[nested]),nestedBaseline);probe.finish();profile=JSON.parse(dataset.mercenaryPickingProfile);assert.equal(profile.raycastCalls,3);assert(profile.timings.exclusiveRaycastMs<=profile.timings.intersectTotalMs+1e-8);

// Duplicate candidate roots retain original duplicate-hit ordering, no root
// deduplication is applied to the authoritative query.
const duplicates=ray.intersectObjects([root,root],true);time=7000;probe.begin(time);const duplicated=probe.intersect(ray,[root,root]);probe.finish();for(let i=0;i<duplicates.length;i++)assert.equal(duplicated[i],duplicates[i]);assert.equal(duplicated.length,duplicates.length);

// Integration parity of real Three box/instance intersections and target data.
const actualScene=new THREE.Scene(),camera=new THREE.PerspectiveCamera(50,1,.1,200);camera.position.set(0,1,8);camera.lookAt(0,1,0);camera.updateMatrixWorld();
const car=new THREE.Mesh(new THREE.BoxGeometry(2,2,2),new THREE.MeshBasicMaterial());car.position.y=1;actualScene.add(car);actualScene.updateMatrixWorld(true);
const fleet={records:[{id:'v1',car:{object:car}}]},baseTargets=createMercenaryTargets({THREE,camera,getRoots:()=>[car],getFleet:()=>fleet}),qaTargets=createMercenaryTargets({THREE,camera,getRoots:()=>[car],getFleet:()=>fleet,pickingProbe:probe});
const targetBaseline=baseTargets.pick();time=8500;probe.begin(time);probe.mark('guardAndRosterMs');const targetMeasured=qaTargets.pick();probe.finish();assert.deepEqual(targetMeasured,targetBaseline);profile=JSON.parse(dataset.mercenaryPickingProfile);assert.equal(profile.categories.cars.roots,1);assert.equal(profile.firstAcceptedHit.uuid,car.uuid);assert.equal(profile.selectedTargetId,'fleet:v1');for(const phase of ['registryMs','candidateQueryMs','raySetupMs','resolveMs'])assert(Number.isFinite(profile.timings[phase]));
const instances=new THREE.InstancedMesh(new THREE.BoxGeometry(1,1,1),new THREE.MeshBasicMaterial(),2);instances.setMatrixAt(0,new THREE.Matrix4());instances.setMatrixAt(1,new THREE.Matrix4().makeTranslation(0,0,2));instances.computeBoundingSphere();instances.updateMatrixWorld();const instanceBaseline=ray.intersectObjects([instances],true);time=10000;probe.begin(time);const instanceMeasured=probe.intersect(ray,[instances]);probe.finish();assert.deepEqual(instanceMeasured,instanceBaseline);assert.equal(Object.hasOwn(instances,'raycast'),false);
assert.equal(mercenaryPickingRootCategory({userData:{nativeTerrainKind:'asphalt'}}),'native-terrain:asphalt');assert.equal(mercenaryPickingRootCategory(root,'npc'),'npc');
probe.dispose();assert.equal(dataset.mercenaryPickingProfile,undefined);assert.equal(probe.begin(20000),false);
mesh.geometry.dispose();mesh.material.dispose();car.geometry.dispose();car.material.dispose();instances.geometry.dispose();instances.material.dispose();
console.log('PASS picking probe: same original sorted hit references, root duplicates, layers, return false, this, exception identity, descriptors/finally, inherited Mesh/InstancedMesh, nested exclusive accounting, natural 1 Hz throttle, QA-off zero access, target parity');
