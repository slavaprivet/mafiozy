#!/usr/bin/env node
// Executed-source oracle for the private vehicle_damage copyPart/detachParts event.
// Production modules are SHA/sentinel pinned and instrumented only in memory.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {registerHooks} from 'node:module';
import {fileURLToPath, pathToFileURL} from 'node:url';

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const vendor = process.env.MAFIOZI_THREE_VENDOR ?? 'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const target = path.join(repo, 'godot/mafiozi_walk/data/transport/source_debris_copy_event.json');
const step1Path = path.join(repo, 'godot/mafiozi_walk/data/transport/source_burn_identities.json');
const damagePath = path.join(repo, 'assets/maps/city_rebuild_v1/vehicle_damage.mjs');
const batchesPath = path.join(repo, 'assets/maps/city_rebuild_v1/vehicle_render_batches.mjs');
const damageUrl = pathToFileURL(damagePath).href;
const batchesUrl = pathToFileURL(batchesPath).href;
const expectedDamageSha = 'e029cb4a03dcd23bbdd0fb2f73b7780db92f24f761cf83b030991acb3c403f92';
const expectedBatchesSha = 'a9b4c0c93652b52e29a2c29fe65748bdf451122594583d3bd455238f766df648';
const expectedStep1Sha = '38d370792b7e97445b56efb35b4360121157a659905216db79221f78f22c2d38';
const extraPins = new Map([
  ['assets/maps/city_rebuild_v1/vehicle_fleet.mjs', '7fd414ed74da713da06ee6ea436828e3ace825edc1aa97aa33c57dee28e1e4a8'],
  ['assets/maps/city_rebuild_v1/car_drive.mjs', 'a25cb6c140cd770f387f3f9004672d3dcd1aa224f0ba17d2d778c0ae7a7258eb'],
  ['assets/maps/city_rebuild_v1/vehicle_collision_shape.mjs', '97c3fb895450937da0e0ec3c818036b3f066db4803b1877c6969acfd90cd166f'],
  ['assets/maps/city_rebuild_v1/vehicle_contact.mjs', '668e776961d474e6a2bceb62f6435027b859f926b819c0f77da5f4bb0afd4020'],
  ['assets/maps/city_rebuild_v1/vehicle_contact_motion.mjs', 'aa787eb0fef14df3e9324b797c263195e4cf943b594f7d0b3c1a1569164f63ff'],
  ['assets/maps/city_rebuild_v1/vehicle_dynamics.mjs', '105cce8bf2cac63136e1c5e48f38465c4bf8e448a271702136b7c014e3396faf'],
  ['assets/maps/city_rebuild_v1/vehicle_impact_reaction.mjs', '9b6acc01dc508c7c9e4b78310234a18ae50fd67c0f877c1b4058352217889bb5'],
  ['assets/maps/city_rebuild_v1/vehicle_interiors.mjs', '060f3a36b7ca4d75d872f957f5501f27f150817937d399b422de72d85ecd3a35'],
  ['assets/maps/city_rebuild_v1/vehicle_occupant_crash_pulse_event.mjs', '755fde5d4cad9e90bba1f108b2e96aa2cef785c71c9886ac707e78af6b632edd'],
  ['assets/maps/city_rebuild_v1/vehicle_occupant_impact_adapter.mjs', '2e00ab3ac5c46ca6b43cc566ee3c0c00a9dfea12c384106e239d8f2ea2aa46f6'],
  ['assets/maps/city_rebuild_v1/vehicle_occupant_impact_fleet_seam.mjs', '16fe6a6504393031b9e6c515fc9b985e365c946438663ac65079e5a496516643'],
  ['assets/maps/city_rebuild_v1/vehicle_pair_impulse.mjs', '544a6a3c0d3b406ada6f60d38084e3e9ace488e12e7b404e2d9ea75bbb2abbe1'],
  ['assets/maps/city_rebuild_v1/vehicle_water_state.mjs', 'e046695e2f6cd2da372c48fcd23af4f83f9c4070749a9b9ad2f5504051967769'],
  ['assets/maps/city_rebuild_v1/vehicle_wheel_render_batches.mjs', 'dd295cd05d25ece2c68075286b12ee86f1e69f2c947b43771caf8b04fba3229e'],
  ['assets/maps/city_rebuild_v1/vehicle_rollover.mjs', '21650742ccef39b229917e92986f0a57e91e2b4d77a9ad586839ffb5c50f76d8'],
  ['assets/maps/city_rebuild_v1/tyre_damage.mjs', '5fb71f8ad6efd84f4a9e998c93a3a112e7874fd4a18448370378c0acd78762af'],
]);
const probeSymbol = Symbol.for('mafiozi.transport.debris.copy.event.oracle');
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const relative = value => path.relative(repo, value).replaceAll('\\', '/');
const dependencies = new Set([fileURLToPath(import.meta.url)]);
const readPinned = (file, sha, label) => {const bytes = fs.readFileSync(file); assert.equal(hash(bytes), sha, label + ' changed'); return bytes;};

