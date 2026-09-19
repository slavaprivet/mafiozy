import assert from 'node:assert/strict';
import {test} from 'node:test';
import {CAR,createCarWorld,carFits} from './car_drive.mjs';
import {cityParkingCarFits} from './city_parking_plan.mjs';
import {createLaneConnector} from './city_lane_connector.mjs';
import {createParkingOriginResolver,validateParkingVehicleProfile} from './city_parking_origin.mjs';

function fixture(){
 const lot={id:'lot',origin:{x:0,z:0},dx:0,dz:1,yaw:0,layout:'perpendicular',rect:{minX:-4,maxX:4,minZ:2,maxZ:14},driveway:{minX:-4.5,maxX:4.5,minZ:0,maxZ:2.1},bayCount:2,bayIds:['bay0','bay1']};
 const bays=[{id:'bay0',lotId:'lot',x:-1.6,z:10.9,yaw:0},{id:'bay1',lotId:'lot',x:1.6,z:10.9,yaw:0}],surfaceRects=[lot.rect,lot.driveway],roadSupportRects=[{minX:-30,maxX:30,minZ:-14,maxZ:0}],parking={lots:[lot],bays,surfaceRects,roadSupportRects};
 const fits=(x,z,yaw,shape=CAR)=>cityParkingCarFits(parking,x,z,yaw,shape);
 const connector=createLaneConnector({from:{x:1.65,z:5.6,yaw:Math.PI},to:{x:9.65,z:-2.5,yaw:Math.PI/2},isRoad:()=>true,poseAllowed:fits});assert(connector);
 parking.access={routes:[{id:'exit',lotId:'lot',kind:'exit',gear:'forward',points:connector.points}]};
 return {parking,bays,lot,fits};
}
const angle=a=>Math.atan2(Math.sin(a),Math.cos(a));

test('inward perpendicular bay reverses, changes gear without yaw teleport and exits a real driveway',()=>{
 const {parking,bays,fits}=fixture(),resolver=createParkingOriginResolver({parking,isRoad:(x,z)=>z<=0,poseAllowed:fits});
 for(const bay of bays){const origins=resolver.resolve({from:bay});assert.equal(origins.length,1);const {prefix,gearChanges}=origins[0];assert(gearChanges.length>0);assert.equal(prefix[0].gear,'reverse');assert.equal(prefix.at(-1).gear,'forward');assert.equal(prefix[0].x,bay.x);assert.equal(prefix[0].z,bay.z);
  for(let i=1;i<prefix.length;i++){const a=prefix[i-1],b=prefix[i],d=Math.hypot(b.x-a.x,b.z-a.z),dyaw=angle(b.yaw-a.yaw);assert(d>0);assert(Math.abs(dyaw)/d<=1/4.29);const alignment=((b.x-a.x)*Math.sin(a.yaw+dyaw/2)+(b.z-a.z)*Math.cos(a.yaw+dyaw/2))/d;assert(alignment*(b.gear==='reverse'?-1:1)>.998);assert(fits(b.x,b.z,b.yaw));}
  for(const change of gearChanges){assert(change.requiresStop);assert.equal(prefix[change.pointIndex].gear,change.from);assert.equal(prefix[change.pointIndex+1].gear,change.to);}
 }
});

test('cached manoeuvres never cache clearance: a new fixed barrier blocks the whole exit',()=>{
 const {parking,bays,fits}=fixture();let blocked=false;
 const resolver=createParkingOriginResolver({parking,isRoad:()=>true,poseAllowed:(x,z,yaw,shape)=>fits(x,z,yaw,shape)&&(!blocked||z>0)});
 assert.equal(resolver.resolve({from:bays[0]}).length,1);const initial=resolver.diagnostics().geometryBuilds;blocked=true;assert.equal(resolver.resolve({from:bays[0]}).length,0);assert.equal(resolver.diagnostics().geometryBuilds,initial);blocked=false;assert.equal(resolver.resolve({from:bays[0]}).length,1);
});

