import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';
const source=fs.readFileSync(new URL('./civilian_parking_trip_source.js',import.meta.url),'utf8'),MAP=Array.from({length:40},()=>Array(40).fill(9)),CARS=[],NPCS=[];let now=0;
const box={MAP,CARS,NPCS,PARKING_LOTS:[],player:{r:35,c:35},myDrivingCarId:null,performance:{now:()=>now},document:{documentElement:{dataset:{}}},_trafficRoadTile:(r,c)=>r>=0&&c>=0&&r<40&&c<40&&MAP[Math.floor(r)][Math.floor(c)]===0,_trafficHardTileAt:(r,c)=>r<0||c<0||r>=40||c>=40||MAP[Math.floor(r)][Math.floor(c)]===1,_civilianPlanInterrupted:n=>!!n.dead,_clearNpcRoute:n=>{n._route=null;},npcWaypointOk:(n,r,c)=>r>=0&&c>=0&&r<40&&c<40&&MAP[Math.floor(r)][Math.floor(c)]!==1,_npcPathPassable:()=>true,_civilianRouteTo:()=>true,_npcEffectiveSpeed:()=>1,_npcAdvanceRoute:()=>false};
vm.createContext(box);vm.runInContext(source+`;globalThis.api={schedule:_civilianTripSchedule,plan:_civilianTripPlan,clear:_civilianTripPoseClear,sweep:_civilianTripSweep,driveway:_civilianTripDriveway,carTick:_civilianTripTickCar,npcTick:_civilianTripTickNpc,available:_civilianTripVehicleAvailable,set(t){_civilianTrip=t;t.car._civilianTrip=true;t.npc._civilianTrip=true;},trip(){return _civilianTrip;}}`,box);const api=box.api,lot={r0:2,c0:2,r1:20,c1:20},car={r:6,c:6,ang:0,dirDx:1,dirDy:0,parked:true,_onParking:lot,model:{L:1.8,W:.88}},npc={id:'existing',r:6,c:6};CARS.push(car);NPCS.push(npc);
assert(api.available(car));for(const flag of ['_hijackPending','_towed','_wrecked','_towDispatched','owner_uid','driver_uid']){car[flag]=true;assert(!api.available(car),flag);delete car[flag];}
assert(api.clear(car,6,6,0,[lot],false));MAP[6][6]=1;assert(!api.clear(car,6,6,0,[lot],false));MAP[6][6]=9;
MAP[6][7]=1;assert(!api.sweep(car,{r:6,c:6,angle:0},{r:6,c:9,angle:0},[lot],false),'swept body cannot tunnel');MAP[6][7]=9;
const blocker={r:6,c:8,model:car.model};CARS.push(blocker);assert(!api.clear(car,6,7,0,[lot],false),'existing car blocks whole footprint');CARS.pop();
assert(api.driveway(car,{r:6,c:6,angle:0},{r:6,c:9,angle:0},[lot]),'physical driveway exists');
const create=()=>({car,npc,carId:'existing-car',phase:'drive',index:0,plan:{lots:[lot],points:[{r:6,c:8,angle:0}],goal:{lot,door:{id:'shop',r:7,c:8}}}});let trip=create();api.set(trip);npc._civilianTripRiding=true;let prev=car.c;
for(let i=0;i<200;i++){now+=50;api.carTick(car,.05);api.npcTick(npc,.05,now);assert(Math.abs(car.c-prev)<=.07,'bounded continuous car movement');prev=car.c;if(!api.trip())break;}
assert(!api.trip(),'drive parks and passenger physically exits');assert.equal(CARS.length,1);assert.equal(NPCS.length,1);assert.equal(npc.id,'existing');assert.equal(npc._civilianPlan.phase,'walk_to_shop');
for(const flag of ['_hijackPending','_towed','_wrecked','_towDispatched','owner_uid']){car.r=6;car.c=6;car.parked=true;car[flag]=true;trip=create();trip.phase='approach';api.set(trip);npc._civilianTripRiding=false;api.npcTick(npc,.05,now);assert(!api.trip());assert(car[flag]);delete car[flag];}
assert.equal(CARS[0],car);assert.equal(NPCS[0],npc);assert.doesNotThrow(()=>JSON.stringify({car,npc}),'no cyclic entity fields');
console.log('PASS civilian trip: full footprint, swept wall/car contact, driveway, existing object identity, continuous drive/exit/visit, hijack/tow/wreck/ownership interruption, no cycles/duplicates');

