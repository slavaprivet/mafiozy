import test from 'node:test';
import assert from 'node:assert/strict';
import {createVehicleImpactReaction,createVehicleOccupantImpactPose,VEHICLE_IMPACT_REACTION as R} from './vehicle_impact_reaction.mjs';

test('outward contact direction drives occupant inertia and braking body dip, weak taps remain small',()=>{
 const front=createVehicleImpactReaction();assert(front.impact({normal:{x:0,z:1},impactSpeed:18}));const s=front.update(.075);assert(s.local.z>0&&s.torso.pitch>0&&s.car.pitch>0);
 const side=createVehicleImpactReaction();side.impact({normal:{x:1,z:0},impactSpeed:18});const t=side.update(.075);assert(t.local.x>0&&t.torso.roll<0);
 const yaw=createVehicleImpactReaction();yaw.impact({normal:{x:1,z:0},impactSpeed:18},{yaw:Math.PI/2});assert(Math.abs(yaw.update(.075).local.z-s.local.z)<1e-12);
 const weak=createVehicleImpactReaction();weak.impact({normal:{x:0,z:1},impactSpeed:.5});assert(weak.update(.075).local.z<s.local.z*.02);
});
test('analytical damped spring agrees at 30/60/120/144 Hz, settles, resets and rejects nonfinite data',()=>{
 const results=[];for(const fps of [30,60,120,144]){const r=createVehicleImpactReaction();r.impact({normal:{x:1,z:1},impactSpeed:20});for(let i=0;i<fps;i++)r.update(1/fps);results.push(r.sample().local);r.update(10);assert.equal(r.sample().active,false);r.reset();assert.equal(r.sample().impacts,0)}
 for(const p of results){assert(Math.abs(p.x-results[0].x)<1e-10);assert(Math.abs(p.z-results[0].z)<1e-10)}
 const r=createVehicleImpactReaction();for(const normal of [{x:NaN,z:1},{x:0,z:0},{x:Infinity,z:0}])assert.equal(r.impact({normal,impactSpeed:20}),false);assert.equal(r.impact({normal:{x:1,z:0},impactSpeed:NaN}),false);assert.throws(()=>r.update(NaN));assert.throws(()=>r.update(-1));
});
test('event deduplication and sustained repeated crashes stay bounded without accumulating rest pose',()=>{
 const r=createVehicleImpactReaction();assert(r.impact({normal:{x:1,z:1},impactSpeed:18,eventId:'a'}));assert.equal(r.impact({normal:{x:1,z:1},impactSpeed:18,eventId:'a'}),false);
 for(let i=0;i<1200;i++){r.impact({normal:{x:Math.sin(i),z:Math.cos(i)},impactSpeed:1e20,eventId:i});const s=r.update(1/60);assert(Math.hypot(s.local.x,s.local.z)<=R.maxOffset+1e-10);assert([s.torso.pitch,s.head.roll,s.camera.y,s.car.pitch].every(Number.isFinite))}
 r.update(5);assert.equal(r.sample().active,false);
});

