import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {planDecor} from './decor_placement.mjs';
import {pointInPolygon} from './topology.mjs';
const here=path.dirname(fileURLToPath(import.meta.url)),hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const read=name=>JSON.parse(fs.readFileSync(path.join(here,name)));
const topology=read('topology_for_placement.json'),catalog=read('decor_catalog.v1.json'),infra=read('infrastructure_catalog.v1.json');
const buildingName=process.argv[2]||'buildings_placement.v1.json';
if(!fs.existsSync(path.join(here,buildingName)))throw Error('Required final building footprints/doors not delivered yet: '+buildingName);
const buildings=read(buildingName),placed=buildings.instances;
if(!Array.isArray(placed)||!placed.length)throw Error('Building ledger missing instances');
const grid=topology.grid,m=topology.map.worldUnitsPerCell;
const cells=[];for(let r=0;r<200;r++)for(let c=0;c<180;c++)if(topology.policeMask[r][c])cells.push({r,c});
function rect(b){return b&&['minR','maxR','minC','maxC'].every(k=>Number.isFinite(b[k]))?b:null;}
const host={metresPerCell:m,ledgerComplete:true,policeProtectedCells:cells,
 doorCorridors:placed.map(x=>rect(x.entryCorridor)).filter(Boolean),buildingFootprints:placed.map(x=>rect(x.clearance)||rect(x.footprint)).filter(Boolean),
 railKeepouts:topology.crossings.filter(x=>x.no_build_envelope_polygon_grid_cr).map(x=>bbox(x.no_build_envelope_polygon_grid_cr)),
 placementKeepouts:topology.crossings.filter(x=>x.layer==='bridge_deck').map(x=>bbox(x.deck_envelope_polygon_grid_cr)),assetAdapters:infra.lampAdapters};