test('callers cannot corrupt cached geometry or authored exits by changing returned points',()=>{
 const {parking,bays,fits}=fixture(),resolver=createParkingOriginResolver({parking,isRoad:()=>true,poseAllowed:fits}),first=resolver.resolve({from:bays[0]})[0],end=parking.access.routes[0].points.at(-1).x;
 first.prefix[0].x=999;first.point.x=999;const next=resolver.resolve({from:bays[0]})[0];assert.equal(next.prefix[0].x,bays[0].x);assert.equal(next.point.x,end);assert.equal(parking.access.routes[0].points.at(-1).x,end);
});

test('actual vehicle profile reaches every solid and paved-hull query; unsupported size fails closed',()=>{
 const {parking,bays,fits}=fixture();const seen=[];
 const resolver=createParkingOriginResolver({parking,isRoad:()=>true,poseAllowed:(x,z,yaw,p)=>{seen.push([p.halfLength,p.halfWidth]);return fits(x,z,yaw,p);}});
 assert.equal(resolver.resolve({from:bays[0],profile:{halfLength:2.4542,halfWidth:1.188}}).length,1);assert(seen.length>100);assert(seen.every(p=>p[0]===2.4542&&p[1]===1.188));
 assert.equal(resolver.resolve({from:bays[0],profile:{halfLength:4,halfWidth:2.5}}).length,0);
 for(const profile of [{halfLength:NaN,halfWidth:1},{halfLength:-1,halfWidth:1},{halfLength:2,halfWidth:Infinity},{halfLength:2,halfWidth:1,collisionHull:[[0,0],[1,NaN],[1,0]]}])assert.equal(validateParkingVehicleProfile(profile),null);
});

test('arbitrary already outward-facing pose retains the direct physically checked connector',()=>{
 const {parking,fits}=fixture(),resolver=createParkingOriginResolver({parking,isRoad:()=>true,poseAllowed:fits}),from={x:1.65,z:7,yaw:Math.PI};
 const [origin]=resolver.resolve({from});assert(origin);assert.equal(origin.prefix[0].z,7);assert(origin.prefix.every(p=>p.gear==='forward'));assert.equal(origin.gearChanges.length,0);
 assert.deepEqual(resolver.resolve({from:{x:50,z:50,yaw:0}}),[{point:{x:50,z:50,yaw:0},prefix:[]}]);
});

test('admission can stop at the first safe exit without validating all alternate tails',()=>{
 const {parking,bays,fits}=fixture();parking.access.routes.push({...parking.access.routes[0],id:'second-exit'});
 const resolver=createParkingOriginResolver({parking,isRoad:()=>true,poseAllowed:fits});
 assert.equal(resolver.resolve({from:bays[0],firstOnly:true}).length,1);assert.equal(resolver.resolve({from:bays[0]}).length,2);
});

test('a thin obstacle between two existing driveway samples is swept, not stepped over',()=>{
 const {parking,bays,fits}=fixture(),route=parking.access.routes[0];
 const obstacle=createCarWorld({grid:[]},[{minYM:0,maxYM:2,polygonCR:[[-10,-.005],[10,-.005],[10,.005],[-10,.005]]}],1,{surfaceAt:()=>true});
 route.points=[{x:1.65,z:5.6,yaw:Math.PI},{x:1.65,z:-6,yaw:Math.PI}];
 assert(route.points.every(p=>carFits(p.x,p.z,p.yaw,obstacle)),'both coarse endpoints are unobstructed');
 const resolver=createParkingOriginResolver({parking,isRoad:()=>true,poseAllowed:(x,z,yaw,shape)=>fits(x,z,yaw,shape)&&carFits(x,z,yaw,obstacle,shape)});
 assert.equal(resolver.resolve({from:bays[0]}).length,0);
});
