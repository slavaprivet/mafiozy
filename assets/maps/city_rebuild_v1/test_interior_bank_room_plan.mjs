import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {performance} from 'node:perf_hooks';
import {planBankRooms} from './interior_bank_room_plan.mjs';

const placement=JSON.parse(fs.readFileSync(new URL('./buildings_placement.v1.json',import.meta.url),'utf8')),banks=placement.instances.filter(x=>x.bankLayout),EPS=1e-6;
const overlap=(a,b)=>a[0]<b[2]-EPS&&a[2]>b[0]+EPS&&a[1]<b[3]-EPS&&a[3]>b[1]+EPS;
const inside=(x,z,r)=>x>=r[0]-EPS&&x<=r[2]+EPS&&z>=r[1]-EPS&&z<=r[3]+EPS;
const expectedRoles={public_lobby:'civic_hall',staff_office:'office',archive_manager:'archive',security_approach:'security_office',vault:'vault',staff_lounge:'living_room',meeting_room:'meeting_hall'};
function freeze(value){if(value&&typeof value==='object'){for(const child of Object.values(value))freeze(child);Object.freeze(value)}return value}

test('all three authored banks have seven distinct room rectangles preserving names, IDs and vault',()=>{
 assert.equal(banks.length,3);
 for(const raw of banks){
  const instance=freeze(structuredClone(raw)),before=JSON.stringify(instance),plan=planBankRooms({instance});
  assert.equal(JSON.stringify(instance),before,'pure function does not modify signed placement or layout');assert.equal(plan.coordinateSpace,'original GLB visual local metres');assert.equal(plan.rooms.length,7);
  assert.equal(new Set(plan.rooms.map(r=>r.rect.join(','))).size,7,'door gaps no longer give two rooms the same large rectangle');
  for(const room of plan.rooms){
   const label=instance.bankLayout.roomLabels.find(l=>l.id===room.id);assert.equal(room.name,label.label);assert.equal(room.role,expectedRoles[room.id]);assert(inside(label.center[0],label.center[2],room.rect));assert(room.doors.length>=1);
   assert(!instance.bankLayout.wallRects.some(w=>overlap(room.rect,w.rect)),'room excludes all named wall thicknesses');
   for(const other of plan.rooms)if(other!==room)assert(!overlap(room.rect,other.rect),`${room.id} overlaps ${other.id}`);
  }
  const lobby=plan.rooms.find(r=>r.id==='public_lobby'),vault=plan.rooms.find(r=>r.id==='vault');
  assert(lobby.rect[1]>instance.bankRoomProfile.bounds[1]+3,'public lobby cannot span the entire rear floor');
  assert.deepEqual(vault.rect,instance.bankLayout.vault.rect);assert.equal(vault.preserveExisting,true);
 }
});

test('room borders use authored wall inner faces independently of labels aligned with open door gaps',()=>{
 for(const instance of banks){
  const plan=planBankRooms({instance}),rooms=Object.fromEntries(plan.rooms.map(r=>[r.id,r])),walls=Object.fromEntries(instance.bankLayout.wallRects.map(w=>[w.name,w.rect]));
  assert.equal(rooms.public_lobby.rect[1],walls.Bank_Partition_Arch_0[3]);
  assert.equal(rooms.staff_office.rect[3],walls.Bank_Partition_Arch_0[1]);assert.equal(rooms.staff_office.rect[2],walls.Bank_Partition_Staff_Security[0]);
  assert.equal(rooms.archive_manager.rect[3],walls.Bank_Partition_Staff_Rear_L[1]);assert.equal(rooms.staff_office.rect[1],walls.Bank_Partition_Staff_Rear_L[3]);
  assert.equal(rooms.meeting_room.rect[3],walls.Bank_Partition_Lounge_Rear_L[1]);assert.equal(rooms.staff_lounge.rect[1],walls.Bank_Partition_Lounge_Rear_L[3]);
  assert.equal(rooms.security_approach.rect[1],walls.Bank_Vault_Front_L[3]);assert.equal(rooms.vault.rect[3],walls.Bank_Vault_Front_L[1]);
  const moved=structuredClone(instance);for(const label of moved.bankLayout.roomLabels){const r=rooms[label.id].rect;label.center=[(r[0]+r[2])/2,.1,(r[1]+r[3])/2]}
  assert.deepEqual(planBankRooms({instance:moved}).rooms.map(r=>r.rect),plan.rooms.map(r=>r.rect),'label ray alignment never changes partition ownership');
 }
});

