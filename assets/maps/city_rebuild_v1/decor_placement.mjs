/** Pure candidate planner. No fetch, scene mutation, gameplay imports or RNG. */
import {pointInPolygon} from './topology.mjs';
const T={road:0,grass:8,sidewalk:9,sand:14,water:16,bridge:19};
const finite=Number.isFinite;
const road=t=>t===T.road||t===T.bridge;
const round=x=>Math.round(x*1e8)/1e8;
const rectangle=(r0,c0,r1,c1)=>[[c0,r0],[c1,r0],[c1,r1],[c0,r1]];
export function polygonsOverlap(a,b) {
  for(const p of[a,b])for(let i=0;i<p.length;i++){
    const q=p[(i+1)%p.length],n=[q[1]-p[i][1],p[i][0]-q[0]];
    const aa=a.map(v=>v[0]*n[0]+v[1]*n[1]),bb=b.map(v=>v[0]*n[0]+v[1]*n[1]);
    if(Math.max(...aa)<=Math.min(...bb)+1e-8||Math.max(...bb)<=Math.min(...aa)+1e-8)return false;
  } return true;
}
function footprint(r,c,w,d,yaw,scale,metres) {
  const a=yaw*Math.PI/180,co=Math.cos(a),si=Math.sin(a);
  return [[-w/2,-d/2],[w/2,-d/2],[w/2,d/2],[-w/2,d/2]].map(([x,z])=>[round(c+(x*co+z*si)*scale/metres),round(r+(-x*si+z*co)*scale/metres)]);
}
function coveredCells(p) {
  const result=[];
  for(let r=Math.floor(Math.min(...p.map(v=>v[1])));r<Math.ceil(Math.max(...p.map(v=>v[1])));r++)
    for(let c=Math.floor(Math.min(...p.map(v=>v[0])));c<Math.ceil(Math.max(...p.map(v=>v[0])));c++)
      if(polygonsOverlap(p,rectangle(r,c,r+1,c+1)))result.push({r,c});
  return result;
}
function validRect(x){return x&&[x.minR,x.maxR,x.minC,x.maxC].every(finite)&&x.minR<x.maxR&&x.minC<x.maxC;}
function cellRect(x){return rectangle(x.r,x.c,x.r+1,x.c+1);}

/** Rectangle surface batching: each native ROAD cell appears exactly once. */
export function batchAsphalt(grid, protectedCells=new Set()) {
  const rectangles=[],active=new Map();
  for(let r=0;r<=grid.length;r++){
    const spans=[];
    if(r<grid.length)for(let c=0;c<grid[r].length;){if(grid[r][c]!==T.road||protectedCells.has(`${r},${c}`)){c++;continue;}const start=c;while(c<grid[r].length&&grid[r][c]===T.road&&!protectedCells.has(`${r},${c}`))c++;spans.push([start,c]);}
    const next=new Map();for(const [c0,c1]of spans){const key=`${c0}:${c1}`,rect=active.get(key)||{minR:r,maxR:r,minC:c0,maxC:c1};rect.maxR=r+1;next.set(key,rect);}
    for(const[k,v]of active)if(!next.has(k))rectangles.push(v);active.clear();for(const[k,v]of next)active.set(k,v);
  } return {kind:'native_road_surface_batch',materialBinding:'host:asphalt',glbInstances:0,rectangles,cellCount:rectangles.reduce((n,x)=>n+(x.maxR-x.minR)*(x.maxC-x.minC),0)};
}

/**
 * host ledger is mandatory even when the candidate presently has no buildings.
 * Host declares all rectangles in RC, half-open. anchors are explicit planner
 * proposals; bad explicit anchors reject the transaction, not silently vanish.
 */
