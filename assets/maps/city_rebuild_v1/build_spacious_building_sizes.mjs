// Construction-time candidate builder. Running this file writes only a review
// candidate/report under outputs; it never overwrites live placement JSON.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {cellsForRect,rectanglesOverlap as overlap} from './building_placement.mjs';

const M=4.1,EPS=1e-7;
const polygon=r=>[[r.minC,r.minR],[r.maxC,r.minR],[r.maxC,r.maxR],[r.minC,r.maxR]];
const bounds=ps=>({minC:Math.min(...ps.map(p=>p[0])),minR:Math.min(...ps.map(p=>p[1])),maxC:Math.max(...ps.map(p=>p[0])),maxR:Math.max(...ps.map(p=>p[1]))});
const area=r=>(r.maxC-r.minC)*(r.maxR-r.minR);
const rectFromPoly=p=>p?.length?bounds(p):null;
const protectedInstance=i=>i.bankLayout||i.role==='bank_shell'||i.transform.preserveSiteBounds||/bank_|hospital|civic_hall|police|red_bridge/.test(i.assetId)||i.gameplayId;
function inside(c,r,p){let result=false;for(let i=0,j=p.length-1;i<p.length;j=i++){const a=p[i],b=p[j];if((a[1]>r)!==(b[1]>r)&&c<(b[0]-a[0])*(r-a[1])/(b[1]-a[1])+a[0])result=!result}return result}
function offsets(limit,step,footprint){const out=[],seen=new Set();const add=(x,z)=>{const d=Math.hypot(x,z),key=`${x.toFixed(5)},${z.toFixed(5)}`;if(d<=limit+EPS&&!seen.has(key)){seen.add(key);out.push({x,z,distance:d})}};add(0,0);for(let z=-limit;z<=limit+EPS;z+=step)for(let x=-limit;x<=limit+EPS;x+=step)add(x,z);const local=Math.min(limit,6);for(let z=-local;z<=local+EPS;z+=.5)for(let x=-local;x<=local+EPS;x+=.5)add(x,z);
 // Snap envelope edges to terrain-cell boundaries. A regular 2m search can
 // miss a perfectly safe but narrow interval in a 4.1m cell-aligned parcel.
 if(footprint){const xs=[0],zs=[0];for(const [values,a,b]of[[xs,footprint.minC,footprint.maxC],[zs,footprint.minR,footprint.maxR]])for(let k=Math.floor(a-limit/M);k<=Math.ceil(b+limit/M);k++){for(const v of[(k-a+.00001)*M,(k-b-.00001)*M])if(Math.abs(v)<=limit)values.push(v)}for(const x of xs)for(const z of zs)add(x,z)}return out.sort((a,b)=>a.distance-b.distance||a.z-b.z||a.x-b.x)}
function subtractRect(a,b){if(!overlap(a,b))return[a];const c0=Math.max(a.minC,b.minC),c1=Math.min(a.maxC,b.maxC),r0=Math.max(a.minR,b.minR),r1=Math.min(a.maxR,b.maxR);return[{minC:a.minC,minR:a.minR,maxC:a.maxC,maxR:r0},{minC:a.minC,minR:r1,maxC:a.maxC,maxR:a.maxR},{minC:a.minC,minR:r0,maxC:c0,maxR:r1},{minC:c1,minR:r0,maxC:a.maxC,maxR:r1}].filter(r=>r.maxC-r.minC>EPS&&r.maxR-r.minR>EPS)}

