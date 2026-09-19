import assert from 'node:assert/strict';
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {vehicleOpaqueCoverHeight} from './hero_cover_contact.mjs';
import {createDemoCar,CAR} from './car_drive.mjs';
import {createArtistVehicle,ARTIST_VEHICLE_PROFILE_BY_ID} from './vehicle_fleet_models.mjs';
import {createVehicleRenderBatches} from './vehicle_render_batches.mjs';
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c);}});
const T=await import(pathToFileURL(vendor+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const {RoundedBoxGeometry}=await import('../../../tools/vehicle_fleet_qa/RoundedBoxGeometry.mjs');
const box=(w,h,d,x,y,z,material)=>{const mesh=new T.Mesh(new T.BoxGeometry(w,h,d),material);mesh.position.set(x,y,z);return mesh;};
const paint=new T.MeshBasicMaterial(),glass=new T.MeshBasicMaterial({transparent:true,opacity:.3}),fixture=new T.Group();
const body=box(2,.8,.16,0,.7,0,paint),window=box(2,1.1,.06,0,1.60,0,glass),roof=box(2,.10,1.8,0,2.15,.8,paint),seat=box(1,.8,.25,0,1.4,.45,paint);
fixture.add(body,window,roof,seat);
const input={position:{x:0,y:0,z:-.65},normal:{x:0,z:-1}},closed=vehicleOpaqueCoverHeight(T,fixture,input);
assert.ok(closed.height>.95&&closed.height<1.1,'window and roof cannot raise the opaque door band');
assert.equal(closed.fullWidth,true);
const edge=vehicleOpaqueCoverHeight(T,fixture,{...input,position:{...input.position,x:.86}});
assert.ok(edge.height>.95&&edge.height<1.1,'corner retains the actual central wall height');assert.equal(edge.fullWidth,false);assert.equal(edge.continuous,false);
body.visible=window.visible=false;assert.equal(vehicleOpaqueCoverHeight(T,fixture,input).height,0,'a seat beyond the open door is not the near body wall');
body.visible=window.visible=true;window.material=paint;
const solidCabin=vehicleOpaqueCoverHeight(T,fixture,input);assert.ok(solidCabin.height>2,'continuous opaque cabin wall can provide tall cover');window.material=glass;
const narrow=box(.08,.1,.2,0,1.2,0,paint);fixture.add(narrow);assert.ok(vehicleOpaqueCoverHeight(T,fixture,input).height<1.1,'narrow posts cannot shield the full head width');
window.material=new T.MeshPhysicalMaterial({transmission:1,transparent:false});
assert.ok(vehicleOpaqueCoverHeight(T,fixture,input).height<1.1,'transmissive glass is not opaque even without alpha blending');window.material=glass;
let cases=6;const results=[];
const cars=[{id:'kingswell',car:createDemoCar(T,RoundedBoxGeometry),profile:CAR}];
for(const id of ['compact_sedan','delivery_van']){const profile=ARTIST_VEHICLE_PROFILE_BY_ID[id],b=fs.readFileSync(new URL('./models/artist_vehicle_pack/'+profile.modelFile,import.meta.url));const gltf=await new GLTFLoader().parseAsync(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),'');const car=createArtistVehicle(T,RoundedBoxGeometry,gltf,profile);cars.push({id,car,profile:car.profile});}
for(const {id,car,profile}of cars){
  const door=car.doors.get('front_left')||car.doors.get(1);car.object.updateMatrixWorld(true);
  const center=new T.Box3().setFromObject(door).getCenter(new T.Vector3()),query={position:{x:profile.halfWidth+.37,y:0,z:center.z-.2},normal:{x:1,z:0},maxDistance:1.25};
  const before=vehicleOpaqueCoverHeight(T,car.object,query);
  assert.ok(before.height>.7&&before.height<1.5,id+' closed opaque panel, not roof: '+JSON.stringify({before,query}));
  const batches=createVehicleRenderBatches({THREE:T,root:car.object,includeBody:true,includeDoors:true});batches.update();
  const batched=vehicleOpaqueCoverHeight(T,car.object,query);assert.deepEqual(batched,before,id+' batching preserves protection height and width flags');
  car.setDoorById(1,'front_left');batches.update();const opened=vehicleOpaqueCoverHeight(T,car.object,query);
  assert.equal(opened.height,0,id+' open door cannot invent protection from cabin interior');
  car.setDoorById(0,'front_left');batches.update();
  const hood=vehicleOpaqueCoverHeight(T,car.object,{position:{x:0,y:0,z:profile.halfLength+.37},normal:{x:0,z:1},maxDistance:1.25});
  assert.ok(hood.height>.7&&hood.height<1.3,id+' front body provides hood-height protection');
  results.push({id,closed:before,opened,hood});cases+=4;
  if(id==='kingswell'){
    assert.ok(hood.height<.9,'height sampling must retain the narrow discontinuity below the hood');
    const corner=vehicleOpaqueCoverHeight(T,car.object,{...query,position:{...query.position,z:profile.halfLength-.14}});
    assert.ok(corner.height>.6,'Kingswell corner .14 retains its central body height: '+JSON.stringify(corner));
    assert.equal(corner.fullWidth,false,'Kingswell outer column crosses the real corner');assert.equal(corner.continuous,false);
    results.at(-1).corner=corner;cases++;
  }
  if(id==='delivery_van'){
    const cargo=vehicleOpaqueCoverHeight(T,car.object,{...query,position:{...query.position,z:-1}});
    assert.ok(cargo.height>1.8,'opaque cargo wall supplies tall cover without using cabin roof');results.at(-1).cargo=cargo;cases++;
  }
  const times=[];for(let i=0;i<25;i++){const start=performance.now();vehicleOpaqueCoverHeight(T,car.object,query);if(i>=5)times.push(performance.now()-start);}times.sort((a,b)=>a-b);results.at(-1).cpu={warmup:5,samples:20,p50Ms:times[10],p95Ms:times[19]};
  batches.dispose();
}
console.log(JSON.stringify({passed:true,cases,results,scope:'CPU query only; no GPU or shared-scene FPS'}));



