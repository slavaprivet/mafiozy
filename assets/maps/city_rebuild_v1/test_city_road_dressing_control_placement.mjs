import test from 'node:test';
import assert from 'node:assert/strict';
import {prioritySignMatchesApproach,yieldTrianglePlacementValid,roadPedestrianPhase,roadSignalPhase,findIncomingControlVerge} from './city_road_dressing_plan.mjs';

test('priority dedup only shares a diamond facing the same incoming stream',()=>{
 const approach={roadId:'A-EAST-RING',center:{x:574,z:92.6709333},outward:{x:0,z:1}};
 const oldSuppressor={kind:'priority',roadId:approach.roadId,x:565.02,z:72.4821333,yaw:-Math.PI};
 assert.equal(prioritySignMatchesApproach(oldSuppressor,approach),false,'actual opposite-facing road-priority-25 cannot suppress junction-18');
 assert.equal(prioritySignMatchesApproach({...oldSuppressor,yaw:0},approach),true);
 assert.equal(prioritySignMatchesApproach({...oldSuppressor,yaw:Math.PI/2},approach),false);
 assert.equal(prioritySignMatchesApproach({...oldSuppressor,yaw:0,roadId:'parallel-road'},approach),false);
 assert.equal(prioritySignMatchesApproach({...oldSuppressor,yaw:0,z:400},approach),false);
});
const approach={id:'own:main:0:1',junctionId:'own',roadId:'main',outward:{x:0,z:1},progress:0,direction:1,entryDistance:10,width:8,lanes:2,path:{length:60,segments:[{a:{x:0,z:0},b:{x:0,z:60},tx:0,tz:1,start:0,length:60}]}};
const triangle=(x=2,z=16)=>[{x,z:z+1.4},{x:x-.95,z:z-.85},{x:x+.95,z:z-.85}];
const valid=(extra={})=>yieldTrianglePlacementValid({vertices:triangle(),approach,stopPoint:{x:2,z:12},complexId:'own-complex',...extra});
test('yield fallback stays before its stop and on its own incoming road half',()=>{
 assert.equal(valid(),true);
 assert.equal(valid({vertices:triangle(-2)}),false,'a triangle on the opposing half cannot instruct this approach');
 assert.equal(valid({vertices:triangle(2,11)}),false,'a triangle may not straddle the stop line');
 assert.equal(valid({vertices:triangle(2,60)}),false,'a triangle cannot run off the authored approach');
 assert.equal(valid({vertices:triangle(3.4)}),false,'complete stroke stays inside lane edge');
});
test('yield fallback checks triangle edges against distinct junction complexes',()=>{
 assert.equal(valid({junctions:[{id:'neighbour',complexId:'other',x:2,z:17,radius:2}]}),false);
 assert.equal(valid({junctions:[{id:'neighbour',complexId:'other',x:3.9,z:15.15,radius:1}]}),false,'edge grazes another complex even while triangle centre is outside');
 assert.equal(valid({junctions:[{id:'neighbour',complexId:'other',x:15,z:17,radius:2}]}),true);
 assert.equal(valid({junctions:[{id:'own-member',complexId:'own-complex',x:2,z:17,radius:2}]}),true,'a graph-internal priority boundary retains its own complex control');
});
test('pedestrian start window shares the real controller and leaves enough crossing clearance',()=>{
 for(const axis of [0,1])for(const offset of [0,7,21,43]){const crossing={signalControl:{axis,offset,clearanceSeconds:17}};let walkFrames=0;for(let time=-44;time<88;time+=.1)if(roadPedestrianPhase(crossing,time)==='walk'){walkFrames++;assert.equal(roadSignalPhase(time,axis,offset),'red');for(let future=0;future<17;future+=.25)assert.equal(roadSignalPhase(time+future,axis,offset),'red','the pedestrian can finish before this traffic stream turns green');}assert.ok(walkFrames>0);}
 assert.equal(roadPedestrianPhase({},0),'uncontrolled');
});

const vergeApproach={pathId:'test:0',width:8,rule:'yield',progress:0,direction:1,entryDistance:6,outward:{x:0,z:1},path:{length:50,sample:s=>({x:0,z:s,tx:0,tz:1})}};
const dryVerge=(x,z)=>({road:Math.abs(x)<4,land:Math.abs(x)>=4});
test('exceptional control follows its own right curb, with explicit left alternative only when right is occupied',()=>{
 const find=safeSign=>findIncomingControlVerge({approach:vergeApproach,surfaceAt:dryVerge,safeSign});
 const right=find((x,z)=>x<0||z>=14);assert.equal(right.controlPlacement.side,'right','a later right verge is preferred to a closer left one');assert(right.z>=14);assert.equal(right.yaw,0);
 const left=find((x,z)=>x<0);assert.equal(left.controlPlacement.side,'left');assert.equal(left.controlPlacement.rightVergeUnavailable,true);assert(left.x<-4&&left.z>=6);
});
test('no control jumps across another carriageway, water, or an upstream junction to reach an empty patch',()=>{
 const next=()=>findIncomingControlVerge({approach:vergeApproach,surfaceAt:dryVerge,safeSign:(x,z)=>z>=14,upstreamDistance:4});assert.equal(next(),null,'do not put the first junction sign beyond a second one');
 for(const middle of ['water','road']){const surfaceAt=(x,z)=>{const side=Math.abs(x);return side<4?{road:true,land:false}:side<5?{road:false,land:true}:side<7?{road:middle==='road',land:false}:{road:false,land:true}};assert.equal(findIncomingControlVerge({approach:vergeApproach,surfaceAt,safeSign:(x,z)=>Math.abs(x)>=7}),null);}
});
test('priority confirmation stays before its physical junction, and placement search has a fixed work bound',()=>{
 let probes=0;const point=findIncomingControlVerge({approach:{...vergeApproach,rule:'priority'},surfaceAt:dryVerge,safeSign:(x,z)=>z<=5});assert(point);assert(point.controlPlacement.distanceFromJunctionM>=1);assert(point.z>0,'a free site across the intersection cannot confirm this approach');
 const absent=findIncomingControlVerge({approach:{...vergeApproach,rule:'priority',path:{...vergeApproach.path,length:1e6}},surfaceAt(x,z){probes++;return dryVerge(x,z)},safeSign:()=>false});assert.equal(absent,null);assert(probes<8000,'map-length growth cannot produce unbounded pole placement scans');
});

test('rail clearance may use a wider continuous shoulder but never a second carriageway',()=>{
 const options={approach:vergeApproach,surfaceAt:dryVerge,safeSign:x=>x<-9.2};
 assert.equal(findIncomingControlVerge(options),null,'normal shoulder budget cannot clear this rail reservation');
 const p=findIncomingControlVerge({...options,maxCurbSetback:6});assert(p);assert.equal(p.controlPlacement.side,'left');assert(p.controlPlacement.curbSetbackM<=6);assert(p.controlPlacement.curbSetbackM>4.8);assert(p.x<-9.2);
 const separated=(x,z)=>{const side=Math.abs(x);return {road:side<4||side>7&&side<9,land:side>=4&&side<=7||side>=9};};
 assert.equal(findIncomingControlVerge({...options,maxCurbSetback:6,surfaceAt:separated}),null,'a parallel road between the approach and the free patch still stops the search');
});