export function planDecor({topology,catalog,host,anchors=[],crossings=[],lampPolicy={},executionScope='isolated_rebuild_preview',includeSurfaces=true}={}) {
  const errors=[],skipped=[],instances=[];
  const result=()=>({schema:'mafiozi.city-rebuild.decor-plan/v1',status:errors.length?'REJECTED':'CANDIDATE_REQUIRES_LIVE_QA',scope:'isolated_rebuild_preview',errors,skipped,
    pendingHostSnapshot:!!topology?.pendingHostSnapshot,productionPhysicsAuthorized:false,
    instances:errors.length?[]:instances,surfaces:errors.length||!includeSurfaces?[]:[batchAsphalt(topology.grid,new Set(host.policeProtectedCells.map(x=>`${x.r},${x.c}`)))],
    activationContract:'Revalidate masks and all bound GLB hashes before atomic scene attach. Failure attaches nothing. No gameplay mutation is authorized by this plan.',
    unresolved:catalog?.missing||[]});
  const pendingIsolated=executionScope==='isolated_walk_preview'&&topology?.status==='ISOLATED_WALK_TOPOLOGY_PENDING_HOST'&&topology.pendingHostSnapshot===true;
  if((topology?.status!=='CANDIDATE_TOPOLOGY_ONLY'&&!pendingIsolated)||!Array.isArray(topology.grid)||topology.grid.length!==topology.map?.rows||topology.grid.some(row=>!Array.isArray(row)||row.length!==topology.map.cols)){errors.push({code:'INVALID_TOPOLOGY'});return result();}
  if(!host||!finite(host.metresPerCell)||host.metresPerCell<=0||host.ledgerComplete!==true||!Array.isArray(host.policeProtectedCells)||!host.policeProtectedCells.length||['doorCorridors','buildingFootprints','railKeepouts'].some(k=>!Array.isArray(host[k])||host[k].some(x=>!validRect(x)))||host.policeProtectedCells.some(x=>!Number.isInteger(x.r)||!Number.isInteger(x.c)||x.r<0||x.c<0||x.r>=topology.map.rows||x.c>=topology.map.cols)){errors.push({code:'INCOMPLETE_HOST_LEDGER'});return result();}
  if(!Array.isArray(catalog?.entries)||new Set(catalog.entries.map(x=>x.assetId)).size!==catalog.entries.length){errors.push({code:'INVALID_CATALOG'});return result();}
  if(host.placementKeepouts&&(!Array.isArray(host.placementKeepouts)||host.placementKeepouts.some(x=>!validRect(x)))){errors.push({code:'INVALID_KEEP_OUTS'});return result();}
  const grid=topology.grid,m=host.metresPerCell;
  const forbidden=[...host.policeProtectedCells.map(p=>({kind:'police',polygon:cellRect(p)})),
    {kind:'immutable_red_bridge',polygon:rectangle(47,78.25,57,101.75)},
    ...['doorCorridors','buildingFootprints','railKeepouts'].flatMap(k=>host[k].map(p=>({kind:k,polygon:rectangle(p.minR,p.minC,p.maxR,p.maxC)}))),
    ...(host.placementKeepouts||[]).map(p=>({kind:'placementKeepouts',polygon:rectangle(p.minR,p.minC,p.maxR,p.maxC)}))];
  const assets=new Map(catalog.entries.map(a=>[a.assetId,a])),ids=new Set();
  function place(a,automatic=false){
    const fail=(code,detail)=>{(automatic?skipped:errors).push({id:a.id,code,...(detail?{detail}:{})});return false;};
    if(!a.id||ids.has(a.id))return fail('DUPLICATE_OR_MISSING_ID');ids.add(a.id);
    const asset=assets.get(a.assetId),scale=a.uniformScale??1,yaw=a.yawDegrees??0;
    if(!asset||asset.stagingStatus!=='bytes_and_contract_nodes_verified')return fail('UNVERIFIED_ASSET');
    if(asset.artAcceptance.status==='rejected')return fail('REJECTED_ART');
    if(asset.assetRole!=='decor')return fail('REQUIRES_SPECIALIZED_ADAPTER',asset.assetRole);
    const adapter=host.assetAdapters?.[a.assetId];
    const clearance=asset.clearanceM||adapter?.clearanceM;
    if(!Array.isArray(clearance)||clearance.length!==3||clearance.some(x=>!finite(x)||x<=0))return fail('CLEARANCE_ADAPTER_REQUIRED');
    const isBridge=asset.kind==='bridge';
    if(asset.requiresGroundAdapter&&(!adapter?.collisionEvidence||!Array.isArray(adapter.groundBodiesGltfM)||!adapter.groundBodiesGltfM.length))return fail('GROUND_ADAPTER_REQUIRED');
    if(![a.r,a.c,scale,yaw].every(finite)||scale<=0||scale>4)return fail('INVALID_TRANSFORM');
    const polygon=footprint(a.r,a.c,clearance[0],clearance[1],yaw,scale,m),cells=coveredCells(polygon);
    const hit=forbidden.find(p=>polygonsOverlap(polygon,p.polygon));if(hit)return fail('FORBIDDEN_ENVELOPE',hit.kind);
    if(instances.some(p=>polygonsOverlap(polygon,p.clearancePolygonCR)))return fail('DECOR_OVERLAP');
    if(cells.some(p=>!grid[p.r]||grid[p.r][p.c]===undefined))return fail('OUTSIDE_MAP');
    if(isBridge){
      const crossing=crossings.find(x=>x.id===a.crossingId);
      if(!crossing||crossing.id==='XR-RED-01'||crossing.immutable||!['pedestrian','car'].includes(crossing.mode)||!validRect(crossing.envelope)||!Array.isArray(crossing.endpointsRC)||crossing.endpointsRC.length!==2||crossing.endpointsRC.some(p=>!Array.isArray(p)||p.length!==2||p.some(x=>!finite(x))))return fail('EXPLICIT_BRIDGE_CROSSING_REQUIRED');
      if(crossing.mode==='car'&&asset.assetId!=='mini_vehicle_bridge')return fail('BRIDGE_MODE_MISMATCH');
      const [p,q]=crossing.endpointsRC;if([p,q].some(([r,c])=>!grid[Math.floor(r)]||!([T.grass,T.sidewalk,T.sand,T.road,T.bridge].includes(grid[Math.floor(r)][Math.floor(c)]))))return fail('BRIDGE_SHORE_NOT_DRY');
      if(Math.abs(a.r-(p[0]+q[0])/2)>1e-6||Math.abs(a.c-(p[1]+q[1])/2)>1e-6)return fail('BRIDGE_NOT_CENTERED');
      const expected=Math.atan2(q[1]-p[1],q[0]-p[0])*180/Math.PI;
      if(Math.abs(Math.sin((yaw-expected)*Math.PI/180))>1e-6)return fail('BRIDGE_DIRECTION_MISMATCH');
      const vb=asset.visualBoundsBlenderM,span=vb&&(vb.max[1]-vb.min[1])*scale/m;
      if(!finite(span)||span<Math.hypot(q[0]-p[0],q[1]-p[1])-1e-6)return fail('BRIDGE_TOO_SHORT');
      if(!cells.some(p=>grid[p.r][p.c]===T.water||grid[p.r][p.c]===T.bridge))return fail('BRIDGE_WITHOUT_WATER_OR_DECK');
      if(polygon.some(([c,r])=>c<crossing.envelope.minC||c>crossing.envelope.maxC||r<crossing.envelope.minR||r>crossing.envelope.maxR))return fail('BRIDGE_OUTSIDE_EXPLICIT_ENVELOPE');
      if(!adapter?.deckNavigationEvidence)return fail('BRIDGE_DECK_ADAPTER_REQUIRED');
    }else if(cells.some(p=>![T.grass,T.sidewalk,T.sand].includes(grid[p.r][p.c])))return fail('WATER_ROAD_OR_UNKNOWN_SURFACE');
    const isLamp=asset.kind==='pedestrian_light'||a.role==='roadside_lamp';
    if(isLamp){
      if(grid[Math.floor(a.r)]?.[Math.floor(a.c)]!==T.sidewalk)return fail('LAMP_NOT_ON_SIDEWALK');
      const minSpacing=lampPolicy.spacingCells??8;
      if(instances.some(p=>p.role==='roadside_lamp'&&Math.hypot(p.r-a.r,p.c-a.c)<minSpacing-1e-8))return fail('LAMP_SPACING');
      const distance=nearestRoad(a.r,a.c);if(distance<(lampPolicy.setbackCells??0.3)||distance>(lampPolicy.maxRoadDistanceCells??2))return fail('LAMP_ROAD_SETBACK');
    }
    const binding=asset.lods.find(l=>l.lod===(a.lod??1))||asset.lods.find(l=>l.lod===0);
    if(!binding||!/^\/assets\//.test(binding.url)||!/^[0-9a-f]{64}$/.test(binding.sha256)||!Number.isInteger(binding.bytes))return fail('INVALID_BINDING');
    const placementOrigin=adapter?.placementOriginEvidence?adapter.placementOriginGltfM:asset.placementOriginGltfM;
    if(!Array.isArray(placementOrigin)||placementOrigin.length!==3||placementOrigin.some(x=>!finite(x)))return fail('PLACEMENT_SOCKET_REQUIRED');
    const sourceBodies=asset.collisionBodiesGltfM.length?asset.collisionBodiesGltfM:adapter?.groundBodiesGltfM||[];
    if(sourceBodies.some(b=>!Array.isArray(b.min)||!Array.isArray(b.max)||b.min.length!==3||b.max.length!==3||b.min.some((v,k)=>!finite(v)||!finite(b.max[k])||b.max[k]<=v)))return fail('INVALID_GROUND_BODIES');
    const ca=Math.cos(yaw*Math.PI/180),sa=Math.sin(yaw*Math.PI/180);
    const worldBodies=sourceBodies.map(b=>{
      const x=(b.min[0]+b.max[0])/2,z=(b.min[2]+b.max[2])/2;
      return {node:b.node||null,polygonCR:footprint(a.r+(-x*sa+z*ca)*scale/m,a.c+(x*ca+z*sa)*scale/m,b.max[0]-b.min[0],b.max[2]-b.min[2],yaw,scale,m),minYM:round(b.min[1]*scale),maxYM:round(b.max[1]*scale)};
    });
    instances.push({id:a.id,assetId:a.assetId,role:isLamp?'roadside_lamp':isBridge?'bridge':'decor',r:a.r,c:a.c,
      transform:{positionM:[round(a.c*m),0,round(a.r*m)],yawDegrees:yaw,uniformScale:scale,modelLocalOffsetM:placementOrigin.map(x=>-x)},
      binding:{url:binding.url,sha256:binding.sha256,bytes:binding.bytes,lod:binding.lod},artAcceptance:asset.artAcceptance.status,
      clearancePolygonCR:polygon,collision:{policy:isBridge?'host_deck_adapter':'authored_ground_proxy_only',sourceBodies,worldBodies,adapter:adapter||null,scaleApplied:scale},
      crossingId:isBridge?a.crossingId:null,lightBudget:isLamp?{emissive:true,dynamicLight:false}:null});return true;
  }
  function nearestRoad(r,c){let best=Infinity;for(let rr=Math.max(0,Math.floor(r)-4);rr<Math.min(grid.length,Math.floor(r)+5);rr++)for(let cc=Math.max(0,Math.floor(c)-4);cc<Math.min(grid[rr].length,Math.floor(c)+5);cc++)if(road(grid[rr][cc]))best=Math.min(best,Math.hypot(Math.max(cc-c,0,c-cc-1),Math.max(rr-r,0,r-rr-1)));return best;}
  if(anchors.length>1000||!Array.isArray(crossings)||new Set(crossings.map(x=>x.id)).size!==crossings.length){errors.push({code:'INVALID_ANCHOR_OR_CROSSING_BUDGET'});return result();}
  for(const a of [...anchors].sort((a,b)=>String(a.id).localeCompare(String(b.id),'en')))place(a);
  if(lampPolicy.enabled){
    const max=lampPolicy.maxCount??80,spacing=lampPolicy.spacingCells??8;
    if(!Number.isInteger(max)||max<0||max>320||!finite(spacing)||spacing<3){errors.push({code:'INVALID_LAMP_POLICY'});return result();}
    let count=instances.filter(x=>x.role==='roadside_lamp').length;const regionCounts=new Map();
    for(let r=0;r<grid.length&&count<max;r++)for(let c=0;c<grid[r].length&&count<max;c++)if(grid[r][c]===T.sidewalk&&nearestRoad(r+0.5,c+0.5)<=2){
      const region=lampPolicy.regions?.find(x=>r>=x.minR&&r<x.maxR&&c>=x.minC&&c<x.maxC&&(!x.polygonCR||pointInPolygon([c+.5,r+.5],x.polygonCR)));
      if(lampPolicy.regions&&(!region||(regionCounts.get(region)||0)>=(region.maxCount??max)))continue;
      if(place({id:`LAMP-${r}-${c}`,assetId:region?.assetId||lampPolicy.assetId||'ped_light_double',role:'roadside_lamp',r:r+0.5,c:c+0.5,yawDegrees:0},true)){count++;regionCounts.set(region,(regionCounts.get(region)||0)+1);}
    }
  }
  return result();
}