function transformCandidate(old,fx,fz,offset,yawOffset=0,clearancePadding=null){
 const item=structuredClone(old),t=old.transform,yaw=t.yawDegrees*Math.PI/180,co=Math.cos(yaw),si=Math.sin(yaw),newYaw=(t.yawDegrees+yawOffset)*Math.PI/180,nco=Math.cos(newYaw),nsi=Math.sin(newYaw),oldC=t.positionM[0]/M,oldR=t.positionM[2]/M,newC=oldC+offset.x/M,newR=oldR+offset.z/M;
 const convert=([c,r])=>{const x=(c-oldC)*co-(r-oldR)*si,z=(c-oldC)*si+(r-oldR)*co;return[newC+x*fx*nco+z*fz*nsi,newR-x*fx*nsi+z*fz*nco]};
 const convertRect=r=>bounds(polygon(r).map(convert)),oldScale=t.horizontalScale??[1,1];
 item.transform.positionM=[t.positionM[0]+offset.x,t.positionM[1],t.positionM[2]+offset.z];item.transform.horizontalScale=[oldScale[0]*fx,oldScale[1]*fz];item.transform.yawDegrees=(t.yawDegrees+yawOffset)%360;
 item.footprint=convertRect(old.footprint);
 const pad={left:clearancePadding??old.footprint.minC-old.clearance.minC,right:clearancePadding??old.clearance.maxC-old.footprint.maxC,back:clearancePadding??old.footprint.minR-old.clearance.minR,front:clearancePadding??old.clearance.maxR-old.footprint.maxR};
 item.clearance={minC:item.footprint.minC-pad.left,maxC:item.footprint.maxC+pad.right,minR:item.footprint.minR-pad.back,maxR:item.footprint.maxR+pad.front};
 const [c,r]=convert([old.entry.anchorRC.c,old.entry.anchorRC.r]);item.entry.anchorRC={c,r};
 item.collision.worldBodies=old.collision.worldBodies.map(b=>({...b,polygonCR:b.polygonCR.map(convert),...(b.rectangleRC?{rectangleRC:convertRect(b.rectangleRC)}:{})}));
 return{item,convert};
}

/** Resize only buildings whose narrowest actual floor needs room. Local
 * translations are capped in metres; no district-wide repacking takes place.
 * The caller must review blocked candidates and scale-cap exceptions. */
