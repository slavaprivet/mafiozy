import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {performance} from 'node:perf_hooks';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {planSpaciousFloor,spaciousFloorPurpose} from './interior_spacious_layout.mjs';

const here=path.dirname(fileURLToPath(import.meta.url)),root=path.resolve(here,'../../..');
const fixturesFile=process.env.MAFIOZY_INTERIOR_FIXTURES;
const area=r=>(r[2]-r[0])*(r[3]-r[1]);
const inRect=(p,r,padding=0)=>p.x>=r[0]-padding&&p.x<=r[2]+padding&&p.z>=r[1]-padding&&p.z<=r[3]+padding;
const distRect=(p,r)=>Math.hypot(Math.max(r[0]-p.x,0,p.x-r[2]),Math.max(r[1]-p.z,0,p.z-r[3]));
const intersects=(a,b)=>a[0]<b[2]&&a[2]>b[0]&&a[1]<b[3]&&a[3]>b[1];

function assertPlan(fixture){
 const p=planSpaciousFloor(fixture),label=`${fixture.instanceId}/${fixture.level}`;
 if(p.preserveExisting){assert.equal(p.partitions.length,0);return p}
 assert.ok(p.rooms.length,label+' has an intentional room');
 assert.ok(p.metrics.mainRoomShare>=.53,label+' does not regress into a corridor');
 assert.ok(p.metrics.openArea>=p.metrics.usableArea*.55,label+' more than half usable floor is shared');
 assert.deepEqual(p.metrics.unreachable,[],label+' planned routes reach every door and staircase');
 for(const room of p.rooms){assert.ok(room.role&&room.name);assert.ok(room.rect.every(Number.isFinite));assert.ok(area(room.rect)>0);assert.ok(inRect({x:room.rect[0],z:room.rect[1]},fixture.rect,1e-6)&&inRect({x:room.rect[2],z:room.rect[3]},fixture.rect,1e-6));if(!room.openPlan){assert.ok(room.rect[2]-room.rect[0]>=2.75&&room.rect[3]-room.rect[1]>=2.75,label+' no micro room');assert.ok(room.door.width>=1.65,label+' broad door');}}
 const walls=p.partitions.filter(b=>b.collision&&b.bottom<fixture.y+1.8&&b.top>fixture.y+.1);
 const rails=(fixture.stairs??[]).filter(s=>s.lowerLevel===fixture.level||s.upperLevel===fixture.level).flatMap(s=>(s.obstacles??[]).filter(b=>b.minY<fixture.y+1.75&&b.maxY>fixture.y+.12).map(b=>({name:'actual stair railing',rect:b.rect})));
 // Every reserved centerline is tested with the real .36m hero radius against
 // wall geometry. Headers remain above the standing capsule.
 for(const route of p.reservedPaths)for(let j=1;j<route.points.length;j++){
  const a=route.points[j-1],b=route.points[j],steps=Math.max(1,Math.ceil(Math.hypot(b.x-a.x,b.z-a.z)/.1));
  for(let i=0;i<=steps;i++){const t=i/steps,q={x:a.x+(b.x-a.x)*t,z:a.z+(b.z-a.z)*t};assert.ok(inRect(q,fixture.rect,.001),label+' route inside actual floor');for(const wall of walls.concat(rails))assert.ok(distRect(q,wall.rect)>=.36-1e-5,`${label} capsule route ${route.id} clears ${wall.name}`)}
 }
 for(const s of p.stairAccess)for(const wall of walls)assert.ok(!intersects(wall.rect,s.rect),label+' two metre staircase approach reserved');
 for(const room of p.rooms.filter(r=>r.door)){const d=room.door;for(let t=-.75;t<=.75;t+=.05)for(const wall of walls)assert.ok(distRect({x:d.x,z:d.z+t},wall.rect)>=.36,label+' capsule through entire doorway');}
 assert.deepEqual(p,planSpaciousFloor(fixture),label+' deterministic replay');
 return p;
}