const damageBytes = readPinned(damagePath, expectedDamageSha, 'vehicle_damage.mjs');
let damageSource = damageBytes.toString('utf8').replaceAll('\r\n','\n');
const copySentinel = ` function copyPart(source){
  if(!source.visible||source===object||marks.includes(source)||source.isLine||source.material?.transparent||source.userData.vehicleRenderBatch)return null;
  const material=getVehicleRenderSourceMaterial(source);
  const node=source.isMesh?new T.Mesh(source.geometry.clone(),Array.isArray(material)?material.map(m=>m.clone()):material.clone()):new T.Group();
  node.name=source.name;node.position.copy(source.position);node.quaternion.copy(source.quaternion);node.scale.copy(source.scale);node.castShadow=true;node.raycast=()=>{};
  for(const child of source.children){const copy=copyPart(child);if(copy)node.add(copy)}return node;
 }`;
const copyInstrumented = ` function copyPart(source){
  const __probe=globalThis[Symbol.for('mafiozi.transport.debris.copy.event.oracle')];__probe?.({kind:'copy_visit',source});
  if(!source.visible){__probe?.({kind:'copy_reject',source,reason:'invisible'});return null;}
  if(source===object){__probe?.({kind:'copy_reject',source,reason:'damage_effects'});return null;}
  if(marks.includes(source)){__probe?.({kind:'copy_reject',source,reason:'mark'});return null;}
  if(source.isLine){__probe?.({kind:'copy_reject',source,reason:'line'});return null;}
  if(source.material?.transparent){__probe?.({kind:'copy_reject',source,reason:'transparent'});return null;}
  if(source.userData.vehicleRenderBatch){__probe?.({kind:'copy_reject',source,reason:'render_batch'});return null;}
  const material=getVehicleRenderSourceMaterial(source);__probe?.({kind:'copy_getter',source,current:source.material,material});
  const node=source.isMesh?new T.Mesh(source.geometry.clone(),Array.isArray(material)?material.map(m=>m.clone()):material.clone()):new T.Group();
  node.name=source.name;node.position.copy(source.position);node.quaternion.copy(source.quaternion);node.scale.copy(source.scale);node.castShadow=true;node.raycast=()=>{};
  for(const child of source.children){const copy=copyPart(child);if(copy)node.add(copy)}__probe?.({kind:'copy_accept',source,node,material});return node;
 }`;
assert.equal(damageSource.split(copySentinel).length, 2, 'copyPart sentinel must occur once');
damageSource = damageSource.replace(copySentinel, copyInstrumented);
const sourcesSentinel = `  const sources=[...car.doors.values(),...(car.shell||[]).filter(m=>['Hood_lid','Trunk_lid'].includes(m.name)),...car.wheels.map(w=>w.pivot)];
  for(const [i,source]of sources.slice(0,10).entries()){
   const mesh=copyPart(source);if(!mesh)continue;`;
const sourcesInstrumented = `  const sources=[...car.doors.values(),...(car.shell||[]).filter(m=>['Hood_lid','Trunk_lid'].includes(m.name)),...car.wheels.map(w=>w.pivot)];
  const __probe=globalThis[Symbol.for('mafiozi.transport.debris.copy.event.oracle')];let __oracleRoot=-1;const __oracleRandom=()=>__probe?.({kind:'random_draw',index:__oracleRoot})??globalThis['Math'].random();__probe?.({kind:'detach_roots',sources:sources.slice(0,10)});
  for(const [i,source]of sources.slice(0,10).entries()){
   __oracleRoot=i;__probe?.({kind:'detach_root_begin',index:i,source});const mesh=copyPart(source);if(!mesh){__probe?.({kind:'detach_root_reject',index:i,source});continue;}`;
