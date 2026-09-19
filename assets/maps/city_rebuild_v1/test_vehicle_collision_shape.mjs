import assert from 'node:assert/strict';
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {createDemoCar,CAR} from './car_drive.mjs';
import {ARTIST_VEHICLE_PROFILES,createArtistVehicle} from './vehicle_fleet_models.mjs';
import {decorateCityTaxi} from './vehicle_taxi.mjs';
import {createVehicleHood} from './vehicle_hood.mjs';
import {createVehicleTrunk} from './vehicle_trunk.mjs';
import {buildVehicleCollisionShape,convexVehicleHull,collisionPolygon,collisionCircleOverlap} from './vehicle_collision_shape.mjs';
import {polygonVehicleContact} from './vehicle_contact.mjs';
const vendor=process.env.MAFIOZY_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const T=await import(pathToFileURL(vendor+'build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js')),{RoundedBoxGeometry}=await import('../../../tools/vehicle_fleet_qa/RoundedBoxGeometry.mjs');
const profiles=[...ARTIST_VEHICLE_PROFILES,{...ARTIST_VEHICLE_PROFILES.find(p=>p.id==='compact_sedan'),wheelDesignId:'city_taxi',taxi:true}],rows=[],fixtures=new Map();
const near=(a,b,e=1e-6)=>assert.ok(Math.abs(a-b)<e,`${a} != ${b}`);
function snapshot(car){const a=[];car.object.traverse(n=>a.push({id:n.uuid,p:n.position.toArray(),q:n.quaternion.toArray(),s:n.scale.toArray(),g:n.geometry,visible:n.visible}));return a}
// Independent pre-optimization traversal. It keeps the old Vector3 path as a
// byte-for-byte oracle for every real vehicle source vertex and transform.
function referenceCollisionShape(T,car){
 const root=car.object,doors=new Set(car.doors?.values?.()||[]),wheels=new Map((car.wheels||[]).map(w=>[w.pivot,w])),spins=new Set((car.wheels||[]).map(w=>w.wheel)),tyres=new Set((car.wheels||[]).map(w=>w.tire)),points=[],meshNames=[],excluded=[],v=new T.Vector3(),identity=new T.Matrix4(),unit=new T.Vector3(1,1,1),zeroQ=new T.Quaternion(),decorative=/Mirror|DoorHandle|Door_handle|Lightbar|Ladder|RoofRail|Roof_rail|Roofrail|RoofSpoiler|Spoiler|Taxi_(roof_sign|sign_mount|letters)|damage_effect|Engine_smoke|Hood_support_strut/i;
 function visit(node,parentMatrix,inWheel=false,inTyre=false){
  if(node!==root&&!node.visible)return;
  if(node===car.interior?.object||node.name?.startsWith('Interior_')||decorative.test(node.name||'')){excluded.push(node.name);return}
  let matrix=parentMatrix;
  if(node!==root){const wheel=wheels.get(node),closed=doors.has(node)||spins.has(node)||/^(Hood|Trunk)_hinge$/.test(node.name),local=new T.Matrix4().compose(wheel?.restPosition||node.position,wheel||closed?zeroQ:node.quaternion,tyres.has(node)?unit:node.scale);matrix=parentMatrix.clone().multiply(local);if(wheel)inWheel=true;if(tyres.has(node))inTyre=true}
  if(node.isMesh&&(!inWheel||inTyre)&&!node.material?.transparent){const a=node.geometry?.attributes?.position;if(a){meshNames.push(node.name);for(let i=0;i<a.count;i++){v.fromBufferAttribute(a,i).applyMatrix4(matrix);points.push([v.x,v.z])}}}
  for(const child of node.children)visit(child,matrix,inWheel,inTyre);
 }
 visit(root,identity);const hull=convexVehicleHull(points),xs=hull.map(p=>p[0]),zs=hull.map(p=>p[1]),min=[Math.min(...xs),Math.min(...zs)],max=[Math.max(...xs),Math.max(...zs)];
 return {collisionHull:hull,collisionHalfWidth:Math.max(Math.abs(min[0]),Math.abs(max[0])),collisionHalfLength:Math.max(Math.abs(min[1]),Math.abs(max[1])),collisionBounds:{min,max},collisionShapeSource:'closed-runtime-body-bumpers-tyres',collisionShapeDiagnostics:{vertices:hull.length,sourceVertices:points.length,meshes:meshNames,excluded,pose:'closed access panels, neutral wheels',padding:0}};
}
for(const p of [null,...profiles]){
 let car;if(!p)car=createDemoCar(T,RoundedBoxGeometry);else{const bytes=await readFile(new URL('./models/artist_vehicle_pack/'+p.modelFile,import.meta.url)),source=await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'');car=createArtistVehicle(T,RoundedBoxGeometry,source,p);if(p.taxi)decorateCityTaxi(T,RoundedBoxGeometry,car)}
 const id=p?.taxi?'city_taxi':p?.id||'red_demo',old={...CAR,...car.profile},scene=new T.Scene();scene.add(car.object);
 const hood=createVehicleHood(T,RoundedBoxGeometry,car,{scene}),trunk=createVehicleTrunk(T,RoundedBoxGeometry,car,{scene});
 const before=snapshot(car),originalProfile=JSON.stringify(car.profile),shape=buildVehicleCollisionShape(T,car);assert.deepEqual(shape,referenceCollisionShape(T,car),`${id}: optimized gather differs from exact reference`);assert.deepEqual(snapshot(car),before,`${id}: geometry/pose mutated`);assert.equal(JSON.stringify(car.profile),originalProfile,`${id}: shared profile mutated`);
 assert.ok(shape.collisionHull.length>=4&&shape.collisionHull.length<100);assert.ok(shape.collisionShapeDiagnostics.meshes.some(n=>/tyre|tire/i.test(n)),`${id}: no tyres`);
 assert.ok(!shape.collisionShapeDiagnostics.meshes.some(n=>/Mirror|DoorHandle|Lightbar|Ladder/i.test(n)),`${id}: decoration in solid hull`);
 for(const [x,z] of shape.collisionHull){assert.ok(Number.isFinite(x)&&Number.isFinite(z));assert.ok(Math.abs(x)<=shape.collisionHalfWidth+1e-9);assert.ok(Math.abs(z)<=shape.collisionHalfLength+1e-9)}
 car.object.position.set(17,3,-9);car.object.rotation.set(.1,.7,-.05);for(const door of car.doors.values())door.rotation.y=.92;
 if(hood.hinge)hood.hinge.rotation.x=-1.3;if(trunk.hinge)trunk.hinge.rotation.x=1.4;for(const w of car.wheels){w.pivot.rotation.y=.56;w.wheel.rotation.x=13;w.tire.scale.set(.42,1.1,.58)}
 const altered=snapshot(car),neutral=buildVehicleCollisionShape(T,car);assert.deepEqual(neutral,referenceCollisionShape(T,car),`${id}: altered optimized gather differs from exact reference`);assert.deepEqual(snapshot(car),altered,`${id}: runtime state mutated`);assert.deepEqual(neutral.collisionHull,shape.collisionHull,`${id}: transient pose changed closed footprint`);
 const merged={...old,...shape};assert.equal(merged.halfWidth,old.halfWidth);assert.equal(merged.halfLength,old.halfLength);
 const poly=collisionPolygon(0,0,0,shape),pad=collisionPolygon(0,0,0,{...shape,collisionPadding:.23});
 for(let i=0;i<poly.length;i++){const a=poly[i],b=poly[(i+1)%poly.length],len=Math.hypot(b[0]-a[0],b[1]-a[1]),nx=(b[1]-a[1])/len,nz=-(b[0]-a[0])/len;near(pad[i][0]*nx+pad[i][1]*nz-(a[0]*nx+a[1]*nz),.23)}
 const transformed=collisionPolygon(10,20,Math.PI/2,shape);poly.forEach((p,i)=>{near(transformed[i][0],10+p[1]);near(transformed[i][1],20-p[0])});
 assert.equal(collisionCircleOverlap({x:0,z:0,yaw:0},0,0,.2,shape),true);assert.equal(collisionCircleOverlap({x:0,z:0,yaw:0},shape.collisionHalfWidth+.31,0,.3,shape),false);
 const row={id,oldHalfWidth:old.halfWidth,oldHalfLength:old.halfLength,physicalHalfWidth:shape.collisionHalfWidth,physicalHalfLength:shape.collisionHalfLength,invisibleSideMargin:old.halfWidth-shape.collisionHalfWidth,invisibleEndMargin:old.halfLength-shape.collisionHalfLength,hullVertices:shape.collisionHull.length,bounds:shape.collisionBounds,hull:shape.collisionHull};rows.push(row);fixtures.set(id,{old,shape,car});console.log('PASS',id,JSON.stringify({...row,hull:undefined}));
}
if(process.env.MAFIOZY_COLLISION_BENCH){
 const cars=[...fixtures.values()].map(f=>f.car),rounds=8,samples=[];
 for(let i=0;i<3;i++)for(const car of cars)buildVehicleCollisionShape(T,car);
 for(let sample=0;sample<7;sample++){const start=performance.now();for(let round=0;round<rounds;round++)for(const car of cars)buildVehicleCollisionShape(T,car);samples.push(performance.now()-start)}
 samples.sort((a,b)=>a-b);console.log('BENCH collision-shape',JSON.stringify({cars:cars.length,builds:cars.length*rounds,msP50:samples[3],msP95:samples[6]}));
}
assert.deepEqual(collisionPolygon(0,0,0,{halfWidth:1,halfLength:2}),[[-1,-2],[1,-2],[1,2],[-1,2]]);
assert.deepEqual(collisionPolygon(0,0,0,{halfWidth:1,halfLength:2,collisionPadding:.5}),[[-1.5,-2.5],[1.5,-2.5],[1.5,2.5],[-1.5,2.5]]);
const red=fixtures.get('red_demo'),fire=fixtures.get('fire_engine'),gap=.04,spacing=red.shape.collisionBounds.max[0]-fire.shape.collisionBounds.min[0]+gap;
const oldContact=polygonVehicleContact(collisionPolygon(0,0,0,red.old),collisionPolygon(spacing,0,0,fire.old)),newContact=polygonVehicleContact(collisionPolygon(0,0,0,red.shape),collisionPolygon(spacing,0,0,fire.shape));
assert.ok(oldContact?.depth>.1,'Reproduction must expose old phantom overlap');assert.equal(newContact,null,'Visible 4 cm gap must remain traversable');
const a=red.shape.collisionHull.reduce((best,p)=>p[0]>best[0]?p:best),b=fire.shape.collisionHull.reduce((best,p)=>p[0]<best[0]?p:best),actualContact=polygonVehicleContact(collisionPolygon(0,0,0,red.shape),collisionPolygon(a[0]-b[0]-.02,a[1]-b[1],0,fire.shape));assert.ok(actualContact?.depth>0,'Real penetrating tyres/body must collide');
const pair={visibleGap:gap,centerSpacing:spacing,oldPhantomPenetration:oldContact.depth,newContact,realOverlapContactDepth:actualContact.depth};console.log('PASS red/fire pair',JSON.stringify(pair));
const out=new URL('../../../outputs/vehicle_fleet_continuation/',import.meta.url);await mkdir(out,{recursive:true});await writeFile(new URL('collision_shape_audit.json',out),JSON.stringify({vehicles:rows,pair,checks:'All 14 actual runtime cars; closed panel/steer/spin/deflation invariance; no state mutation; legacy dims; physical convex supports; explicit padding; real contact and phantom-gap reproduction'},null,2));console.log('PASS collision shape: 14 vehicles and red/fire contact regression');