test('large public floors stay open, include typed side rooms and broad passages',()=>{
 for(const kind of['hospital','hotel','restaurant','civic','nightclub','strip_club','retail','gun_shop','print_shop','police','fire_station','warehouse'])for(let level=0;level<3;level++){
  const p=assertPlan({assetId:'fixture',instanceId:kind,level,rect:[-12,-10,12,10],y:level*3.5,ceiling:level*3.5+3.3,purpose:{kind}});
  assert.equal(p.rooms.length,3,kind+' all private rooms fit roomy fixture');
  if(kind==='hotel'&&level)assert.equal(p.rooms.filter(r=>r.role==='guest_bedroom').length,2);
  if(kind==='hospital'&&level)assert.equal(p.rooms[0].role,'hospital_ward');
 }
});
test('narrow existing homes retain their full width instead of a thin corridor',()=>{
 for(const width of[4.8,5.5,6.1])for(const depth of[7.5,9.8,15.4])for(let level=0;level<3;level++){
  const p=assertPlan({assetId:'old_town_narrow_townhouse_v1',instanceId:'home',level,rect:[-width/2,-depth,width/2,0],y:level*3.4,ceiling:level*3.4+3.2});
  assert.equal(p.partitions.length,0);assert.equal(p.rooms[0].rect[2]-p.rooms[0].rect[0],width);
 }
});
test('explicit purpose wins over the exterior asset; bank layouts remain unchanged',()=>{
 assert.equal(spaciousFloorPurpose({assetId:'compact_podium_glass_tower_v1'}),'residential');
 assert.equal(spaciousFloorPurpose({assetId:'compact_podium_glass_tower_v1',name:'Отель Белведер'}),'hotel');
 assert.equal(spaciousFloorPurpose({assetId:'pawnshop',purpose:{kind:'hospital'}}),'hospital');
 assert.equal(planSpaciousFloor({assetId:'bank_medium_shell_v1',rect:[-12,-12,12,12]}).preserveExisting,true);
 assert.equal(planSpaciousFloor({assetId:'hotel',rect:[-12,-12,12,12],bankLayout:{roomLabels:[]}}).preserveExisting,true);
});

test('a hotel retains kitchen circulation beside a rear staircase and guest beds on compact upper floors',()=>{
 const fixture={assetId:'hospital',instanceId:'REBUILD-VISUAL-hospital-001',purpose:{kind:'hotel'},level:0,y:0,ceiling:3.39,rect:[-5.931817746818136,-17.44090769486726,11.931817306818182,-1.2136361575945254],stairs:[{lowerLevel:0,upperLevel:1,footprint:[-3.357272472272716,-15.82090780486726,-.5772724722727163,-10.459369343328795],route:[{x:-2.707272472272716,y:0,z:-15.170907804867259},{x:-1.227272472272716,y:3.59,z:-15.170907804867259}]}]};
 const p=assertPlan(fixture),main=p.rooms.find(r=>r.role==='hotel_lobby'),kitchen=p.rooms.find(r=>r.role==='kitchen');
 assert.ok(p.rooms.some(r=>r.role==='dining_room'));
 assert.ok(kitchen?.functionalZone,'missing private kitchen becomes a connected open kitchen');
 assert.ok(p.reservedPaths.some(r=>r.id===kitchen.id&&r.kind==='functional'));
 assert.ok(main.reservedPaths.some(r=>r.kind==='functional-zone'&&r.rect[0]<=kitchen.rect[0]&&r.rect[2]>=kitchen.rect[2]),'lobby furniture cannot occupy the kitchen zone');
 assert.ok(!p.partitions.some(r=>intersects(r.rect,kitchen.rect)),'functional zone does not add a wall');
 assert.ok(kitchen.rect[2]-kitchen.rect[0]>=2.75&&kitchen.rect[3]-kitchen.rect[1]>=2.75);
 const top=assertPlan({assetId:'compact_podium_glass_tower_v1',instanceId:'hotel-top',purpose:{kind:'hotel'},level:6,rect:[-3.5,-7.168,3.5,0],y:21,ceiling:24.1});
 assert.equal(top.rooms.length,1);assert.equal(top.rooms[0].role,'guest_bedroom');
});