assert.equal(damageSource.split(sourcesSentinel).length, 2, 'detach roots sentinel must occur once');
damageSource = damageSource.replace(sourcesSentinel, sourcesInstrumented);
const hideSentinel = `   debrisObject.add(mesh);visibilityRest.set(source,source.visible);source.visible=false;`;
const hideInstrumented = `   debrisObject.add(mesh);visibilityRest.set(source,source.visible);source.visible=false;__probe?.({kind:'source_hidden',index:i,source,mesh});`;
assert.equal(damageSource.split(hideSentinel).length, 2, 'hide sentinel must occur once');
damageSource = damageSource.replace(hideSentinel, hideInstrumented);
const pushSentinel = `   debris.push({mesh,start,quaternion:mesh.quaternion.clone(),landing:landing.clone(),born:time,velocity:velocity.clone(),spin:new T.Vector3((Math.random()-.5)*6,(Math.random()-.5)*6,(Math.random()-.5)*6)});
  }
 }`;
const pushInstrumented = `   debris.push({mesh,start,quaternion:mesh.quaternion.clone(),landing:landing.clone(),born:time,velocity:velocity.clone(),spin:new T.Vector3((Math.random()-.5)*6,(Math.random()-.5)*6,(Math.random()-.5)*6)});__probe?.({kind:'detach_root_complete',index:i,source,mesh});
  }
  __probe?.({kind:'detach_complete'});
 }`;
assert.equal(damageSource.split(pushSentinel).length, 2, 'detach push sentinel must occur once');
damageSource = damageSource.replace(pushSentinel, pushInstrumented);
const stateSentinel=`motion=getState()||{},speed=Math.max(-35,Math.min(35,Number(motion.speed)||0))`;
const stateInstrumented=`motion=getState()||{};__probe?.({kind:'get_state',index:i,motion});const speed=Math.max(-35,Math.min(35,Number(motion.speed)||0))`;
assert.equal(damageSource.split(stateSentinel).length,2,'detach getState sentinel must occur once');
damageSource=damageSource.replace(stateSentinel,stateInstrumented);
{
  const start=damageSource.indexOf(' function detachParts(){'),end=damageSource.indexOf(' // The explosion releases several real assemblies',start);
  assert(start>=0&&end>start,'detachParts range missing');const before=damageSource.slice(start,end);assert.equal(before.split('Math.random()').length-1,7,'detachParts RNG call count changed');
  damageSource=damageSource.slice(0,start)+before.replaceAll('Math.random()','__oracleRandom()')+damageSource.slice(end);
}
const explosionSentinel = `  if(state.explosions>prior){for(const material of materialRest.keys())if(material.color&&!material.transparent){material.color.lerp(new T.Color('#100f0e'),.94);material.roughness=.99}onExplosion({vehicle:car,state,point:car.object.getWorldPosition(new T.Vector3())});for(const pane of glass)pane.visible=false;detachParts()}`;
const explosionInstrumented = `  if(state.explosions>prior){for(const material of materialRest.keys())if(material.color&&!material.transparent){material.color.lerp(new T.Color('#100f0e'),.94);material.roughness=.99}const __probe=globalThis[Symbol.for('mafiozi.transport.debris.copy.event.oracle')];__probe?.({kind:'after_char'});onExplosion({vehicle:car,state,point:car.object.getWorldPosition(new T.Vector3())});__probe?.({kind:'after_callback'});for(const pane of glass)pane.visible=false;__probe?.({kind:'after_glass'});detachParts();__probe?.({kind:'after_detach'})}`;
assert.equal(damageSource.split(explosionSentinel).length, 2, 'explosion sentinel must occur once');
damageSource = damageSource.replace(explosionSentinel, explosionInstrumented);

