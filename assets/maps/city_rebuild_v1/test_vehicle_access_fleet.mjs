import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {createVehicleHood} from './vehicle_hood.mjs';
import {createVehicleTrunk} from './vehicle_trunk.mjs';
import {createVehicleDamage} from './vehicle_damage.mjs';
const vendor=process.env.MAFIOZY_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
const factoryURL=process.env.MAFIOZY_FLEET_FACTORY?pathToFileURL(process.env.MAFIOZY_FLEET_FACTORY):new URL('./vehicle_fleet_models.mjs',import.meta.url);
const {ARTIST_VEHICLE_PROFILES,createArtistVehicle}=await import(factoryURL);
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const T=await import(pathToFileURL(vendor+'build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
class Box extends T.BoxGeometry{constructor(w,h,d){super(w,h,d)}}
const state={x:0,y:0,z:0,yaw:0,speed:0};
const failures=[];
for(const definition of ARTIST_VEHICLE_PROFILES){
  const bytes=await readFile(new URL('./models/artist_vehicle_pack/'+definition.modelFile,import.meta.url)),source=await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'');
  const scene=new T.Scene(),car=createArtistVehicle(T,Box,source,definition);scene.add(car.object);
  const trunk=createVehicleTrunk(T,Box,car,{scene}),hood=createVehicleHood(T,Box,car,{scene});car.trunk=trunk;car.hood=hood;
  const damage=createVehicleDamage(T,car,{scene,trunk,getState:()=>state});
  try{
    assert(trunk.enabled&&hood.enabled,'both access controllers enabled: '+definition.id);assert(car.hoodSpec&&car.trunkSpec);
    const sign=hood.profile.front?1:-1,hoodHero={x:hood.profile.accessSide||0,y:0,z:hood.profile.accessZ+sign*.65},trunkHero={x:0,y:0,z:trunk.profile.rearZ-.65};
    const doorPose=[...car.doors].map(([id,node])=>[id,node.position.clone(),node.quaternion.clone()]);
    const context={hero:hoodHero,vehicleState:state,damage};assert(hood.interaction(hoodHero,state),'hood access: '+definition.id);assert(trunk.interaction(trunkHero,state),'trunk access: '+definition.id);
    if(!hood.profile.front){assert(trunk.interaction(trunkHero,state).near<hood.interaction(trunkHero,state).near,'rear cargo wins at centre');assert(hood.interaction(hoodHero,state).near<trunk.interaction(hoodHero,state).near,'rear engine hatch wins at its offset handle')}
    assert(hood.toggle(context).accepted);assert(trunk.toggle({hero:trunkHero,vehicleState:state}).accepted);
    for(let i=0;i<45;i++){hood.update(1/60,{vehicleState:state,crashState:damage.crash.state,damageState:damage.state});trunk.update(1/60,{vehicleState:state,damageState:damage.state})}
    assert.equal(hood.state.amount,1);assert.equal(trunk.state.amount,1);assert(hood.interaction(hoodHero,state).repairAvailable);
    car.object.updateWorldMatrix(true,true);const cover=hood.bay.getObjectByName('Engine_valve_cover'),target=cover.getWorldPosition(new T.Vector3()),from=target.clone();from.y=car.hoodSpec.engineBounds.max[1]+.06;
    const surfaces=[];car.object.traverse(mesh=>{if(!mesh.isMesh||mesh.material?.transparent)return;for(let n=mesh;n;n=n.parent)if(!n.visible)return;surfaces.push(mesh)});
    let visibleEngine=new T.Raycaster(from,new T.Vector3(0,-1,0),0,2).intersectObjects(surfaces,false)[0];
    assert(visibleEngine&&/Engine_valve_cover|Valve_cover_rib|Oil_filler_cap/.test(visibleEngine.object.name),'open hood must expose engine rather than solid hull: '+definition.id+' first '+visibleEngine?.object.name);
    if(hood.profile.front){
      // Standing at the front, looking down into the open bonnet. A low ray
      // fired through the grille would incorrectly reject the real front apron.
      const view=new T.Vector3(hood.profile.accessSide||0,Math.max(1.65,car.hoodSpec.engineBounds.max[1]+.40),hood.profile.accessZ+.40),hit=new T.Raycaster(view,target.clone().sub(view).normalize(),0,5).intersectObjects(surfaces,false)[0];
      if(process.env.MAFIOZY_SERVICE_DEBUG&&!/Engine_|Radiator_|Valve_cover|Oil_filler|Upper_radiator/.test(hit?.object.name||''))console.error(JSON.stringify({view,target,access:hood.profile,first:hit?.point}));
      assert(hit&&/Engine_|Radiator_|Valve_cover|Oil_filler|Upper_radiator/.test(hit.object.name),'standing front view exposes powertrain: '+definition.id+' first '+hit?.object.name);
    }
    for(const [id,position,q]of doorPose){assert(car.doors.get(id).position.equals(position));assert(car.doors.get(id).quaternion.equals(q))}
    assert.equal(car.seats.length,definition.seatCount);assert.equal(car.wheels.length,4);
    hood.bay.traverse(mesh=>{const a=mesh.geometry?.attributes?.position;if(a)for(const value of a.array)assert(Number.isFinite(value),'finite engine mesh '+definition.id+' '+mesh.name)});
    const mechanical=damage.crash.state;mechanical.engine=.2;mechanical.radiator=.1;mechanical.temperature=.9;hood.update(.1,{vehicleState:state,crashState:mechanical});assert(hood.stats().smokeParticles>0);
    const bodyHp=damage.state.hp,wheels=JSON.stringify(mechanical.wheels);assert(hood.repair(context).accepted);assert.equal(mechanical.engine,1);assert.equal(mechanical.radiator,1);assert.equal(damage.state.hp,bodyHp);assert.equal(JSON.stringify(mechanical.wheels),wheels);assert.equal(trunk.state.amount,1,'powertrain repair leaves trunk open');
    assert(damage.crash.detach('hood',{point:hood.interaction(hoodHero,state).anchor,normal:{x:0,y:0,z:sign},impactSpeed:20},state));hood.update(.1,{vehicleState:state,crashState:mechanical});assert(hood.state.detached);assert.equal(damage.crash.root.children.filter(n=>n.name==='Hood_lid').length,1);
    assert(hood.repair(context).accepted,'missing lid does not block engine access');
    assert(damage.crash.detach('trunk',{point:trunk.interaction(trunkHero,state).anchor,normal:{x:0,y:0,z:-1},impactSpeed:20},state));trunk.update(.1,{vehicleState:state});
    assert(trunk.state.detached&&!trunk.lid.visible);assert.equal(trunk.stats().debris+damage.crash.root.children.filter(n=>n.name==='Trunk_lid').length,1,'central crash delegates to the trunk pool without creating a second lid');
    damage.reset();assert(!hood.state.detached&&hood.lid.visible);assert(!trunk.state.detached&&trunk.lid.visible);assert.equal(trunk.state.amount,0);
    console.log('PASS '+definition.id+' hood '+(hood.profile.front?'front':'rear-service')+', '+trunk.profile.mode+', '+car.seats.length+' seats, smoke/repair/detach/reset');
  }catch(error){failures.push({id:definition.id,message:error.message,hoodEnabled:hood.enabled,trunkEnabled:trunk.enabled});console.error('FAIL '+definition.id+': '+error.message);if(process.env.MAFIOZY_SERVICE_DEBUG){const diagnostics={engineBounds:car.hoodSpec.engineBounds};for(const name of ['Engine_valve_cover','Gear_console','Front_apron']){const n=car.object.getObjectByName(name);if(n)diagnostics[name]=new T.Box3().setFromObject(n)}console.error(JSON.stringify(diagnostics))}}finally{damage.dispose();hood.dispose();trunk.dispose()}
}
assert.equal(failures.length,0,JSON.stringify(failures));
console.log('PASS all 12 authored vehicles: independent hood/trunk access, original seat doors, engine details, smoke, scoped repair and single world-space hood/trunk debris');