test('actual unchanged hero GLB: all 40 original/authored seats preserve palms, bone lengths, scales and cabin bounds under four impact directions',async()=>{
 const {readFile}=await import('node:fs/promises'),{pathToFileURL}=await import('node:url'),{registerHooks}=await import('node:module');
 const vendor=process.env.MAFIOZY_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
 registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
 const T=await import(pathToFileURL(vendor+'build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
 const {RoundedBoxGeometry}=await import('../../../tools/vehicle_fleet_qa/RoundedBoxGeometry.mjs'),{createArtistVehicle,ARTIST_VEHICLE_PROFILES}=await import('./vehicle_fleet_models.mjs'),{createDemoCar}=await import('./car_drive.mjs'),{VEHICLE_SEATS}=await import('./vehicle_seats.mjs'),{createHeroWalker}=await import('./hero_walk.mjs');
 const parse=async url=>{const b=await readFile(url);return(await new GLTFLoader().parseAsync(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),'')).scene};
 const hero=createHeroWalker({THREE:T,scene:await parse(new URL('./hero_models/player_male.8130dfb1f7eb.glb',import.meta.url))}),ctx=hero.artistContext(),adapter=createVehicleOccupantImpactPose(T),lengths=new Map(),scales=new Map();
 hero.object.traverse(n=>{scales.set(n,n.scale.clone());if(n.isBone&&n.parent.isBone)lengths.set(n,n.getWorldPosition(new T.Vector3()).distanceTo(n.parent.getWorldPosition(new T.Vector3())))});
 const fixtures=[{id:'red_demo',create:()=>createDemoCar(T,RoundedBoxGeometry)},...ARTIST_VEHICLE_PROFILES.map(p=>({id:p.id,create:async()=>createArtistVehicle(T,RoundedBoxGeometry,await parse(new URL('./models/artist_vehicle_pack/'+p.modelFile,import.meta.url)),p)}))];
 let seats=0,applied=0,attempts=0;const byCar=[],legacy=[],probeMs=[],cachedMs=[];
 const exactBounds=()=>{hero.object.updateMatrixWorld(true);hero.object.traverse(n=>{if(n.isSkinnedMesh)n.skeleton.update()});return new T.Box3().setFromObject(hero.object,true)};
 for(const f of fixtures){const car=await f.create();let active=0;
  for(const seat of car.seats||VEHICLE_SEATS){seats++;
   for(const normal of [{x:0,z:1},{x:0,z:-1},{x:1,z:0},{x:-1,z:0}]){
    hero.reset();hero.object.position.set(seat.anchor.side,seat.anchor.y,seat.anchor.front);hero.object.quaternion.copy(car.object.quaternion);car.object.updateMatrixWorld(true);
    if(car.poseOccupant)car.poseOccupant(hero,seat.id);else hero.vehiclePose(1,0,{driver:seat.canDrive,steeringGrips:car.getSteeringGrips()});
    if(f.id==='red_demo'&&seat.id==='front_left'&&normal.z===1){let top={y:-Infinity};const p=new T.Vector3();hero.object.traverse(mesh=>{if(!mesh.isMesh)return;if(mesh.isSkinnedMesh)mesh.skeleton.update();const a=mesh.geometry.attributes.position;for(let i=0;i<a.count;i++){p.fromBufferAttribute(a,i);if(mesh.isSkinnedMesh)mesh.applyBoneTransform(i,p);p.applyMatrix4(mesh.matrixWorld);if(p.y>top.y)top={mesh:mesh.name,x:p.x,y:p.y,z:p.z}}});const solids=[];car.object.traverse(m=>{if(m.isMesh&&!m.material?.transparent)solids.push(m)});const hit=new T.Raycaster(new T.Vector3(top.x,1.5,top.z),new T.Vector3(0,1,0),0,2).intersectObjects(solids,false)[0];assert(hit&&top.y<hit.point.y-.015,'red neutral hair below actual roof underside');assert(Math.abs(car.anchors.roofBottom-hit.point.y)<1e-6,'red roof metadata matches actual triangles');console.log(JSON.stringify({legacyNeutralTop:top,realRoofUnderside:hit?.point.toArray(),roofEnvelope:car.anchors.roofBottom,roofMesh:hit?.object.name}));}
    const hands=['l','r'].map(s=>ctx.bones['socket_hand_'+s].getWorldPosition(new T.Vector3())),neutral=new Map();for(const bone of Object.values(ctx.bones))neutral.set(bone,bone.matrix.clone());
    const neutralBounds=exactBounds(),limits=car.diagnostics?.().interiorVoid||{min:[-.775,.4,-1.62],max:[.775,car.anchors.roofBottom,.78]};
    const checkBounds=()=>{const occupied=exactBounds();for(const [axis,i]of [['x',0],['y',1],['z',2]]){assert(occupied.min[axis]>=Math.min(limits.min[i],neutralBounds.min[axis])-1e-6,`${f.id} ${seat.id} ${axis} lower cabin clearance`);assert(occupied.max[axis]<=Math.max(limits.max[i],neutralBounds.max[axis])+1e-6,`${f.id} ${seat.id} ${axis} upper cabin clearance`)}};
    const r=createVehicleImpactReaction();r.impact({normal,impactSpeed:18});const sample=r.update(.075),started=performance.now(),result=adapter.apply(hero,car,seat.id,sample);probeMs.push(performance.now()-started);attempts++;if(result.applied){applied++;active++}
    if(f.id==='red_demo')legacy.push({seat:seat.id,normal,...result});
    if(seat.canDrive)for(let i=0;i<2;i++)assert(ctx.bones['socket_hand_'+['l','r'][i]].getWorldPosition(new T.Vector3()).distanceTo(hands[i])<.0031,`${f.id} hand remains attached`);
    for(const [n,s]of scales)assert(n.scale.distanceTo(s)<1e-8,'no scale modification');for(const [b,len]of lengths)assert(Math.abs(b.getWorldPosition(new T.Vector3()).distanceTo(b.parent.getWorldPosition(new T.Vector3()))-len)<1e-5,`${f.id} ${b.name} length`);
    if(!result.applied)for(const [bone,matrix]of neutral)assert.deepEqual(bone.matrix.elements,matrix.elements,'rejected unsafe reaction restores neutral');
    checkBounds();for(const factor of [1,.5,.1]){for(const [bone,matrix]of neutral){bone.matrix.copy(matrix);bone.matrixWorldNeedsUpdate=true}hero.object.updateMatrixWorld(true);const smaller={...sample,torso:{pitch:sample.torso.pitch*factor,roll:sample.torso.roll*factor},head:{pitch:sample.head.pitch*factor,roll:sample.head.roll*factor}};const originalUpdate=hero.object.updateMatrixWorld;let poseWorldUpdates=0;hero.object.updateMatrixWorld=function(...args){poseWorldUpdates++;return originalUpdate.apply(this,args)};let cached,start;try{start=performance.now();cached=adapter.apply(hero,car,seat.id,smaller)}finally{hero.object.updateMatrixWorld=originalUpdate}cachedMs.push(performance.now()-start);assert(poseWorldUpdates<(seat.canDrive&&!cached.headOnly?9:2),'cached pose omits the pre-local-edit world traversal while retaining later IK flushes');assert(cached.cached);assert.equal(cached.applied,result.applied);checkBounds()}
   }
  }byCar.push({id:f.id,applied:active});assert(active>0,f.id+' has visible seated reaction');
 }
 assert.equal(seats,40);assert.equal(applied,attempts,'all original and authored seats respond safely in every tested direction');const mean=a=>a.reduce((s,v)=>s+v,0)/a.length;console.log(JSON.stringify({seats,attempts,applied,byCar,legacy,timing:{probeMeanMs:mean(probeMs),probeMaxMs:Math.max(...probeMs),cachedMeanMs:mean(cachedMs),cachedMaxMs:Math.max(...cachedMs)}}));assert(mean(cachedMs)<2,'cached per-frame pose below 2ms');
});

test('actual 13-car passengers keep the same certified impact pose through left, centre and right steering without another skin scan',async()=>{
 const {readFile}=await import('node:fs/promises'),{pathToFileURL}=await import('node:url'),{registerHooks}=await import('node:module');
 const vendor=process.env.MAFIOZY_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
 registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
 const T=await import(pathToFileURL(vendor+'build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
 const {RoundedBoxGeometry}=await import('../../../tools/vehicle_fleet_qa/RoundedBoxGeometry.mjs'),{createArtistVehicle,ARTIST_VEHICLE_PROFILES}=await import('./vehicle_fleet_models.mjs'),{createDemoCar}=await import('./car_drive.mjs'),{VEHICLE_SEATS}=await import('./vehicle_seats.mjs'),{createHeroWalker}=await import('./hero_walk.mjs');
 const parse=async url=>{const b=await readFile(url);return(await new GLTFLoader().parseAsync(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),'')).scene};
 const hero=createHeroWalker({THREE:T,scene:await parse(new URL('./hero_models/player_male.8130dfb1f7eb.glb',import.meta.url))}),ctx=hero.artistContext(),adapter=createVehicleOccupantImpactPose(T),originalScales=new Map(),originalLengths=new Map();
 hero.object.traverse(node=>{originalScales.set(node,node.scale.clone());if(node.isBone&&node.parent.isBone)originalLengths.set(node,node.getWorldPosition(new T.Vector3()).distanceTo(node.parent.getWorldPosition(new T.Vector3())))});
 const fixtures=[{id:'red_demo',create:()=>createDemoCar(T,RoundedBoxGeometry)},...ARTIST_VEHICLE_PROFILES.map(profile=>({id:profile.id,create:async()=>createArtistVehicle(T,RoundedBoxGeometry,await parse(new URL('./models/artist_vehicle_pack/'+profile.modelFile,import.meta.url)),profile)}))];
 const originalApplyBoneTransform=T.SkinnedMesh.prototype.applyBoneTransform;let skinnedVertexTransforms=0;
 T.SkinnedMesh.prototype.applyBoneTransform=function(...args){skinnedVertexTransforms++;return originalApplyBoneTransform.apply(this,args)};
 const sampleFor=normal=>{const reaction=createVehicleImpactReaction();reaction.impact({normal,impactSpeed:18});return reaction.update(.075)};
 const poseAt=(car,seat,steer)=>{car.interior?.update?.({steer});hero.reset();hero.object.position.set(seat.anchor.side,seat.anchor.y,seat.anchor.front);hero.object.quaternion.copy(car.object.quaternion);car.object.updateMatrixWorld(true);if(car.poseOccupant)car.poseOccupant(hero,seat.id,{steer,dt:0});else hero.vehiclePose(1,0,{driver:seat.canDrive,steeringGrips:car.getSteeringGrips(),steer,dt:0});};
 const snapshot=()=>{hero.object.updateMatrixWorld(true);hero.object.traverse(node=>{if(node.isSkinnedMesh)node.skeleton.update()});return {bounds:new T.Box3().setFromObject(hero.object,true),hands:['l','r'].map(side=>ctx.bones['socket_hand_'+side].getWorldPosition(new T.Vector3())),bones:Object.fromEntries(Object.entries(ctx.bones).map(([name,bone])=>[name,bone.matrix.elements.slice()]))};};
 const close=(a,b,message)=>assert(Math.abs(a-b)<1e-7,message);
 const compareSnapshots=(fresh,cached,label)=>{for(const axis of ['x','y','z']){close(fresh.bounds.min[axis],cached.bounds.min[axis],label+' bound min '+axis);close(fresh.bounds.max[axis],cached.bounds.max[axis],label+' bound max '+axis)}for(let i=0;i<2;i++)assert(fresh.hands[i].distanceTo(cached.hands[i])<1e-7,label+' palm '+i);for(const [name,values]of Object.entries(fresh.bones))assert.deepEqual(cached.bones[name],values,label+' bone '+name);};
 const assertCabin=(car,neutral,label)=>{const limits=car.diagnostics?.().interiorVoid||{min:[-.775,.4,-1.62],max:[.775,car.anchors.roofBottom,.78]},actual=snapshot();for(const [axis,index]of [['x',0],['y',1],['z',2]]){assert(actual.bounds.min[axis]>=Math.min(limits.min[index],neutral.bounds.min[axis])-1e-6,label+' cabin lower '+axis);assert(actual.bounds.max[axis]<=Math.max(limits.max[index],neutral.bounds.max[axis])+1e-6,label+' cabin upper '+axis)}return actual;};
 let passengers=0,cachedRecertifications=0,coldVertexTransforms=0;
 try{
  for(const fixture of fixtures){const car=await fixture.create();for(const seat of car.seats||VEHICLE_SEATS){if(seat.canDrive)continue;passengers++;
   for(const normal of [{x:0,z:1},{x:0,z:-1},{x:1,z:0},{x:-1,z:0}]){const reaction=sampleFor(normal);
    poseAt(car,seat,-.56);const seedBefore=skinnedVertexTransforms,seed=adapter.apply(hero,car,seat.id,reaction),seedTransforms=skinnedVertexTransforms-seedBefore;coldVertexTransforms+=seedTransforms;assert(seed.applied&&!seed.cached,fixture.id+' '+seat.id+' left lock cold certificate');
    for(const steer of [0,.56]){poseAt(car,seat,steer);const neutral=snapshot(),freshAdapter=createVehicleOccupantImpactPose(T),fresh=freshAdapter.apply(hero,car,seat.id,reaction);assert(fresh.applied&&!fresh.cached,fixture.id+' '+seat.id+' fresh reference');const freshPose=assertCabin(car,neutral,fixture.id+' '+seat.id+' fresh '+steer);
     poseAt(car,seat,steer);const cachedBefore=skinnedVertexTransforms,cached=adapter.apply(hero,car,seat.id,reaction),cachedTransforms=skinnedVertexTransforms-cachedBefore;assert(cached.applied&&cached.cached,fixture.id+' '+seat.id+' reused passenger certificate at '+steer);assert.equal(cachedTransforms,0,fixture.id+' '+seat.id+' reused pose has no skinned-vertex certification');assert.equal(cached.gain,fresh.gain,fixture.id+' '+seat.id+' exact gain');assert.equal(cached.headOnly,fresh.headOnly,fixture.id+' '+seat.id+' exact torso/head mode');const cachedPose=assertCabin(car,neutral,fixture.id+' '+seat.id+' cached '+steer);compareSnapshots(freshPose,cachedPose,fixture.id+' '+seat.id+' '+steer);cachedRecertifications++;
    }
    for(const [node,scale]of originalScales)assert(node.scale.distanceTo(scale)<1e-8,'no scale modification');for(const [bone,length]of originalLengths)assert(Math.abs(bone.getWorldPosition(new T.Vector3()).distanceTo(bone.parent.getWorldPosition(new T.Vector3()))-length)<1e-5,'bone length');
   }
  }}
 }finally{T.SkinnedMesh.prototype.applyBoneTransform=originalApplyBoneTransform}
 assert.equal(passengers,27);assert.equal(cachedRecertifications,27*4*2);assert(coldVertexTransforms>0);console.log(JSON.stringify({passengers,cachedRecertifications,coldVertexTransforms,certificate:'passenger steering does not add a skinned-vertex certification'}));
});