const batchesBytes = readPinned(batchesPath, expectedBatchesSha, 'vehicle_render_batches.mjs');
let batchesSource = batchesBytes.toString('utf8').replaceAll('\r\n','\n');
const getterSentinel = `export function getVehicleRenderSourceMaterial(mesh){const saved=sourceMaterials.get(mesh);return saved&&mesh.material===saved.hidden?saved.material:mesh.material;}`;
const getterInstrumented = `export function getVehicleRenderSourceMaterial(mesh){const saved=sourceMaterials.get(mesh),result=saved&&mesh.material===saved.hidden?saved.material:mesh.material;globalThis[Symbol.for('mafiozi.transport.debris.copy.event.oracle')]?.({kind:'batch_getter',source:mesh,current:mesh.material,result,registered:!!saved,hidden:saved?.hidden??null,canonical:saved?.material??null});return result;}`;
assert.equal(batchesSource.split(getterSentinel).length, 2, 'batch getter sentinel must occur once');
batchesSource = batchesSource.replace(getterSentinel, getterInstrumented);
batchesSource += `\nexport function __transportDebrisCopyRegistration(mesh){const saved=sourceMaterials.get(mesh);return saved?Object.freeze({hidden:saved.hidden,material:saved.material}):null;}\n`;

registerHooks({
  resolve(specifier, context, next) {return next(specifier === 'three' ? pathToFileURL(path.join(vendor, 'build/three.module.js')).href : specifier, context);},
  load(url, context, next) {
    if (url.startsWith('file:')) dependencies.add(fileURLToPath(url));
    if (url === damageUrl) return {format: 'module', source: damageSource, shortCircuit: true};
    if (url === batchesUrl) return {format: 'module', source: batchesSource, shortCircuit: true};
    return next(url, context);
  },
});

const T = await import('three'); assert.equal(T.REVISION, '180');
const {GLTFLoader} = await import(pathToFileURL(path.join(vendor, 'addons/loaders/GLTFLoader.js')));
const {RoundedBoxGeometry} = await import('../vehicle_fleet_qa/RoundedBoxGeometry.mjs');
const {ARTIST_VEHICLE_PROFILES, createArtistVehicle} = await import('../../assets/maps/city_rebuild_v1/vehicle_fleet_models.mjs');
const {createVehicleHood} = await import('../../assets/maps/city_rebuild_v1/vehicle_hood.mjs');
const {createVehicleTrunk} = await import('../../assets/maps/city_rebuild_v1/vehicle_trunk.mjs');
const {decorateCityTaxi} = await import('../../assets/maps/city_rebuild_v1/vehicle_taxi.mjs');
const {createVehicleFleet} = await import('../../assets/maps/city_rebuild_v1/vehicle_fleet.mjs');
const {__transportDebrisCopyRegistration} = await import('../../assets/maps/city_rebuild_v1/vehicle_render_batches.mjs');

const step1Bytes = readPinned(step1Path, expectedStep1Sha, 'source_burn_identities.json');
const step1 = JSON.parse(step1Bytes); assert.equal(step1.schema, 'mafiozi.transport-burn-source-identities.v1');
const stepById = new Map(step1.profiles.map(row => [row.profile_id, row]));
const sourcePins = new Map(step1.source_files.map(row => [row.path, row.sha256]));
for (const [p, sha] of extraPins) sourcePins.set(p, sha);
const sedan = ARTIST_VEHICLE_PROFILES.find(profile => profile.id === 'compact_sedan'); assert(sedan);
const profiles = [...ARTIST_VEHICLE_PROFILES, {...sedan, id: 'city_taxi', source_profile_id: 'compact_sedan', wheelDesignId: 'city_taxi'}];
const f64 = values => {const a = new Float64Array(values); return {count:a.length, f64le_sha256:hash(Buffer.from(a.buffer, a.byteOffset, a.byteLength))};};
const typedDigest = attribute => attribute ? {count:attribute.count, item_size:attribute.itemSize, normalized:!!attribute.normalized,
  array_type:attribute.array?.constructor?.name??null, bytes_sha256:attribute.array ? hash(Buffer.from(attribute.array.buffer, attribute.array.byteOffset, attribute.array.byteLength)) : null} : null;
const geometryDigest = geometry => geometry ? {attributes:Object.fromEntries(Object.keys(geometry.attributes??{}).sort().map(name=>[name,typedDigest(geometry.attributes[name])])), index:typedDigest(geometry.index),
  groups:(geometry.groups??[]).map(g=>[g.start,g.count,g.materialIndex]),
  draw_range:[geometry.drawRange?.start??0, Number.isFinite(geometry.drawRange?.count)?geometry.drawRange.count:'Infinity']} : null;