export function buildSpaciousBuildingSizes({base,topology,fixtures,source,decor={instances:[]},ledger={rows:[]},minimumFloorWidth=7,minimumWidthFallbacks=[],maximumLocalMoveM=12,searchStepM=1,maxRuntimeScale=3,allowQuarterTurns=false,allowStairRefitFallback=false,onlyInstanceIds=null,clearancePadding=null,preferNearest=false,relativeDepthOverrides={},authoredOpeningWidths={}}={}){
 if(!base?.instances?.length||!topology?.grid||!topology.protectedMask||!Array.isArray(fixtures)||!source?.districts?.length)throw Error('Spacious sizing requires placement, validated topology, actual floor fixtures and district source');
 if(topology.status==='REJECTED')throw Error('Rejected topology cannot authorize placement');
 if(!Number.isFinite(minimumFloorWidth)||minimumFloorWidth<2||!Number.isFinite(maximumLocalMoveM)||maximumLocalMoveM<0||!Number.isFinite(searchStepM)||searchStepM<=0||minimumWidthFallbacks.some(w=>!Number.isFinite(w)||w<2||w>minimumFloorWidth))throw Error('Invalid bounded sizing search parameters');
 const plan=structuredClone(base),fixturesById=new Map(),audit=[];
 for(const f of fixtures){if(!fixturesById.has(f.instanceId))fixturesById.set(f.instanceId,[]);fixturesById.get(f.instanceId).push(f)}
 const protectedRects=base.protectedRects??[],reservations=(ledger.rows??[]).filter(r=>Array.isArray(r.plannedRC)&&/^(bank|business|poi):/.test(r.id)).map(r=>({id:r.id,minR:r.plannedRC[0]-2.5,maxR:r.plannedRC[0]+2.5,minC:r.plannedRC[1]-2.5,maxC:r.plannedRC[1]+2.5}));
 const decorRects=(decor.instances??[]).map(i=>({id:i.id,rect:rectFromPoly(i.clearancePolygonCR)})).filter(i=>i.rect);
 const landProblems=(r,allowed)=>{const problems=[];for(const p of cellsForRect(r)){const tile=topology.grid[p.r]?.[p.c];if(!allowed.includes(tile))problems.push({kind:'terrain',r:p.r,c:p.c,tile:tile??null});if(topology.protectedMask[p.r]?.[p.c])problems.push({kind:'protected_cell',r:p.r,c:p.c})}return problems};
 const requests=[];
 for(const old of base.instances){
  if(onlyInstanceIds&&!onlyInstanceIds.includes(old.id)){audit.push({id:old.id,assetId:old.assetId,status:'frozen_reviewed_candidate'});continue}
  const floors=fixturesById.get(old.id);if(!floors?.length){audit.push({id:old.id,assetId:old.assetId,status:'missing_actual_fixtures'});continue}
  if(protectedInstance(old)){audit.push({id:old.id,assetId:old.assetId,status:'preserved_anchor_or_bank'});continue}
  const minWidth=Math.min(...floors.map(f=>f.rect[2]-f.rect[0])),minDepth=Math.min(...floors.map(f=>f.rect[3]-f.rect[1])),fx=Math.max(1,minimumFloorWidth/minWidth),fz=relativeDepthOverrides[old.id]??(old.assetId==='eastside_stepped_apartment_v1'?1.38:old.assetId==='glass_pavilion_small_v1'?1.64:1);
  if(!Number.isFinite(fz)||fz<.5||fz>3)throw Error('Invalid reviewed relative depth scale for '+old.id);
  if(fx<1+EPS&&fz<1+EPS){audit.push({id:old.id,assetId:old.assetId,status:'already_spacious',minWidth,minDepth});continue}
  requests.push({old,floors,minWidth,minDepth,fx,fz,growth:area(old.footprint)*(fx*fz-1)});
 }
 const changes=[],unresolvedById=new Map();requests.sort((a,b)=>b.growth-a.growth||a.old.id.localeCompare(b.old.id));
 for(let pass=0;pass<3;pass++){
 const countBefore=changes.length;
 for(const request of requests.filter(r=>!changes.some(c=>c.id===r.old.id))){
  const {old,minWidth,minDepth}=request,district=source.districts.find(d=>d.id===old.districtId),other=plan.instances.filter(i=>i.id!==old.id),blockers=protectedRects.concat(reservations.filter(r=>r.id!==old.gameplayId)),failures=new Map();let accepted=null,atOrigin=[],fx=request.fx,fz=request.fz,selectedMinimumWidth=minimumFloorWidth,selectedYawOffset=0;
  const record=problems=>{for(const p of problems){const key=p.kind+(p.id?':'+p.id:'');failures.set(key,(failures.get(key)??0)+1)}};
  sizing:for(const localLimit of preferNearest?[...new Set([0,6,12,24,40,maximumLocalMoveM].filter(d=>d<=maximumLocalMoveM))]:[maximumLocalMoveM]){
  for(const depthFactor of [request.fz,...(allowStairRefitFallback&&request.fz>1?[1.15,1]:[])]){
  fz=depthFactor;
  for(const goalWidth of [minimumFloorWidth,...minimumWidthFallbacks]){
  fx=Math.max(1,goalWidth/minWidth);selectedMinimumWidth=goalWidth;
  for(const yawOffset of allowQuarterTurns?[0,180,90,270]:[0]){
  selectedYawOffset=yawOffset;
  const probe=transformCandidate(old,fx,fz,{x:0,z:0},yawOffset,clearancePadding).item,candidateOffsets=offsets(localLimit,searchStepM,probe.footprint);
  for(const offset of candidateOffsets){
   const {item}=transformCandidate(old,fx,fz,offset,yawOffset,clearancePadding),problems=landProblems(item.footprint,[8]);
   if(!district||!polygon(item.footprint).every(([c,r])=>inside(c,r,district.polygon_grid)))problems.push({kind:'district_boundary'});
   for(const b of blockers)if(overlap(item.footprint,b))problems.push({kind:'protected_reservation',id:b.id});
   for(const b of other)if(overlap(item.clearance,b.clearance)||overlap(item.footprint,b.entryCorridor))problems.push({kind:'building_clearance_or_entry',id:b.id});
   for(const b of decorRects)if(overlap(item.footprint,b.rect))problems.push({kind:'decor_clearance',id:b.id});
   if(!offset.distance)atOrigin=problems.slice(0,40);
   if(problems.length){record(problems);continue}
   const door=item.entry.anchorRC,oldDc=old.entry.roadProbeRC.c-old.entry.anchorRC.c,oldDr=old.entry.roadProbeRC.r-old.entry.anchorRC.r,angle=yawOffset*Math.PI/180,dc=oldDc*Math.cos(angle)+oldDr*Math.sin(angle),dr=-oldDc*Math.sin(angle)+oldDr*Math.cos(angle),nc=Math.abs(dc)>Math.abs(dr)?Math.sign(dc):0,nr=nc?0:Math.sign(dr);
   const edge={c:nc>0?item.footprint.maxC:nc<0?item.footprint.minC:door.c,r:nr>0?item.footprint.maxR:nr<0?item.footprint.minR:door.r};let end=null;
   for(let t=.25;t<=12;t+=.25){const p={c:edge.c+nc*t,r:edge.r+nr*t},tile=topology.grid[Math.floor(p.r)]?.[Math.floor(p.c)];if(![0,8,9].includes(tile)||topology.protectedMask[Math.floor(p.r)]?.[Math.floor(p.c)])break;if(tile===0){end=p;break}}
   if(!end){record([{kind:'no_dry_road_connection'}]);continue}
   const oldNr=Math.abs(oldDr)>Math.abs(oldDc),oldWidth=oldNr?old.entryCorridor.maxC-old.entryCorridor.minC:old.entryCorridor.maxR-old.entryCorridor.minR,measuredOpening=authoredOpeningWidths[old.id],half=Number.isFinite(measuredOpening)?Math.max(1.2,measuredOpening*item.transform.horizontalScale[0]*(item.transform.uniformScale??1)/2+.4)/M:Math.max(1.2/M,oldWidth/2*(oldNr?Math.abs(Math.cos(old.transform.yawDegrees*Math.PI/180))*fx+Math.abs(Math.sin(old.transform.yawDegrees*Math.PI/180))*fz:Math.abs(Math.sin(old.transform.yawDegrees*Math.PI/180))*fx+Math.abs(Math.cos(old.transform.yawDegrees*Math.PI/180))*fz));
   const corridor=nr?{minC:door.c-half,maxC:door.c+half,minR:Math.min(door.r,end.r)-.05,maxR:Math.max(door.r,end.r)+.05}:{minC:Math.min(door.c,end.c)-.05,maxC:Math.max(door.c,end.c)+.05,minR:door.r-half,maxR:door.r+half};
   const bad=landProblems(corridor,[0,8,9]);for(const b of blockers)if(overlap(corridor,b))bad.push({kind:'entry_protected_reservation',id:b.id});for(const b of other)if(overlap(corridor,b.footprint))bad.push({kind:'entry_building',id:b.id});for(const b of decorRects)if(overlap(corridor,b.rect))bad.push({kind:'entry_decor',id:b.id});if(bad.length){record(bad);continue}
   item.entryCorridor=corridor;item.entry.roadProbeRC=end;
   // Retain existing heights and collider metadata. Only subtract the newly
   // verified entry strip from transformed conservative exterior envelopes.
   item.collision.worldBodies=item.collision.worldBodies.flatMap(b=>b.rectangleRC?subtractRect(b.rectangleRC,corridor).map(r=>({...b,rectangleRC:r,polygonCR:polygon(r)})):[b]);
   item.roomSizing={...old.roomSizing,source:'2026-09-12 user requested spacious interiors; reviewed candidate required',exteriorAndInterior:true,previousPositionM:old.transform.positionM.slice(),relativeScale:[fx,fz],minimumFloorWidth:goalWidth,requestedMinimumFloorWidth:minimumFloorWidth,stairRefitRequired:fz<request.fz,areaMultiplier:(old.roomSizing?.areaMultiplier??1)*fx*fz};
   accepted={item,offset};break sizing;
  }
  }
  }
  }
  }
  const targetScale=(old.transform.horizontalScale??[1,1]).map((s,i)=>s*(i?fz:fx)),row={id:old.id,assetId:old.assetId,minWidthBefore:minWidth,minWidthRequested:minimumFloorWidth,minWidthSelected:selectedMinimumWidth,minWidthTarget:minWidth*fx,minDepthBefore:minDepth,minDepthTarget:minDepth*fz,relativeScale:[fx,fz],targetScale,yawOffset:selectedYawOffset,stairRefitRequired:fz<request.fz,runtimeScaleCapExceeded:targetScale.some(s=>s>maxRuntimeScale),attempts:[...failures.values()].reduce((a,b)=>a+b,0),originProblems:atOrigin};
  if(accepted){Object.assign(plan.instances.find(i=>i.id===old.id),accepted.item);changes.push({...row,status:'candidate_ready',movedMetres:accepted.offset.distance,positionM:accepted.item.transform.positionM});unresolvedById.delete(old.id)}
  else unresolvedById.set(old.id,{...row,status:'no_safe_local_fit',reasons:[...failures].sort((a,b)=>b[1]-a[1]).slice(0,12).map(([reason,candidates])=>({reason,candidates})),suggestion:'Review a wider local parcel or side-positioned staircase; current live placement stays unchanged.'});
 }
 if(changes.length===countBefore)break;
 }
 const unresolved=[...unresolvedById.values()];
 plan.footprints=plan.instances.map(i=>({id:i.id,...i.footprint}));plan.doorCorridors=plan.instances.map(i=>({id:i.id,...i.entryCorridor}));plan.roomSizingRevision='2026-09-12-spacious-dry-candidate';
 const report={status:unresolved.length?'PARTIAL_CANDIDATE_REQUIRES_REVIEW':'CANDIDATE_REQUIRES_ACTUAL_GEOMETRY_AND_LIVE_QA',livePlacementWritten:false,metresPerCell:M,minimumFloorWidth,minimumWidthFallbacks,maximumLocalMoveM,allowQuarterTurns,allowStairRefitFallback,onlyInstanceIds,clearancePadding,preferNearest,relativeDepthOverrides,authoredOpeningWidths,instances:base.instances.length,changed:changes.length,unresolvedCount:unresolved.length,preserved:audit,changes,unresolved,runtimeScaleCapExceptions:changes.filter(c=>c.runtimeScaleCapExceeded).map(c=>c.id),limitations:['Terrain checks use the provided staged topology, not authenticated server occupancy.','No map repaint, gameplay ID migration, protected anchor change or general repacking.','Rebuild actual entry/storey/window colliders and run capsule routes after applying a reviewed candidate.','Loaded game performance and GPU visuals have not been checked.']};
 return{plan,report};
}

