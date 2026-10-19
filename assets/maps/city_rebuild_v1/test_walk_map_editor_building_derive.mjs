import assert from 'node:assert/strict';
import test from 'node:test';
import {deriveMovedBuilding,transformBuildingPointCR} from './walk_map_editor_building_derive.mjs';

const M=4.1;
const BASE_TRANSFORM={positionM:[41,0,82],yawDegrees:0,uniformScale:1,horizontalScale:[2,1],modelLocalOffsetM:[0,0,0],preserveSiteBounds:false};
const TARGET_POSITION=[49.2,0,73.8];
const base={
 id:'HOUSE-A',assetId:'garden_lane_house_v1',role:'residence',districtId:'test',transform:BASE_TRANSFORM,
 bounds:{min:[-2.05,0,-2.05],max:[2.05,8.2,2.05]},
 footprint:{minC:9,minR:19.5,maxC:11,maxR:20.5},clearance:{minC:8.5,minR:19,maxC:11.5,maxR:21},
 entry:{anchorRC:{c:10,r:20.5},roadProbeRC:{c:10,r:22.5},authoredLocalXYZ:[0,0,2.05]},
 entryCorridor:{minC:9.8,minR:20.4,maxC:10.2,maxR:22.6},
 collision:{method:'fixture',worldBodies:[{id:'rear-wall',polygonCR:[[9,19.5],[11,19.5],[11,20],[9,20]],rectangleRC:{minC:9,minR:19.5,maxC:11,maxR:20},minYM:0,maxYM:8.2}]},
 futureField:{kept:true}
};

const at=(yawDegrees,extra={})=>({...BASE_TRANSFORM,positionM:[...TARGET_POSITION],yawDegrees,...extra});
const rect=(minC,minR,maxC,maxR)=>({minR,minC,maxR,maxC});
const topology=()=>({
 grid:Array.from({length:40},()=>Array(40).fill(8)),
 roadMask:Array.from({length:40},()=>Array(40).fill(0)),
 protectedMask:Array.from({length:40},()=>Array(40).fill(0)),
 policeMask:Array.from({length:40},()=>Array(40).fill(0)),
 bridgeDeckMask:Array.from({length:40},()=>Array(40).fill(0))
});

const cardinalFixtures=[
 {
  yaw:0,footprintPolygon:[[11,17.5],[13,17.5],[13,18.5],[11,18.5]],footprint:rect(11,17.5,13,18.5),
  clearancePolygon:[[10.5,17],[13.5,17],[13.5,19],[10.5,19]],clearance:rect(10.5,17,13.5,19),
  body:[[11,17.5],[13,17.5],[13,18],[11,18]],bodyRect:rect(11,17.5,13,18),
  anchor:{r:18.5,c:12},probe:{r:20.5,c:12},
  corridorPolygon:[[11.8,18.4],[12.2,18.4],[12.2,20.6],[11.8,20.6]],corridor:rect(11.8,18.4,12.2,20.6)
 },
 {
  yaw:90,footprintPolygon:[[11.5,19],[11.5,17],[12.5,17],[12.5,19]],footprint:rect(11.5,17,12.5,19),
  clearancePolygon:[[11,19.5],[11,16.5],[13,16.5],[13,19.5]],clearance:rect(11,16.5,13,19.5),
  body:[[11.5,19],[11.5,17],[12,17],[12,19]],bodyRect:rect(11.5,17,12,19),
  anchor:{r:18,c:12.5},probe:{r:18,c:14.5},
  corridorPolygon:[[12.4,18.2],[12.4,17.8],[14.6,17.8],[14.6,18.2]],corridor:rect(12.4,17.8,14.6,18.2)
 },
 {
  yaw:180,footprintPolygon:[[13,18.5],[11,18.5],[11,17.5],[13,17.5]],footprint:rect(11,17.5,13,18.5),
  clearancePolygon:[[13.5,19],[10.5,19],[10.5,17],[13.5,17]],clearance:rect(10.5,17,13.5,19),
  body:[[13,18.5],[11,18.5],[11,18],[13,18]],bodyRect:rect(11,18,13,18.5),
  anchor:{r:17.5,c:12},probe:{r:15.5,c:12},
  corridorPolygon:[[12.2,17.6],[11.8,17.6],[11.8,15.4],[12.2,15.4]],corridor:rect(11.8,15.4,12.2,17.6)
 },
 {
  yaw:270,footprintPolygon:[[12.5,17],[12.5,19],[11.5,19],[11.5,17]],footprint:rect(11.5,17,12.5,19),
  clearancePolygon:[[13,16.5],[13,19.5],[11,19.5],[11,16.5]],clearance:rect(11,16.5,13,19.5),
  body:[[12.5,17],[12.5,19],[12,19],[12,17]],bodyRect:rect(12,17,12.5,19),
  anchor:{r:18,c:11.5},probe:{r:18,c:9.5},
  corridorPolygon:[[11.6,17.8],[11.6,18.2],[9.4,18.2],[9.4,17.8]],corridor:rect(9.4,17.8,11.6,18.2)
 }
];