if(host.buildingFootprints.length!==placed.length||host.doorCorridors.length!==placed.length)throw Error('Every building needs footprint/entry corridor');
function bbox(p){return {minR:Math.min(...p.map(x=>x[1])),maxR:Math.max(...p.map(x=>x[1])),minC:Math.min(...p.map(x=>x[0])),maxC:Math.max(...p.map(x=>x[0]))};}
const overlaps=(a,b)=>a.minR<b.maxR&&a.maxR>b.minR&&a.minC<b.maxC&&a.maxC>b.minC;
const dist=Array.from({length:200},()=>Array(180).fill(1e6)),queue=[];
for(let r=0;r<200;r++)for(let c=0;c<180;c++)if(topology.roadMask[r][c]){dist[r][c]=0;queue.push([r,c]);}
for(let i=0;i<queue.length;i++){const[r,c]=queue[i];for(const[dr,dc]of[[1,0],[-1,0],[0,1],[0,-1]]){const rr=r+dr,cc=c+dc;if(rr>=0&&rr<200&&cc>=0&&cc<180&&dist[rr][cc]>dist[r][c]+1){dist[rr][cc]=dist[r][c]+1;queue.push([rr,cc]);}}}
const anchors=[],reserved=[...host.buildingFootprints,...host.doorCorridors,...host.railKeepouts],findings=[];
function choose(district,assetId,id,target,maxDistance=35){
 const asset=catalog.entries.find(x=>x.assetId===assetId),scale=asset.kind==='fountain'?(assetId==='fountain_central'?1.22:1.3):1.15;
 const hw=asset.clearanceM[0]*scale/m/2,hd=asset.clearanceM[1]*scale/m/2,candidates=[];
 for(let r=1;r<199;r++)for(let c=1;c<179;c++){
   if(![8,9,14].includes(grid[r][c])||dist[r][c]>7||dist[r][c]<2||!pointInPolygon([c+.5,r+.5],district.polygon_grid))continue;
   const distance=Math.hypot(r+.5-target[1],c+.5-target[0]);if(distance>maxDistance)continue;
   candidates.push({r:r+.5,c:c+.5,score:distance+Math.abs(dist[r][c]-3)*.4});
 }
 candidates.sort((a,b)=>a.score-b.score||a.r-b.r||a.c-b.c);
 for(const p of candidates){const b={minR:p.r-hd,maxR:p.r+hd,minC:p.c-hw,maxC:p.c+hw};if(reserved.some(x=>overlaps(x,b)))continue;
   let bad=false;for(let r=Math.floor(b.minR);r<Math.ceil(b.maxR)&&!bad;r++)for(let c=Math.floor(b.minC);c<Math.ceil(b.maxC);c++)if(!grid[r]||![8,9,14].includes(grid[r][c])||topology.protectedMask[r][c]){bad=true;break;}if(bad)continue;
   const a={id,assetId,r:p.r,c:p.c,yawDegrees:0,uniformScale:scale};
   const test=planDecor({topology,catalog,host,anchors:[a],executionScope:'isolated_walk_preview',includeSurfaces:false});if(test.errors.length)continue;
   anchors.push(a);reserved.push(b);return a;
 }
 findings.push({id,code:'NO_SAFE_NEAR_ROAD_PARK_SPACE',district:district.id,assetId});return null;
}
for(const[dIndex,d]of topology.districts.entries()){
 const fountainId=d.id==='central_district'?'fountain_central':dIndex%2?'fountain_district':'fountain_park';
 const fountain=choose(d,fountainId,`PARK-${d.id}-FOUNTAIN`,d.center_grid);
 if(!fountain)continue;
 for(const[i,delta]of [[-3,0],[3,0],[0,3]].entries())choose(d,'bench_civic',`PARK-${d.id}-BENCH-${i+1}`,[fountain.c+delta[0],fountain.r+delta[1]],5);
 choose(d,'planter_round',`PARK-${d.id}-PLANTER`,[fountain.c+2.8,fountain.r-2.8],5);
 choose(d,'bin_civic',`PARK-${d.id}-BIN`,[fountain.c-2.8,fountain.r-2.8],5);
}
const family=d=>d.id==='north_hills'?'lamp_pine_v1':['iron_harbor','southside'].includes(d.id)?'lamp_foundry_v1':['old_town','chinatown'].includes(d.id)?'lamp_bellini_v1':'lamp_civic_double_v1';
const regions=topology.districts.map(d=>({...bbox(d.polygon_grid),polygonCR:d.polygon_grid,assetId:family(d),maxCount:16,id:d.id}));
const plan=planDecor({topology,catalog,host,anchors,executionScope:'isolated_walk_preview',lampPolicy:{enabled:true,maxCount:128,spacingCells:8,setbackCells:.3,maxRoadDistanceCells:2,regions}});
if(plan.errors.length)throw Error('Final decor rejected '+JSON.stringify(plan.errors));
plan.scope='isolated_walk_preview';plan.buildingsSource={file:buildingName,sha256:hash(fs.readFileSync(path.join(here,buildingName))),instances:placed.length};
plan.topologySource={file:'topology_for_placement.json',sha256:hash(fs.readFileSync(path.join(here,'topology_for_placement.json')))};
plan.infrastructureSource={file:'infrastructure_catalog.v1.json',sha256:hash(fs.readFileSync(path.join(here,'infrastructure_catalog.v1.json')))};
plan.materialDescriptors=infra.roadMaterials.materialDescriptors;
plan.surfaces[0].materialBinding='MAT_CLAY_ASPHALT_CLEAN';plan.surfaces[0].materialDescriptor=plan.materialDescriptors.find(x=>x.id==='MAT_CLAY_ASPHALT_CLEAN');
plan.asphaltRects=plan.surfaces[0].rectangles;plan.generationFindings=findings;
plan.bridgeFitReport=topology.crossings.filter(x=>x.layer==='bridge_deck').map(x=>{const a=x.centerline_grid_cr[0],b=x.centerline_grid_cr.at(-1),span=Math.hypot(b[0]-a[0],b[1]-a[1])*m;return {crossingId:x.id,status:x.id==='XR-RED-01'?'PRESERVE_EXISTING_PREMIUM_BRIDGE':'NO_SINGLE_READY_GLB_FITS',requiredSpanM:span,availableMiniBridgeSpanM:9,requiredUniformScale:span/9,reason:x.id==='XR-RED-01'?'Never replace red bridge':'Mini bridge is only9m, cannot represent this full-size crossing with safe uniform scale; no fake GLB placement emitted'};});
plan.counts={instances:plan.instances.length,lamps:plan.instances.filter(x=>x.role==='roadside_lamp').length,fountains:plan.instances.filter(x=>x.assetId.startsWith('fountain')).length,asphaltRects:plan.asphaltRects.length,asphaltCells:plan.surfaces[0].cellCount};
fs.writeFileSync(path.join(here,'decor_placement.v1.json'),JSON.stringify(plan,null,2)+'\n');console.log(JSON.stringify(plan.counts));
