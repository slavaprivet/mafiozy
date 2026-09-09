// CPU geometry acceptance, not a replacement for the user's visual check.
// Runs the real GLBs, runtime factory and CLOSED hood/trunk controllers.
// Override VEHICLE_QA_FACTORY or MAFIOZY_FLEET_FACTORY for an absolute staged factory.
// MAFIOZY_THREE_VENDOR may override the local Three vendor runtime.
import assert from 'node:assert/strict';
import {test} from 'node:test';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const audit=fileURLToPath(new URL('./audit_vehicle_continuity.mjs',import.meta.url));
const result=spawnSync(process.execPath,[audit,'--full',...(process.env.VEHICLE_QA_FACTORY?['--factory='+process.env.VEHICLE_QA_FACTORY]:[])],{encoding:'utf8',maxBuffer:16*1024*1024});
assert.equal(result.status,0,result.stderr||result.error?.message);
const {vehicles}=JSON.parse(result.stdout);
assert.equal(vehicles.length,13,'All 12 authored vehicles plus existing red sedan');

for(const vehicle of vehicles){
 if(vehicle.id!=='red_demo')test(vehicle.id+': closed glazing physically meets opaque structure',()=>{
  assert(vehicle.windows.length>0,'No glazing checked: renamed geometry must be included');
  for(const window of vehicle.windows){
   assert(window.points.length===4,'Both upper/lower endpoints must be sampled');
   for(const point of window.points)assert(point.distanceM<=.025,
    `${window.name}/${point.label}: ${(point.distanceM*100).toFixed(1)} cm unsupported; nearest ${point.support}`);
  }
 });
 if(vehicle.id!=='red_demo')test(vehicle.id+': exterior equipment has a mounting path to the body',()=>{
  assert(vehicle.mounts.length>0,'No exterior accessory checked');
  // Lenses may mount via their base; ladder rungs via rails. A 35mm maximum
  // unsupported link accommodates seams but catches original 5–85cm layers.
  for(const mount of vehicle.mounts)assert(mount.mountGapM<=.035,
   `${mount.name}: minimum unsupported link ${(mount.mountGapM*100).toFixed(1)} cm via ${mount.via}`);
 });
 test(vehicle.id+': declared cargo volume contains a real 30cm object and a floor',()=>{
  const cargo=vehicle.cargo;
  assert(cargo.specified,'Missing physical cargo bounds');
  assert(cargo.cubeFitsBounds,'30cm cube does not fit cavity dimensions');
  assert.deepEqual(cargo.blockers,[],'Closed lid/hull/seat penetrates the cube at cavity center');
  assert(cargo.floor,'No actual visible surface under cargo');
  assert(Math.abs(cargo.floor.y-cargo.bounds.min[1])<.06,
   `Declared floor ${cargo.bounds.min[1].toFixed(3)}m but actual ${cargo.floor.name} at ${cargo.floor.y}m`);
 });
 test(vehicle.id+': engine bay opens with no cabin/hull intrusion or smoke masking',()=>{
  const engine=vehicle.engine;
  assert(engine.enabled&&engine.openAccepted,'Service panel must open through normal interaction');
  assert.equal(engine.amount,1,'Fully opened after settling');
  assert(engine.angleDegrees>=79.9&&engine.angleDegrees<=85.1,'Visible panel opening angle');
  assert.equal(engine.smokeParticles,0,'Healthy engine must not emit smoke');
  assert(engine.visibleEngineParts>=10,'Real engine detail, not an empty hole');
  assert.deepEqual(engine.foreignBlockers,[],'Body/seat/console geometry intrudes into engine cavity');
 });
 test(vehicle.id+': closed cargo rear skin and roof are not missing',()=>{
  assert.equal(vehicle.cargo.rearClosure?.length,9,'Actual rear-closure rays required');
  assert.deepEqual(vehicle.cargo.rearClosure.filter(r=>!r.sealed),[],'Open slit under a closed lid');
  assert.deepEqual(vehicle.cargo.roofClosure.filter(r=>!r.sealed),[],'Missing closed cargo roof/lid/glazing');
 });
}