test('six original interior openings and the public entry connect all seven rooms with honest widths',()=>{
 for(const instance of banks){
  const plan=planBankRooms({instance});assert.equal(plan.doors.length,7);assert.equal(plan.report.internalDoorways,6);assert.equal(plan.reservedPaths.length,46);
  const reached=new Set(['outside']);for(let pass=0;pass<8;pass++)for(const d of plan.doors)if(d.between.some(id=>reached.has(id)))d.between.forEach(id=>reached.add(id));assert.equal(reached.size,8);
  assert(Math.abs(plan.doors.find(d=>d.id==='security_vault').width-2.1)<EPS);
  for(const room of plan.rooms){assert(room.door.open);assert.equal(room.door,room.doors.find(d=>d.id===room.door.id));assert(room.reservedPaths.some(p=>inside(room.center[0],room.center[2],p.rect)),'room centre remains reachable through reserved routes')}
  for(const path of plan.reservedPaths){
   assert(!instance.bankLayout.wallRects.some(w=>overlap(path.rect,w.rect)),path.id+' crosses an existing wall');
   if(path.kind!=='doorway')assert(path.width>=1.5);
  }
  const narrow=plan.report.narrowExistingDoors;
  assert.equal(narrow.length,/large/.test(instance.id)?0:2);
  if(/small/.test(instance.id))assert(narrow.every(d=>Math.abs(d.width-9/7)<EPS),'small bank retains actual 1.286m rear doors');
  if(/medium/.test(instance.id))assert(narrow.every(d=>Math.abs(d.width-13/9)<EPS),'medium bank retains actual 1.444m rear doors');
 }
});

test('every reserved room centre has a physical capsule route from the public entry in each real bank',()=>{
 const step=.15,radius=.33;
 for(const instance of banks){
  const plan=planBankRooms({instance}),[x0,z0,x1,z1]=plan.bounds,nx=Math.ceil((x1-x0)/step),nz=Math.ceil((z1-z0)/step),visited=new Uint8Array(nx*nz),queue=[];
  const point=(x,z)=>[x0+(x+.5)*step,z0+(z+.5)*step],key=(x,z)=>z*nx+x;
  const allowed=(x,z)=>{if(x<0||z<0||x>=nx||z>=nz)return false;const[p,q]=point(x,z);if(!plan.reservedPaths.some(r=>inside(p,q,r.rect)))return false;return !instance.bankLayout.wallRects.some(w=>{const r=w.rect,dx=Math.max(r[0]-p,0,p-r[2]),dz=Math.max(r[1]-q,0,q-r[3]);return Math.hypot(dx,dz)<radius})};
  const start=[Math.floor((0-x0)/step),Math.floor((z1-.6-z0)/step)];assert(allowed(...start));queue.push(start);visited[key(...start)]=1;
  for(let index=0;index<queue.length;index++)for(const[dx,dz]of[[1,0],[-1,0],[0,1],[0,-1]]){const x=queue[index][0]+dx,z=queue[index][1]+dz;if(x>=0&&z>=0&&x<nx&&z<nz&&!visited[key(x,z)]&&allowed(x,z)){visited[key(x,z)]=1;queue.push([x,z])}}
  for(const room of plan.rooms){const x=Math.floor((room.center[0]-x0)/step),z=Math.floor((room.center[2]-z0)/step);assert.equal(visited[key(x,z)],1,instance.id+' '+room.id+' has no physical route through reserved paths')}
 }
});

test('world rotation and scale never alter the original GLB coordinate plan',()=>{
 const original=banks[0],moved=structuredClone(original);moved.transform={positionM:[900,8,1200],yawDegrees:137,uniformScale:2.5};
 assert.deepEqual(planBankRooms({instance:moved}),planBankRooms({instance:original}));
 const plan=planBankRooms({instance:original,floorBounds:[-17,-13,17,13],entryDoor:{x:0,z:13.15,width:2.86}});assert.equal(plan.doors.find(d=>d.external).width,2.86);
 assert.equal(planBankRooms({instance:{id:'ordinary-house'}}),null);
});

test('missing or inconsistent named walls cannot silently invent a replacement room',()=>{
 const missing=structuredClone(banks[0]);missing.bankLayout.wallRects=missing.bankLayout.wallRects.filter(w=>w.name!=='Bank_Partition_Staff_Security');assert.throws(()=>planBankRooms({instance:missing}),/Missing authored bank partition/);
 const invalid=structuredClone(banks[0]);invalid.bankLayout.wallRects.find(w=>w.name==='Bank_Partition_Arch_1').rect[1]+=2;assert.throws(()=>planBankRooms({instance:invalid}),/Invalid authored bank wall|not aligned/);
 assert.throws(()=>planBankRooms({instance:banks[0],minimumPathWidth:1.2}),/Invalid bank furnishing path/);
});

test('planning cost is paid once per construction and has no per-frame update',()=>{
 const samples=[];for(let warm=0;warm<20;warm++)for(const instance of banks)planBankRooms({instance});
 for(let sample=0;sample<80;sample++){const start=performance.now();for(const instance of banks)planBankRooms({instance});samples.push(performance.now()-start)}samples.sort((a,b)=>a-b);
 console.log(JSON.stringify({scenario:'pure planning for 3 banks / 21 rooms, no renderer',p50Ms:samples[39],p95Ms:samples[75],recurringUpdateMs:0,limitation:'Loaded game frame p50/p95 and GPU performance are not verified'}));
 assert.equal(planBankRooms({instance:banks[0]}).update,undefined);
});