test('a rotated staircase uses its real upper approach when the synthetic front hub lies over the stair opening',()=>{
 const fixture={assetId:'glass_pavilion_small_v1',instanceId:'rotated-pavilion',level:1,y:4,ceiling:7.7,rect:[-5.454,-8.7372,5.454,-4.5252],stairs:[{lowerLevel:0,upperLevel:1,footprint:[-5.334,-7.4252,.3429230769,-4.6452],route:[{x:-4.684,y:0,z:-5.2952},{x:-4.684,y:4,z:-6.7752}],obstacles:[{rect:[-4.079,-6.1702,-2.6428461538,-6.0802],minY:3.125,maxY:4.995},{rect:[-4.079,-7.4702,-2.6428461538,-7.3802],minY:3.125,maxY:4.995}]}]};
 const before=structuredClone(fixture),p=assertPlan(fixture),access=p.stairAccess[0];
 assert.deepEqual(p.entry,access.point,'navigation begins on the accessible upper floor');
 assert.ok(p.reservedPaths.some(r=>r.kind==='main'&&r.points.length>1),'a real route still connects the stair landing to the room');
 assert.deepEqual(fixture,before,'stair geometry and height-specific railing obstacles remain untouched');
 const explicit={x:0,z:-5.0752},invalid=planSpaciousFloor({...fixture,entry:explicit});
 assert.equal(invalid.entry.x,explicit.x);assert.equal(invalid.entry.z,explicit.z);
 assert.ok(invalid.metrics.unreachable.includes('stair:0'),'an explicitly blocked entrance must still fail instead of being hidden');
});