if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const here=path.dirname(fileURLToPath(import.meta.url)),root=path.resolve(here,'../../..'),read=p=>JSON.parse(fs.readFileSync(p,'utf8')),basePath=path.join(here,'buildings_placement.v1.json'),base=read(basePath),fixturePath=process.argv[2]??path.join(root,'outputs/interiors_spacious/actual_storey_fixtures.json'),out=path.resolve(process.argv[3]??path.join(root,'outputs/interiors_spacious'));
 if(out===here||out.startsWith(here+path.sep))throw Error('Dry-run output must not target the live asset directory');
 const flags=process.argv.slice(4),moveFlag=flags.find(a=>a.startsWith('--max-move=')),stepFlag=flags.find(a=>a.startsWith('--step=')),fallbackFlag=flags.find(a=>a.startsWith('--width-fallbacks='));
 const start=performance.now(),result=buildSpaciousBuildingSizes({base,topology:read(path.join(here,'topology_for_placement.json')),fixtures:read(fixturePath).fixtures,source:read(base.inputs[1].path),decor:read(path.join(here,'decor_placement.v1.json')),ledger:read(path.join(root,'docs/city-rebuild/rebuild-ledger.generated.json')),allowQuarterTurns:flags.includes('--quarter-turns'),allowStairRefitFallback:flags.includes('--stair-refit-fallback'),...(moveFlag?{maximumLocalMoveM:Number(moveFlag.split('=')[1])}:{}),...(stepFlag?{searchStepM:Number(stepFlag.split('=')[1])}:{}),...(fallbackFlag?{minimumWidthFallbacks:fallbackFlag.split('=')[1].split(',').map(Number)}:{})});
 result.report.cpuConstructionMs=performance.now()-start;result.report.inputs={placementSha256:createHash('sha256').update(fs.readFileSync(basePath)).digest('hex'),fixturesPath:fixturePath};fs.mkdirSync(out,{recursive:true});fs.writeFileSync(path.join(out,'spacious_sizes.candidate.json'),JSON.stringify(result.plan,null,2)+'\n');fs.writeFileSync(path.join(out,'spacious_sizes.report.json'),JSON.stringify(result.report,null,2)+'\n');console.log(JSON.stringify({status:result.report.status,changed:result.report.changed,unresolved:result.report.unresolvedCount,runtimeScaleCapExceptions:result.report.runtimeScaleCapExceptions,cpuConstructionMs:result.report.cpuConstructionMs,output:out},null,2));
}