// Explicit lane graph route connects two real parking pads and keeps its goal.
for(const row of MAP)row.fill(1);for(let r=0;r<3;r++)for(let c=0;c<30;c++)MAP[r][c]=0;
const home={r0:4,c0:4,r1:7,c1:7,slots:[]},destination={r0:4,c0:14,r1:7,c1:17,slots:[{r:5.5,c:15.5,dirDy:-1,dirDx:0}]};
for(const l of [home,destination])for(let r=3;r<=8;r++)for(let c=l.c0-1;c<=l.c1+1;c++)MAP[r][c]=9;
car.r=5.5;car.c=5.5;car.ang=-Math.PI/2;car.dirDy=-1;car.dirDx=0;car._onParking=home;car.parked=true;delete car._civilianTrip;box.PARKING_LOTS.push(home,destination);
const nodes=[{r:0,c:0},{r:0,c:10},{r:0,c:20}];box._getTrafficRoadGraph=()=>({nodes});box._trafficFindNodePath=(a,b)=>{const ai=nodes.indexOf(a),bi=nodes.indexOf(b);return bi>ai?nodes.slice(ai,bi+1):null;};box._trafficLanePoint=(n,dr,dc)=>({r:n.r+(dr>0||dc>0?.5:2.5),c:n.c+(dr>0||dc>0?.5:2.5)});box._residentBuildingDoors=()=>[{id:'destination-shop',r:7.5,c:16}];
const planned=api.plan(car);assert(planned,'pad to existing graph to explicit destination pad is reachable');assert.equal(planned.goal.door.id,'destination-shop');assert.equal(planned.points.at(-1).c,15.5);
const world=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8');const marked=world.slice(world.indexOf('// CIVILIAN_PARKING_TRIP_START'),world.indexOf('// CIVILIAN_PARKING_TRIP_END')+'// CIVILIAN_PARKING_TRIP_END'.length);assert.equal(marked.replaceAll('\r','').trim(),source.replaceAll('\r','').trim(),'tested block equals live source');
console.log('PASS explicit graph departure/arrival planner and exact live source equality');

trip={car,npc,carId:'existing-car',phase:'drive',index:0,plan:planned};api.set(trip);npc.r=car.r;npc.c=car.c;npc._civilianTripRiding=true;let ticks=0;
for(;ticks<5000&&api.trip();ticks++){const old={r:car.r,c:car.c};now+=50;api.carTick(car,.05);api.npcTick(npc,.05,now);assert(Math.hypot(car.r-old.r,car.c-old.c)<=1.35*.05+1e-9,'entire graph trip has no position jump');}
assert(!api.trip(),'planned departure+road+arrival reaches physical exit');assert(Math.hypot(car.r-5.5,car.c-15.5)<.04);assert.equal(npc._residentDoor.id,'destination-shop');
console.log('PASS complete planned source trip through lane graph in '+ticks+' continuous steps');

car.r=5.5;car.c=5.5;car.ang=-Math.PI/2;car.dirDy=-1;car.dirDx=0;car._onParking=home;car.parked=true;npc.r=5.5;npc.c=4.4;box._parkingNpcs=[];box._civilianPlanEligible=()=>true;box._threeVehicleEntityId=()=> 'stable-existing-car';box._npcAdvanceRoute=()=> 'arrived';
now+=30000;api.schedule(now);assert.equal(api.trip()?.phase,'approach');assert.equal(api.trip().npc,npc);assert.equal(api.trip().car,car);
for(ticks=0;ticks<5000&&api.trip();ticks++){const old={r:npc.r,c:npc.c};now+=50;api.npcTick(npc,.05,now);api.carTick(car,.05);assert(Math.hypot(npc.r-old.r,npc.c-old.c)<.08,'boarding and source rider do not jump');}
assert(!api.trip());assert.equal(car._onParking,destination);assert.equal(CARS.length,1);assert.equal(NPCS.length,1);
console.log('PASS scheduled existing NPC approaches, traverses door, boards, drives, parks, exits and visits with no duplicate or actor jump');
