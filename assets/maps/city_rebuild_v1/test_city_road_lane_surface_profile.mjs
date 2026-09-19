import test from 'node:test';import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';
import {waterfrontLaneInset} from './city_road_lane_surface_profile.mjs';
import {createCarWorld,carFits} from './car_drive.mjs';
const path={id:'A-WATERFRONT-W',segments:[{a:{x:166.05,z:617.05},b:{x:260.35,z:617.05},tx:1,tz:0,start:70,length:94.3}]};
test('the waterfront outer lane fits the native straight with room for the unchanged inner lane',()=>{
 const topology=JSON.parse(readFileSync(new URL('topology_for_placement.json',import.meta.url))),surfaceAt=(x,z)=>!!topology.roadMask[Math.floor(z/4.1)]?.[Math.floor(x/4.1)],world=createCarWorld(topology,[],4.1,{surfaceAt});
 assert.equal(carFits(259.9748956366,622.585,Math.PI/2,world),false,'the former rear corner reaches footpath row152');
 for(let x=175;x<=260;x+=.02){const inset=waterfrontLaneInset(path,70+x-166.05,1,1),z=622.585-inset;assert.ok(z-618.895>=2.9);assert.ok(carFits(x,z,Math.PI/2,world));assert.ok(carFits(x,618.895,Math.PI/2,world));}
});
test('the surface profile preserves other lanes and blends only around the authored straight',()=>{
 for(const progress of [0,58,60,70,100,164.3,170,176.3,200]){assert.equal(waterfrontLaneInset(path,progress,-1,1),0);assert.equal(waterfrontLaneInset(path,progress,1,0),0);assert.equal(waterfrontLaneInset({...path,id:'A-WATERFRONT-E'},progress,1,1),0);}
 assert.equal(waterfrontLaneInset(path,58,1,1),0);assert.equal(waterfrontLaneInset(path,100,1,1),.78);assert.equal(waterfrontLaneInset(path,176.3,1,1),0);
 assert.ok(Math.abs(waterfrontLaneInset(path,70.0001,1,1)-waterfrontLaneInset(path,69.9999,1,1))<1e-8);
});