test('identity is lossless and returns an independent clone',()=>{
 const result=deriveMovedBuilding({trustedBase:base,nextTransform:BASE_TRANSFORM});
 assert.equal(result.ok,true);assert.deepEqual(result.record,base);assert.notEqual(result.record,base);assert.deepEqual(result.dirty,[]);
});

for(const expected of cardinalFixtures)test(`numeric 4.1m fixture derives ${expected.yaw} degrees`,()=>{
 const result=deriveMovedBuilding({trustedBase:base,nextTransform:at(expected.yaw)});
 assert.equal(result.ok,true);assert.deepEqual(result.record.footprint,expected.footprint);assert.deepEqual(result.exact.footprintPolygon,expected.footprintPolygon);
 assert.deepEqual(result.record.clearance,expected.clearance);assert.deepEqual(result.exact.clearancePolygon,expected.clearancePolygon);
 const body=result.record.collision.worldBodies[0];assert.deepEqual(body.polygonCR,expected.body);assert.deepEqual(body.rectangleRC,{...expected.bodyRect,conservativeRectangle:false});
 assert.deepEqual(result.record.entry.anchorRC,expected.anchor);assert.deepEqual(result.record.entry.roadProbeRC,expected.probe);
 assert.deepEqual(result.record.entryCorridor,expected.corridor);assert.deepEqual(result.exact.corridorPolygon,expected.corridorPolygon);
 assert.equal(result.record.futureField.kept,true);assert.deepEqual(result.record.bounds,base.bounds);
});

test('uniform and horizontal scale derive every dependent field numerically',()=>{
 const next=at(0,{positionM:[49.2,2,73.8],uniformScale:1.5,horizontalScale:[3,.5]}),result=deriveMovedBuilding({trustedBase:base,nextTransform:next});
 assert.equal(result.ok,true);assert.deepEqual(result.record.transform.horizontalScale,[3,.5]);assert.deepEqual([next.uniformScale*next.horizontalScale[0],next.uniformScale,next.uniformScale*next.horizontalScale[1]],[4.5,1.5,.75]);
 assert.deepEqual(result.exact.footprintPolygon,[[9.75,17.625],[14.25,17.625],[14.25,18.375],[9.75,18.375]]);assert.deepEqual(result.record.footprint,rect(9.75,17.625,14.25,18.375));
 assert.deepEqual(result.exact.clearancePolygon,[[8.625,17.25],[15.375,17.25],[15.375,18.75],[8.625,18.75]]);assert.deepEqual(result.record.clearance,rect(8.625,17.25,15.375,18.75));
 const body=result.record.collision.worldBodies[0];assert.deepEqual(body.polygonCR,[[9.75,17.625],[14.25,17.625],[14.25,18],[9.75,18]]);assert.deepEqual(body.rectangleRC,{...rect(9.75,17.625,14.25,18),conservativeRectangle:false});assert.equal(body.minYM,2);assert.equal(body.maxYM,14.3);
 assert.deepEqual(result.record.entry.anchorRC,{r:18.375,c:12});assert.deepEqual(result.record.entry.roadProbeRC,{r:19.875,c:12});
 assert.deepEqual(result.exact.corridorPolygon,[[11.55,18.3],[12.45,18.3],[12.45,19.95],[11.55,19.95]]);assert.deepEqual(result.record.entryCorridor,rect(11.55,18.3,12.45,19.95));
});

test('road access reconnects deterministically and rebuilds the exact corridor',()=>{
 const map=topology();map.roadMask[20][12]=1;map.grid[20][12]=0;
 const result=deriveMovedBuilding({trustedBase:base,nextTransform:at(0),topology:map});
 assert.equal(result.ok,true);assert.deepEqual(result.record.entry.roadProbeRC,{r:20,c:12});assert.deepEqual(result.record.entryCorridor,rect(11.7,18.5,12.3,20));assert.deepEqual(result.exact.corridorPolygon,[[11.7,18.5],[12.3,18.5],[12.3,20],[11.7,20]]);
});

test('protected and water cells reject footprint and entry path',()=>{
 const protectedFootprint=topology();protectedFootprint.protectedMask[17][12]=1;assert.equal(deriveMovedBuilding({trustedBase:base,nextTransform:at(0),topology:protectedFootprint}).code,'BUILDING_ON_PROTECTED');
 const waterFootprint=topology();waterFootprint.grid[17][12]=16;assert.equal(deriveMovedBuilding({trustedBase:base,nextTransform:at(0),topology:waterFootprint}).code,'BUILDING_ON_WATER');
 const protectedPath=topology();protectedPath.protectedMask[19][12]=1;assert.deepEqual(deriveMovedBuilding({trustedBase:base,nextTransform:at(0),topology:protectedPath}),{ok:false,code:'ENTRY_PATH_BLOCKED',message:'Проход от входа пересекает воду или защищённую область',details:{r:19,c:12}});
 const waterPath=topology();waterPath.grid[19][12]=16;assert.deepEqual(deriveMovedBuilding({trustedBase:base,nextTransform:at(0),topology:waterPath}),{ok:false,code:'ENTRY_PATH_BLOCKED',message:'Проход от входа пересекает воду или защищённую область',details:{r:19,c:12}});
});

