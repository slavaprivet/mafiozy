import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {mapProjection} from './exploration_minimap.mjs';

// Exercise the production atlas painter, including cache reuse and rebuilds.
// Canvas commands are recorded; no GPU, DOM or duplicate projection is used.
const source=await readFile(new URL('./exploration_minimap.mjs',import.meta.url),'utf8');
const helpers=source.slice(0,source.indexOf('const css=')).replaceAll('export ','');
const path=source.slice(source.indexOf('  function path('),source.indexOf('  function rebuild('));
const drawBase=source.slice(source.indexOf('  function drawBase('),source.indexOf('  function resize('));
const marker=source.slice(source.indexOf('  function marker('),source.indexOf('  function draw(force'));
const factory=new Function('state',`${helpers}
  const {world,objects,actx,ctx,atlas,width,height,dpr}=state;
  const objectIndex=createMapObjectIndex(objects);let viewCache=null,atlasScale=1,expanded=false;
  ${path}${marker}${drawBase}
  return (center,mpp,large=false)=>{expanded=large;drawBase(mapProjection({center,width,height,metresPerPixel:mpp}),mpp);};
`);
const building={id:'home',name:'Дом',kind:'residential',building:true,x:610.4,z:83.7,polygon:[[602,78],[618,78],[618,90],[602,90]]};
const road=[{x:591,z:72},{x:638,z:72}];
let frames=0;
for(const dpr of [1,1.25,2])for(const initialMpp of [180/228,1.7]){
  let ink=[],blit=null,rebuilds=0;
  const actx=new Proxy({setTransform(){ink=[];rebuilds++;}}, {get(target,key){return target[key]??((...args)=>ink.push({key,args}));},set(target,key,value){target[key]=value;return true;}});
  const ctx={drawImage(...args){blit=args;}};
  const width=228,height=194,atlas={width:0,height:0};
  const world={bounds:{minX:0,maxX:738,minZ:0,maxZ:820},regions:[],water:[],roads:[{points:road,width:8}],trails:[],railways:[]};
  const frame=factory({world,objects:[building],actx,ctx,atlas,width,height,dpr});
  const samples=[{x:610.907,z:82.689},{x:611.137,z:83.049},{x:619.231,z:90.711},{x:720.111,z:90.111},{x:610.907,z:82.689}];
  for(const [index,center] of samples.entries()){
    const before=rebuilds;frame(center,initialMpp);frames++;
    if(index===1)assert.equal(rebuilds,before,'ordinary steps reuse the static atlas');
    const icon=ink.find(command=>command.key==='translate');
    assert.ok(icon,'building badge must be painted into the road atlas');
    const roadInk=ink.find(command=>command.key==='moveTo');
    const pr=mapProjection({center,width,height,metresPerPixel:initialMpp});
    for(const [paint,worldPoint] of [[icon,building],[roadInk,road[0]]]){
      const expected=pr.toScreen(worldPoint);
      assert.ok(Math.abs(paint.args[0]+blit[1]-expected.x)<1e-8,'static X aligns after fractional scrolling / cache rebuild');
      assert.ok(Math.abs(paint.args[1]+blit[2]-expected.y)<1e-8,'static Y aligns after fractional scrolling / cache rebuild');
    }
    const pointer=pr.toScreen(building);
    const hit=pr.toWorld(pointer);
    assert.ok(Math.hypot(hit.x-building.x,hit.z-building.z)<1e-8,'hover and waypoint coordinates retain the same projection');
  }
  const before=rebuilds;frame(samples[0],initialMpp,true);
  assert.equal(rebuilds,before+1,'expanded-only symbols refresh even at an unchanged scale');
}
console.log(`PASS minimap static alignment: ${frames} frames, fractional steps, 3 DPRs, cache reuse/rebuild, expanded mode and pointer projection.`);
