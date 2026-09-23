import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {registerHooks} from 'node:module';
import {fileURLToPath,pathToFileURL} from 'node:url';
const dir=path.dirname(fileURLToPath(import.meta.url)),root=path.resolve(dir,'../../..'),url=n=>pathToFileURL(path.join(dir,n)),read=n=>fs.readFileSync(path.join(dir,n),'utf8');
const tracked=['mercenary_world.js','mercenary_core.mjs','mercenary_vehicle_bridge.mjs','npc_actor.mjs','npc_vehicle_pose.mjs','npc_death_entry20.mjs'];
const hashes=()=>Object.fromEntries(tracked.map(n=>[n,crypto.createHash('sha256').update(fs.readFileSync(path.join(dir,n))).digest('hex')]));
const before=hashes(),module=await import(url('mercenary_core.mjs'));
const source=read('mercenary_world.js'),script=source.replace("import(new URL('./mercenary_core.mjs',scriptUrl).href)",'Promise.resolve(module)');
assert.notEqual(script,source);
const fixtureSource=read('test_mercenary_rally_actions.mjs');
const fixture=Function('vm','module','script','assert',fixtureSource.slice(fixtureSource.indexOf('async function fixture('),fixtureSource.indexOf('\nfor(const [profession'))+';return fixture;')(vm,module,script,assert);
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(specifier,context,next){return next(specifier==='three'?pathToFileURL(vendor+'/build/three.module.js').href:specifier,context);}});
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const {RoundedBoxGeometry}=await import(pathToFileURL(path.join(root,'tools/vehicle_fleet_qa/RoundedBoxGeometry.mjs')));
const {clone}=await import(url('test_npc_death_offline_setup.mjs'));
const {createNpcActor,NPC_ASSETS}=await import(url('npc_actor.mjs'));
const {createDemoCar,CAR}=await import(url('car_drive.mjs'));
const {VEHICLE_SEATS}=await import(url('vehicle_seats.mjs'));
const {createNpcTrafficVehicleBinding}=await import(url('npc_vehicle_pose.mjs'));
const {createMercenaryVehicleBridge}=await import(url('mercenary_vehicle_bridge.mjs'));
const load=async location=>{const bytes=fs.readFileSync(new URL(location));return(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;};
const sources=Object.fromEntries(await Promise.all(['male','female'].map(async sex=>[sex,await load(NPC_ASSETS[sex].url)])));
const rows=[];
async function setup(count=1){
 const f=await fixture();const members=['safecracker','bruiser','engineer','demolitions'].slice(0,count).map(f.recruit);
 const scene=new THREE.Scene(),car=createDemoCar(THREE,RoundedBoxGeometry);car.profile={...CAR,id:'red_sedan',label:'Kingswell',height:2.22,massKg:1500};car.seats=VEHICLE_SEATS;scene.add(car.object);car.object.position.set(41,0,41);car.object.updateMatrixWorld(true);
 let player={id:'fleet:audit',seatId:'front_left',ready:true};const fleet={records:[{id:'audit',car,state:{speed:0}}]};
 const bridge=createMercenaryVehicleBridge({getFleet:()=>fleet,getPlayer:()=>player,canCross:()=>true});
 f.api.bindTargets({squadTransport:bridge,canMove:()=>true,groundHeight:()=>0});
 const binding=createNpcTrafficVehicleBinding({THREE,actor:car});
 function occupy(m,seatId){Object.assign(m,{_mercenaryVehicleId:'fleet:audit',_mercenaryVehicleSeat:seatId,_mercenaryVehiclePhase:'drive',_mercenaryVehicleProgress:1});}
 return {...f,members,scene,car,bridge,binding,occupy,setPlayer:p=>player=p};
}
const round=n=>Number(n.toFixed(6));
function presentation(npc,car){
 const c=npc.walker.artistContext(),bone=name=>c.worldPosition(name).toArray().map(round);let minY=Infinity,maxY=-Infinity;
 npc.object.traverse(mesh=>{if(!mesh.isSkinnedMesh)return;mesh.skeleton.update();const attr=mesh.geometry.attributes.position;for(let i=0;i<attr.count;i++){const v=new THREE.Vector3().fromBufferAttribute(attr,i);mesh.applyBoneTransform(i,v);mesh.localToWorld(v);minY=Math.min(minY,v.y);maxY=Math.max(maxY,v.y);}});
 return {pelvis:bone('pelvis'),head:bone('head'),minY:round(minY),maxY:round(maxY),root:npc.object.position.toArray().map(round),deathEntry:npc.saveSurfaceState().deathEntry20?.origin||null,reaction:npc.surface.state.kind};
}
for(const sex of ['male','female']){
 const f=await setup(),m=f.members[0];f.occupy(m,'front_right');f.tick(.05);
 const npc=createNpcActor({THREE,scene:f.scene,source:sources[sex],cloneSkeleton:clone,id:'npc_crew_'+m.id,sex,getVehicle:()=>f.binding});
 const render=(dt=0)=>{const life=f.api.decorateEntities([{id:npc.id,hp:m.hp,dead:!!m.dead,deathConfirmed:!!m.deathConfirmed,deadAt:m.deadAt}])[0];assert(life);npc.update(dt,{time:f.ctx.performance.now()/1000,position:{x:m.c*4.1,y:0,z:m.r*4.1},yaw:Math.PI/2-m.ang,life});return life;};
 render();f.tick(.05);render(.05);const alive=presentation(npc,f.car);
 Object.assign(m,{hp:0,dead:true,deathConfirmed:true,deadAt:f.ctx.performance.now()});const life=render();
 const phases=[{age:0,...presentation(npc,f.car)}];
 for(const dt of [.14,.14,.34,.38]){f.tick(dt);render(dt);phases.push({age:round((f.ctx.performance.now()-m.deadAt)/1000),...presentation(npc,f.car)});}
 const corpseBefore=phases.at(-1),sourceBefore={r:m.r,c:m.c};f.car.object.position.x+=4;f.car.object.updateMatrixWorld(true);f.tick(.1);render(.1);const moved=presentation(npc,f.car);
 rows.push({case:'real_Kingswell_confirmed_death_'+sex,seat:'front_right',alive,life:{dead:life.dead,deathConfirmed:life.deathConfirmed,riding:life.civilianTripRiding},phases,carMoves4m:{sourceDeltaMetres:round(Math.hypot(m.r-sourceBefore.r,m.c-sourceBefore.c)*4.1),pelvisDeltaX:round(moved.pelvis[0]-corpseBefore.pelvis[0]),corpse:moved},reservation:f.bridge.reservedSeats('fleet:audit')});npc.dispose();
}
{
 const f=await setup(4),[dead,...others]=f.members;['front_right','rear_left','rear_right'].forEach((seat,i)=>f.occupy(f.members[i],seat));f.tick(.05);
 Object.assign(dead,{hp:0,dead:true,deathConfirmed:true,deadAt:f.ctx.performance.now()});f.tick(.05);
 const atFatal={status:f.api.getRoster().members.find(r=>r.id===dead.id).status,seat:dead._mercenaryVehicleSeat,reservations:f.bridge.reservedSeats('fleet:audit')};
 f.tick(21);f.tick(.05);
 const sourceRows=f.members.map(m=>({id:'npc_crew_'+m.id,hp:m.hp,dead:!!m.dead,deathConfirmed:!!m.deathConfirmed}));
 const row={case:'hospital_hidden_seat_and_replacement',atFatal,status:f.api.getRoster().members.find(r=>r.id===dead.id).status,hospital:dead._mercenaryHospital,hidden:!f.api.decorateEntities(sourceRows).some(n=>n.id==='npc_crew_'+dead.id),retainedSeat:dead._mercenaryVehicleSeat,reservations:f.bridge.reservedSeats('fleet:audit'),waitingMember:{id:others[2].id,seat:others[2]._mercenaryVehicleSeat||null,reserved:others[2]._mercenaryVehicleReservedSeat||null}};
 // Control: remove the source actor entirely, as opposed to hiding it for hospital.
 f.ctx._myGang.splice(f.ctx._myGang.indexOf(dead),1);f.tick(.05);
 row.removedSourceControl={rosterStillContainsDead:f.api.getRoster().members.some(r=>r.id===dead.id),waitingMemberReserved:others[2]._mercenaryVehicleReservedSeat||null};rows.push(row);
}
for(const row of rows.filter(row=>row.case.startsWith('real_Kingswell'))){
 assert.deepEqual(row.life,{dead:true,deathConfirmed:true,riding:true},row.case+' keeps the confirmed corpse bound to its seat');
 assert(row.phases.every(phase=>phase.deathEntry==='vehicle'&&phase.reaction==='dead'),row.case+' never pops out during death entry');
 assert.equal(row.carMoves4m.sourceDeltaMetres,4,row.case+' source follows the moving car');
 assert.equal(row.carMoves4m.pelvisDeltaX,4,row.case+' rendered corpse follows the moving car');
 assert(row.reservation.includes('front_right'),row.case+' retains its physical seat before hospital removal');
}
const hospital=rows.find(row=>row.case==='hospital_hidden_seat_and_replacement');
assert.equal(hospital.atFatal.seat,'front_right','fatal corpse remains seated before hospital ownership transition');
assert.equal(hospital.status,'hospital');assert.equal(hospital.hospital,true);assert.equal(hospital.hidden,true);
assert.equal(hospital.retainedSeat,undefined,'hospital transition clears the corpse seat');
assert.equal(hospital.waitingMember.reserved,'front_right','waiting live member can immediately reserve the released seat');
const after=hashes(),report={scope:'Actual mercenary host + actual core/bridge/Kingswell/male-female GLBs. Confirms retained in-car corpse until hospital removal and immediate seat reuse; CPU visual pose, no GPU.',hashes:before,sourceChangedDuringRun:JSON.stringify(before)!==JSON.stringify(after),rows};
console.log(JSON.stringify(report,null,2));