test('missing straight road access is rejected',()=>{
 const result=deriveMovedBuilding({trustedBase:base,nextTransform:at(0),topology:topology()});
 assert.equal(result.ok,false);assert.equal(result.code,'NO_STRAIGHT_ROAD_ACCESS');
});

test('building, foreign entry and parking overlaps have stable diagnostics',()=>{
 const building={id:'HOUSE-B',footprint:rect(13.5,17,15,19),clearance:rect(12.75,17.6,14,18.4)};
 const buildingResult=deriveMovedBuilding({trustedBase:base,nextTransform:at(0),otherInstances:[building]});assert.equal(buildingResult.code,'BUILDING_OVERLAP');assert.deepEqual(buildingResult.details,{otherId:'HOUSE-B'});
 const foreignEntry={id:'HOUSE-C',footprint:rect(20,20,21,21),entryCorridor:rect(12.8,17.7,13.2,20)};
 const entryResult=deriveMovedBuilding({trustedBase:base,nextTransform:at(0),otherInstances:[foreignEntry]});assert.equal(entryResult.code,'BLOCKS_OTHER_ENTRY');assert.deepEqual(entryResult.details,{otherId:'HOUSE-C'});
 const parking={id:'PARK-1',rect:{minX:12.5*M,minZ:17.7*M,maxX:14*M,maxZ:19*M}};
 const parkingResult=deriveMovedBuilding({trustedBase:base,nextTransform:at(0),parkingKeepouts:[parking]});assert.equal(parkingResult.code,'PARKING_OVERLAP');assert.deepEqual(parkingResult.details,{parkingId:'PARK-1'});
});

test('compiler never mutates inputs and repeated compilation is deterministic',()=>{
 const trustedBase=structuredClone(base),next=at(270),map=topology(),others=[{id:'FAR',footprint:rect(25,25,26,26)}],parking=[{id:'FAR-PARK',rectCR:rect(30,30,31,31)}];map.roadMask[18][9]=1;map.grid[18][9]=0;
 const snapshots=[trustedBase,next,map,others,parking].map(value=>structuredClone(value));
 const first=deriveMovedBuilding({trustedBase,nextTransform:next,topology:map,otherInstances:others,parkingKeepouts:parking}),second=deriveMovedBuilding({trustedBase,nextTransform:next,topology:map,otherInstances:others,parkingKeepouts:parking});
 assert.equal(first.ok,true);assert.deepEqual(first,second);assert.equal(JSON.stringify(first),JSON.stringify(second));
 for(const [index,value] of [trustedBase,next,map,others,parking].entries())assert.deepEqual(value,snapshots[index]);
});

test('invalid transforms and non-cardinal yaw fail before producing a record',()=>{
 assert.equal(deriveMovedBuilding({trustedBase:base,nextTransform:at(0,{uniformScale:0})}).code,'INVALID_BUILDING_TRANSFORM');
 assert.equal(deriveMovedBuilding({trustedBase:base,nextTransform:at(0,{positionM:[NaN,0,0]})}).code,'INVALID_BUILDING_TRANSFORM');
 assert.equal(deriveMovedBuilding({trustedBase:base,nextTransform:at(15)}).code,'UNSUPPORTED_BUILDING_YAW');
});

test('detention remains a guarded full-rebuild special case',()=>{
 const detention={...structuredClone(base),id:'DET-A',assetId:'police_station',role:'district_detention',compactSite:true,detentionId:'test-lockup',stopFootprint:rect(9.4,21,10.6,21.6),stopLane:rect(8.8,20.9,11.2,21.8),stopLocalZ:17},snapshot=structuredClone(detention);
 const denied=deriveMovedBuilding({trustedBase:detention,nextTransform:at(90)});assert.equal(denied.code,'FULL_REBUILD_REQUIRED');assert.deepEqual(detention,snapshot);
 const allowed=deriveMovedBuilding({trustedBase:detention,nextTransform:at(90),allowSpecialFullRebuild:true});assert.equal(allowed.ok,true);assert.equal(allowed.requiresFullRebuild,true);assert.deepEqual(detention,snapshot);
});

test('point projection fixture documents the yaw convention',()=>{
 assert.deepEqual(transformBuildingPointCR([11,20],BASE_TRANSFORM,at(90),M),[12,17]);
});