// Opt-in all75 actual-GLB audit. Test fixtures are read from the running source
// transforms and storey/stair descriptors; no browser or GPU is created.
if(process.env.MAFIOZY_AUDIT_ALL_INTERIORS==='1'||fixturesFile){
 test('all 75 actual buildings and every storey preserve routes and spacious rooms',async()=>{
  let fixtures;
  if(fixturesFile)fixtures=JSON.parse(fs.readFileSync(fixturesFile,'utf8')).fixtures;
  else{
   const vendor=process.env.MAFIOZY_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
   registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(path.join(vendor,'build/three.module.js')).href:s,c)}});
   const T=await import(pathToFileURL(path.join(vendor,'build/three.module.js'))),{GLTFLoader}=await import(pathToFileURL(path.join(vendor,'addons/loaders/GLTFLoader.js'))),{createBuildingEntry}=await import('./building_entry.mjs'),{createBuildingStoreys}=await import('./building_storeys.mjs');
   const placement=JSON.parse(fs.readFileSync(path.join(here,'buildings_placement.v1.json'),'utf8')),sources=new Map();fixtures=[];
   for(const instance of placement.instances){
    let source=sources.get(instance.assetId);
    if(!source){const bytes=fs.readFileSync(path.join(root,instance.binding.url.slice(1))),loader=new GLTFLoader().register(()=>({name:'LAYOUT_AUDIT_TEXTURE_ONLY',loadTexture:()=>Promise.resolve(new T.Texture())}));source=(await loader.parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;sources.set(instance.assetId,source)}
    const group=new T.Group(),visual=source.clone(true),t=instance.transform;visual.position.fromArray(t.modelLocalOffsetM);group.position.fromArray(t.positionM);group.rotation.y=t.yawDegrees*Math.PI/180;group.scale.setScalar(t.uniformScale);group.add(visual);group.updateMatrixWorld(true);
    visual.traverse(n=>{if(/^(COLLISION|SOCKET|CLEARANCE|NAV_|COL_)/i.test(n.name)||(instance.hideNodeNames??[]).some(name=>name.replace(/\./g,'')===n.name))n.visible=false});
    const entry=createBuildingEntry({THREE:T,visual,instance});assert.ok(entry,instance.id+' actual entry exists');const storeys=createBuildingStoreys({THREE:T,entry,visual,instance});assert.ok(storeys,instance.id+' storeys exist');
    const stairs=storeys.stairs.map(s=>({lowerLevel:s.lowerLevel,upperLevel:s.upperLevel,footprint:s.footprint.slice(),route:[s.route[0],s.route.at(-1)],obstacles:s.obstacles.map(o=>({...o,rect:o.rect.slice()}))}));
    for(const floor of storeys.floors)fixtures.push({assetId:instance.assetId,instanceId:instance.id,role:instance.role,level:floor.level,y:floor.y,ceiling:floor.ceiling,rect:floor.rect.slice(),stairs,bankLayout:instance.bankLayout});entry.dispose();
   }
   const out=path.join(root,'outputs/interiors_spacious');fs.mkdirSync(out,{recursive:true});fs.writeFileSync(path.join(out,'actual_storey_fixtures.json'),JSON.stringify({source:'75 current actual GLBs and accepted transforms; CPU only',fixtures},null,2));
  }
  assert.equal(new Set(fixtures.map(f=>f.instanceId)).size,75);assert.equal(fixtures.length,174);
  const failures=[],plans=fixtures.map(f=>{try{return assertPlan(f)}catch(e){failures.push({id:f.instanceId,level:f.level,message:e.message});return planSpaciousFloor(f)}}),counts={buildings:75,floors:fixtures.length,rooms:plans.reduce((n,p)=>n+p.rooms.length,0),partitions:plans.reduce((n,p)=>n+p.metrics.partitionCount,0),preservedBankFloors:plans.filter(p=>p.preserveExisting).length};
  // Compare the original layout planning loop on the same fixture inputs.
  const previousLayout=f=>{if(f.bankLayout)return[];const rs=f.stairs.filter(s=>s.lowerLevel===f.level||s.upperLevel===f.level).map(s=>s.footprint),d=f.rect[3]-f.rect[1],mx=clamp(0,f.rect[0]+1.4,f.rect[2]-1.4),out=[];for(const side of[-1,1]){const x0=side<0?f.rect[0]:mx+.75,x1=side<0?mx-.75:f.rect[2];if(x1-x0<1.45)continue;const n=d>12?3:d>6?2:1;for(let j=0;j<n;j++){const r=[x0,f.rect[1]+d*j/n+.08,x1,Math.min(f.rect[3]-.5,f.rect[1]+d*(j+1)/n-.08)];if(r[3]-r[1]<1.8||rs.some(s=>intersects([r[0]-.5,r[1]-.5,r[2]+.5,r[3]+.5],s)))continue;out.push(r)}}return out};
  const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
  for(let i=0;i<3;i++)for(const f of fixtures)planSpaciousFloor(f);
  const bench=fn=>{const samples=[];for(let pass=0;pass<20;pass++){const start=performance.now();for(const f of fixtures)fn(f);samples.push(performance.now()-start)}samples.sort((a,b)=>a-b);return{all174FloorsP50Ms:samples[10],all174FloorsP95Ms:samples[18],perFloorP50Ms:samples[10]/fixtures.length}};
  const report={...counts,failures,creationBefore:bench(previousLayout),creationAfter:bench(planSpaciousFloor),perFrameUpdateMs:0,performanceScope:'CPU construction planning only; performance of the loaded game scene is not checked',floors:fixtures.map((f,i)=>({id:f.instanceId,level:f.level,purpose:plans[i].theme,...plans[i].metrics}))};
  const out=path.join(root,'outputs/interiors_spacious');fs.mkdirSync(out,{recursive:true});fs.writeFileSync(path.join(out,'layout_audit.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({...report,floors:undefined},null,2).slice(0,3000));assert.deepEqual(failures,[],`${failures.length} floor route failures (full report in outputs/interiors_spacious/layout_audit.json)`);
 });
}