function runCase(profile, kind) {
  const step = stepById.get(profile.id); assert(step, 'missing step1 ' + profile.id);
  const inputPath = path.join(repo, 'assets/maps/city_rebuild_v1/models/artist_vehicle_pack', profile.modelFile);
  const input = fs.readFileSync(inputPath); assert.equal(hash(input), profile.sha256); dependencies.add(inputPath);
  return new GLTFLoader().parseAsync(input.buffer.slice(input.byteOffset, input.byteOffset + input.byteLength), '').then(source => {
    const car = profile.id === 'city_taxi'
      ? decorateCityTaxi(T, RoundedBoxGeometry, createArtistVehicle(T, RoundedBoxGeometry, source.scene, {...sedan, wheelDesignId:'city_taxi'}))
      : createArtistVehicle(T, RoundedBoxGeometry, source.scene, profile);
    const scene = new T.Scene(); scene.add(car.object);
    const trunk=createVehicleTrunk(T,RoundedBoxGeometry,car,{scene,groundHeight:()=>0});car.trunk=trunk;
    const hood=createVehicleHood(T,RoundedBoxGeometry,car,{scene,groundHeight:()=>0});car.hood=hood;
    const wrapper = new T.Group(); wrapper.name='VehicleVisual'; wrapper.rotation.y=Math.PI; wrapper.add(car.object); wrapper.updateMatrixWorld(true);
    const keyOf = new Map(), materialIds = new Map(); let nodeIndex=0;
    wrapper.traverse(node=>{keyOf.set(node,'v'+(nodeIndex++).toString().padStart(4,'0')); if(node.isMesh)for(const material of Array.isArray(node.material)?node.material:[node.material])if(material&&!materialIds.has(material))materialIds.set(material,'m'+materialIds.size.toString().padStart(4,'0'));});
    assert.equal(nodeIndex, step.factory_receipt.node_count);
    wrapper.remove(car.object); scene.add(car.object); car.object.updateMatrixWorld(true);
    const auxiliaryKey = new Map(); let auxIndex=0;
    const nodeKey = node => keyOf.get(node) ?? (auxiliaryKey.has(node)?auxiliaryKey.get(node):(auxiliaryKey.set(node,'x'+(auxIndex++).toString().padStart(4,'0')),auxiliaryKey.get(node)));
    const extraMaterials = new Map();
    const materialKey = material => materialIds.get(material) ?? (extraMaterials.has(material)?extraMaterials.get(material):(extraMaterials.set(material,'xmat'+extraMaterials.size.toString().padStart(4,'0')),extraMaterials.get(material)));
    const containerKeys = value => (Array.isArray(value)?value:[value]).filter(Boolean).map(materialKey);
    const preOpaque=new Map([...materialIds].filter(([material])=>material.color&&!material.transparent).map(([material,id])=>[material,{id,color:material.color.toArray(),roughness:material.roughness}]));
    const events=[]; let seq=0, randomCursor=0;
    const randomValues=[.11,.23,.37,.41,.53,.67,.79,.83,.17,.29,.31,.43,.47,.59,.61,.71,.73,.89,.97,.07];
    const record=(kind,payload={})=>events.push({seq:seq++,kind,...payload});
    globalThis[probeSymbol] = event => {
      if(event.kind==='random_draw'){const value=randomValues[randomCursor%randomValues.length];record('random',{index:event.index,cursor:randomCursor,value});randomCursor++;return value;}
      if(event.kind==='get_state')return record('get_state',{index:event.index,speed:event.motion.speed??null,yaw:event.motion.yaw??null,travel_yaw:event.motion.travelYaw??null});
      if(event.kind==='detach_roots')return record(event.kind,{roots:event.sources.map(nodeKey)});
      if(event.kind==='detach_root_begin'||event.kind==='detach_root_reject')return record(event.kind,{index:event.index,source:nodeKey(event.source)});
      if(event.kind==='source_hidden'||event.kind==='detach_root_complete')return record(event.kind,{index:event.index,source:nodeKey(event.source),copy:nodeKey(event.mesh)});
      if(event.kind==='copy_visit')return record(event.kind,{source:nodeKey(event.source)});
      if(event.kind==='copy_reject')return record(event.kind,{source:nodeKey(event.source),reason:event.reason});
      if(event.kind==='copy_getter')return record(event.kind,{source:nodeKey(event.source),current:containerKeys(event.current),canonical:containerKeys(event.material)});
      if(event.kind==='copy_accept')return record(event.kind,{source:nodeKey(event.source),copy:nodeKey(event.node),geometry:geometryDigest(event.node.geometry),materials:containerKeys(event.node.material),children:event.node.children.map(nodeKey)});
      if(event.kind==='batch_getter')return record(event.kind,{source:nodeKey(event.source),registered:event.registered,current:containerKeys(event.current),result:containerKeys(event.result),
        hidden:event.hidden?containerKeys(event.hidden):[],canonical:event.canonical?containerKeys(event.canonical):[]});
      record(event.kind);
    };
    let callbackCount=0,batches=null,fleet=null,fleetRecord=null;
    const onExplosion=()=>{
      callbackCount++; record('callback_enter',{case:kind});
      if(kind==='mutation'){
        const first=[...car.doors.values()][0]; assert(first);
        const mesh=first.children.find(n=>n.isMesh&&!n.material?.transparent)??first.children.find(n=>n.isMesh); assert(mesh);
        mesh.visible=true;
        const old=Array.isArray(mesh.material)?mesh.material[0]:mesh.material;
        const replacement=old.clone(); replacement.name='Oracle_callback_replacement'; replacement.color?.setRGB(.13,.27,.49);
        mesh.material=Array.isArray(mesh.material)?mesh.material.map((m,i)=>i?m:replacement):replacement;
        record('callback_mutation',{source:nodeKey(mesh),old_material:materialKey(old),replacement_material:materialKey(replacement)});
      }
      if(kind==='detail_disabled'){
        assert(batches);batches.setDetailOptimizationEnabled(false);record('callback_detail_disabled');
      }
      if(kind==='hidden_fallback'){
        assert(batches);let selected=null,registration=null;
        for(const door of car.doors.values())door.traverse(node=>{if(selected||!node.isMesh)return;const found=__transportDebrisCopyRegistration(node);if(found){selected=node;registration=found;}});
        assert(selected&&registration);registration.hidden.opacity=.731;batches.update();
        assert.equal(__transportDebrisCopyRegistration(selected),null);record('callback_hidden_fallback',{source:nodeKey(selected),hidden_material:materialKey(registration.hidden),canonical_material:materialKey(registration.material)});
      }
      if(kind==='hidden_root'){
        const first=[...car.doors.values()][0];assert(first);first.visible=false;record('callback_hidden_root',{source:nodeKey(first),original_index:0});
      }
      if(kind==='throw')throw new Error('ORACLE_CALLBACK_THROW');
      record('callback_return',{case:kind});
    };
    fleet=createVehicleFleet(T,{scene,RoundedBox:RoundedBoxGeometry,world:()=>()=>true,groundHeight:()=>0,onExplosion,detailOptimization:true,wheelRenderOptimization:false});
    fleetRecord=fleet.addCar(car);batches=fleetRecord.renderBatches;
    let thrown=null;
    try {assert.equal(fleetRecord.damage.impact({object:{},point:car.object.getWorldPosition(new T.Vector3()),damage:999,explosive:true,eventId:'oracle-'+profile.id+'-'+kind}),true); fleetRecord.damage.update(0);}
    catch(error){thrown=String(error?.message??error); record('outer_catch',{message:thrown});}
    finally {delete globalThis[probeSymbol];}
    const charred=[...preOpaque].map(([material,before])=>({id:before.id,before:{color:before.color,roughness:before.roughness},after:{color:material.color.toArray(),roughness:material.roughness},changed:material.color.toArray().some((v,i)=>v!==before.color[i])||material.roughness!==before.roughness}));
    const copied=[]; fleetRecord.damage.debrisObject.traverse(node=>{if(node!==fleetRecord.damage.debrisObject)copied.push({key:nodeKey(node),name:node.name,type:node.type,parent:nodeKey(node.parent),visible:node.visible,
      local_matrix:f64(node.matrix.toArray()),geometry:geometryDigest(node.geometry),materials:node.isMesh?containerKeys(node.material):[]});});
    const accepted=events.filter(e=>e.kind==='detach_root_complete').length;
    const result={profile_id:profile.id,source_profile_id:profile.source_profile_id??profile.id,case:kind,callback_count:callbackCount,thrown,
      event_count:events.length,events,summary:{roots:events.find(e=>e.kind==='detach_roots')?.roots??[],accepted,rejected:events.filter(e=>e.kind==='detach_root_reject').length,
        copy_visits:events.filter(e=>e.kind==='copy_visit').length,batch_getter_calls:events.filter(e=>e.kind==='batch_getter').length,
        rng_calls:events.filter(e=>e.kind==='random').length,state_calls:events.filter(e=>e.kind==='get_state').length,hidden:events.filter(e=>e.kind==='source_hidden').map(e=>e.source)},
      after:{damage_stats:fleetRecord.damage.stats(),fleet_damage_max_hp:fleetRecord.damage.state.maxHp,fleet_mass_kg:fleet.stats().vehicles[0].massKg,charred_materials:charred,copied_nodes:copied}};
    assert.equal(callbackCount,1);
    if(kind==='throw'){
      assert.equal(thrown,'ORACLE_CALLBACK_THROW'); assert.equal(accepted,0); assert.equal(result.summary.rng_calls,0); assert.equal(result.summary.state_calls,0);
      assert.equal(events.some(e=>e.kind==='after_char'),true); assert.equal(events.some(e=>e.kind==='after_callback'),false); assert.equal(events.some(e=>e.kind==='after_glass'),false);
    } else {
      assert.equal(thrown,null); assert.equal(events.some(e=>e.kind==='after_callback'),true); assert.equal(events.some(e=>e.kind==='after_glass'),true);
      assert.equal(result.summary.rng_calls,accepted*7); assert.equal(result.summary.state_calls,accepted); assert.equal(result.summary.hidden.length,accepted);
      assert.equal(result.after.damage_stats.debris>=accepted,true);
    }
    fleet.dispose();
    return result;
  });
}

const rows=[];
for(const profile of profiles) rows.push(await runCase(profile,'normal'));
rows.push(await runCase(sedan,'mutation'));
rows.push(await runCase(sedan,'detail_disabled'));
rows.push(await runCase(sedan,'hidden_fallback'));
rows.push(await runCase(sedan,'hidden_root'));
rows.push(await runCase(sedan,'throw'));
assert.equal(rows.length,18);
const loaded=[],unpinned=[];
for(const file of [...dependencies].filter(p=>p.startsWith(repo+path.sep)&&fs.existsSync(p)&&fs.statSync(p).isFile()).sort()){
  const rel=relative(file); if(rel===relative(fileURLToPath(import.meta.url)))continue;
  const sha=hash(fs.readFileSync(file)); const expected=sourcePins.get(rel);
  if(!expected){unpinned.push({path:rel,sha256:sha});continue;} assert.equal(sha,expected,'Loaded source changed: '+rel); loaded.push({path:rel,sha256:sha});
}
assert.deepEqual(unpinned,[],'Loaded repo sources absent from pinned allowlist');
const result={schema:'mafiozi.transport-debris-copy-event-oracle.v1',status:'EXECUTED_SOURCE_TEST_ONLY',three_revision:T.REVISION,
  proof_method:{kind:'sha_and_unique_sentinel_pinned_in_memory_private_closure_instrumentation',production_source_modified:false,
    damage_sha256:expectedDamageSha,batches_sha256:expectedBatchesSha},
  inputs:{source_burn_identities:{path:relative(step1Path),sha256:expectedStep1Sha}},source_files:loaded,profiles:rows,
  invariants:{profile_count:13,case_count:18,normal_cases:13,callback_mutation_cases:4,callback_throw_cases:1,rng_draws_per_accepted_root:7,
    source_order:['char','callback','glass_hide','copyPart/detach','source_hide','rng/getState']},
  limits:['Test-only executed-source oracle; never loaded by gameplay runtime','No native event seam, authority, HP, physics, rendering, GPU, LIVE, or FPS proof',
    'The source callback throw intentionally proves partial char mutation and no later glass/copy/hide/RNG; it is not an atomic native transaction contract',
    'Digests preserve geometry/material/transform identity evidence without embedding complete vertex buffers']};
fs.mkdirSync(path.dirname(target),{recursive:true}); fs.writeFileSync(target,JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({output:relative(target),sha256:hash(fs.readFileSync(target)),bytes:fs.statSync(target).size,profiles:13,cases:rows.length,
  events:rows.reduce((n,r)=>n+r.event_count,0),accepted_roots:rows.reduce((n,r)=>n+r.summary.accepted,0)}));
