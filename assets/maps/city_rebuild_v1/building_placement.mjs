// Pure deterministic full-envelope planner for isolated GLB walk preview.
// Coordinate contract: world X=c*4.1, Z=r*4.1, glTF Y-up. No old MAP input.
const M=4.1,EPS=1e-7;
const rect=(minR,minC,maxR,maxC)=>({minR,minC,maxR,maxC});
const polygon=q=>[[q.minC,q.minR],[q.maxC,q.minR],[q.maxC,q.maxR],[q.minC,q.maxR]];
export const rectanglesOverlap=(a,b)=>a.minR<b.maxR-EPS&&a.maxR>b.minR+EPS&&a.minC<b.maxC-EPS&&a.maxC>b.minC+EPS;
const inflate=(q,p)=>rect(q.minR-p,q.minC-p,q.maxR+p,q.maxC+p);
export function cellsForRect(q){const out=[];for(let r=Math.floor(q.minR+EPS);r<Math.ceil(q.maxR-EPS);r++)for(let c=Math.floor(q.minC+EPS);c<Math.ceil(q.maxC-EPS);c++)out.push({r,c});return out;}
function inPoly(c,r,p){let yes=false;for(let i=0,j=p.length-1;i<p.length;j=i++){const a=p[i],b=p[j];if((a[1]>r)!==(b[1]>r)&&c<(b[0]-a[0])*(r-a[1])/(b[1]-a[1])+a[0])yes=!yes;}return yes;}
const rotate=(x,z,yaw)=>{const a=yaw*Math.PI/180;return[x*Math.cos(a)+z*Math.sin(a),-x*Math.sin(a)+z*Math.cos(a)];};
function localRect(asset,r,c,yaw){const b=asset.visualBounds,o=asset.recenterXYZ,p=[];for(const x of[b.min[0],b.max[0]])for(const z of[b.min[2],b.max[2]]){const q=rotate(x+o[0],z+o[2],yaw);p.push([r+q[1]/M,c+q[0]/M]);}return rect(Math.min(...p.map(x=>x[0])),Math.min(...p.map(x=>x[1])),Math.max(...p.map(x=>x[0])),Math.max(...p.map(x=>x[1])));}
function subtractRect(a,b){if(!rectanglesOverlap(a,b))return[a];const r0=Math.max(a.minR,b.minR),r1=Math.min(a.maxR,b.maxR),c0=Math.max(a.minC,b.minC),c1=Math.min(a.maxC,b.maxC);return[rect(a.minR,a.minC,r0,a.maxC),rect(r1,a.minC,a.maxR,a.maxC),rect(r0,a.minC,r1,c0),rect(r0,c1,r1,a.maxC)].filter(q=>q.maxR-q.minR>EPS&&q.maxC-q.minC>EPS);}

export function planBuildings({topology,catalog,source,ledger,maxInstances=220}={}){
  const instances=[],unresolved=[],errors=[];
  if(!topology?.grid||topology.status==='REJECTED'||topology.grid.length!==200||topology.grid.some(r=>r.length!==180)||!topology.protectedMask||topology.validation?.structuralChecksPassed!==true)errors.push('REQUIRES_VALID_NEW_TOPOLOGY');
  if(!catalog?.entries?.length||!source?.districts?.length||!ledger?.immutableGeometry?.length)errors.push('MISSING_CATALOG_DISTRICTS_OR_PROTECTION');
  if(errors.length)return{schema:'mafiozi.city-rebuild.buildings-placement/v1',status:'REJECTED',errors,instances:[]};
  const grid=topology.grid,assets=new Map(catalog.entries.map(a=>[a.assetId,a]));
  const protectedRects=ledger.immutableGeometry.filter(x=>x.immutable&&x.bounds).map(x=>({id:x.id,...rect(x.bounds.minR,x.bounds.minC,x.bounds.maxRExclusive??x.bounds.maxR,x.bounds.maxCExclusive??x.bounds.maxC)}));
  const fixedRows=ledger.rows.filter(x=>/^(bank|business|poi):/.test(x.id)&&Array.isArray(x.plannedRC));
  const fixedReservations=fixedRows.map(x=>({id:x.id,...rect(x.plannedRC[0]-2.5,x.plannedRC[1]-2.5,x.plannedRC[0]+2.5,x.plannedRC[1]+2.5)}));
  const district=(r,c)=>source.districts.find(d=>inPoly(c,r,d.polygon_grid));
  const tile=(r,c)=>grid[Math.floor(r)]?.[Math.floor(c)];
  const clearTiles=(q,allowed)=>cellsForRect(q).every(p=>allowed.includes(grid[p.r]?.[p.c])&&!topology.protectedMask[p.r]?.[p.c]);
  const blockers=q=>protectedRects.some(p=>rectanglesOverlap(q,p));
  function tryPlace(asset,r,c,yaw,{id,districtId,gameplayId=null,parcelId=null,role=asset.role}={}){
    if(!asset.publicDoorLocalXYZ||!asset.sourceHashVerified||asset.artAcceptance==='rejected'||asset.assetId==='police_station')return null;
    const fp=localRect(asset,r,c,yaw),rural=/cottage|chalet|crosswing|orchard|bungalow|garden_lane/.test(asset.assetId),clearance=inflate(fp,rural?1.6:asset.role==='glass_tower'?1.35:.65);
    if(!clearTiles(fp,[8])||blockers(fp)||fixedReservations.some(p=>p.id!==gameplayId&&rectanglesOverlap(fp,p))||instances.some(p=>rectanglesOverlap(clearance,p.clearance)||rectanglesOverlap(fp,p.entryCorridor)))return null;
    const corners=polygon(fp);if(!corners.every(([x,z])=>district(z,x)?.id===districtId))return null;
    const o=asset.recenterXYZ,d=asset.publicDoorLocalXYZ,q=rotate(d[0]+o[0],d[2]+o[2],yaw),door={r:r+q[1]/M,c:c+q[0]/M};
    const normal=rotate(0,asset.frontSign||1,yaw),dr=Math.round(normal[1]),dc=Math.round(normal[0]);
    let end=null;
    // Start at the outer envelope, then require an explicit short dry connection
    // to a native road, not a guessed teleport target inside the building.
    const edge={r:dr>0?fp.maxR:dr<0?fp.minR:door.r,c:dc>0?fp.maxC:dc<0?fp.minC:door.c};
    for(let step=.25;step<=9;step+=.25){const p={r:edge.r+dr*step,c:edge.c+dc*step},t=tile(p.r,p.c);if(![0,8,9].includes(t))break;if(t===0){end=p;break;}}
    if(!end)return null;
    const width=.42,corridor=dr?rect(Math.min(door.r,end.r)-.05,door.c-width,Math.max(door.r,end.r)+.05,door.c+width):rect(door.r-width,Math.min(door.c,end.c)-.05,door.r+width,Math.max(door.c,end.c)+.05);
    if(!clearTiles(corridor,[0,8,9])||blockers(corridor)||fixedReservations.some(p=>p.id!==gameplayId&&rectanglesOverlap(corridor,p))||instances.some(p=>rectanglesOverlap(corridor,p.footprint)||rectanglesOverlap(fp,p.entryCorridor)))return null;
    // Conservative exterior-only collider: full visible envelope minus the
    // explicit front access strip. No fake claim of authored interior collision.
    const bodies=subtractRect(fp,corridor).map(p=>({polygonCR:polygon(p),minYM:0,maxYM:asset.dimensionsXYZ[1],rectangleRC:p}));
    const binding=asset.lods.find(l=>l.lod===0);
    const instance={id,assetId:asset.assetId,role,districtId,sourceParcelId:parcelId,gameplayId,gameplayActive:false,artAcceptance:asset.artAcceptance,
      binding,transform:{positionM:[c*M,0,r*M],yawDegrees:yaw,uniformScale:1,modelLocalOffsetM:asset.recenterXYZ},
      footprint:fp,clearance,entryCorridor:corridor,entry:{anchorRC:door,roadProbeRC:end,authoredLocalXYZ:asset.publicDoorLocalXYZ,evidence:asset.publicDoorEvidence},
      bounds:asset.visualBounds,collision:{method:'conservative_visual_envelope_minus_public_approach_exterior_only',worldBodies:bodies},hideNodeNames:asset.hideNodeNames,
      renderContract:'Parent positionM/yaw/scale; child modelLocalOffsetM BEFORE rotation. Hide helper and non-LOD0 nodes; hash verify binding bytes before attach.'};
    instances.push(instance);return instance;
  }
  const exactModel={'poi:hospital':'hospital','poi:hospital_east':'hospital','poi:firestation':'fire_station','business:club':'nightclub'};
  for(const row of fixedRows){
    if(row.id==='poi:police'){unresolved.push({id:row.id,reason:'protected_existing_police_unchanged_not_replaced'});continue;}
    const asset=assets.get(exactModel[row.id]);if(!asset){unresolved.push({id:row.id,reason:'no_semantically_matching_ready_model_bound'});continue;}
    const [r,c]=row.plannedRC,d=district(r,c);let placed=null;
    for(const yaw of[0,90,180,270]){placed=tryPlace(asset,r,c,yaw,{id:'REBUILD-'+row.id,gameplayId:row.id,districtId:d?.id,role:'fixed_site_visual_candidate'});if(placed)break;}
    if(!placed)unresolved.push({id:row.id,assetId:asset.assetId,reason:'planned_full_footprint_or_public_route_does_not_fit'});
  }
  const parcels=(source.urban_fabric?.parcels||[]).map(p=>({r:p.polygon_grid.reduce((n,v)=>n+v[1],0)/p.polygon_grid.length,c:p.polygon_grid.reduce((n,v)=>n+v[0],0)/p.polygon_grid.length,districtId:p.district,parcelId:p.id}));
  const candidates=[...parcels];
  // Road-frontage infill supplements authored parcels whose tiny proof boxes do
  // not accommodate real models. It never alters the road or terrain geometry.
  for(let r=5;r<194;r+=1.5)for(let c=5;c<175;c+=1.5){const d=district(r,c);if(d&&tile(r,c)===8)candidates.push({r,c,districtId:d.id,parcelId:null});}
  const compatible=(asset,d)=>asset.role==='glass_tower'?['central','eastside'].includes(d):asset.districts.includes(d);
  const pools=catalog.entries.filter(a=>a.assetId!=='police_station').sort((a,b)=>(b.role==='civic_building')-(a.role==='civic_building'));
  const usage=new Map();
  // Round robin ensures silhouettes appear before any one asset is repeated.
  for(let round=0;round<25&&instances.length<maxInstances;round++)for(const asset of pools){
    if(instances.length>=maxInstances)break;
    const quota=asset.role==='business_facade'?4:asset.role==='civic_building'?1:asset.role==='glass_tower'?14:asset.role==='glass_retail'?10:24;
    if((usage.get(asset.assetId)||0)>=quota)continue;
    let found=false;const phase=(round*137+pools.indexOf(asset)*23)%Math.max(1,candidates.length);
    for(let j=0;j<candidates.length;j++){
      const p=candidates[(j+phase)%candidates.length];if(!compatible(asset,p.districtId))continue;
      for(const yaw of[0,90,180,270]){const id=`REBUILD-VISUAL-${asset.assetId}-${String((usage.get(asset.assetId)||0)+1).padStart(3,'0')}`;
        if(tryPlace(asset,p.r,p.c,yaw,{id,districtId:p.districtId,parcelId:p.parcelId})){usage.set(asset.assetId,(usage.get(asset.assetId)||0)+1);found=true;break;}}
      if(found||instances.length>=maxInstances)break;
    }
  }
  for(const asset of pools)if(!instances.some(i=>i.assetId===asset.assetId))unresolved.push({id:'asset:'+asset.assetId,reason:'no_safe_district_frontage_fit',assetId:asset.assetId});
  return{schema:'mafiozi.city-rebuild.buildings-placement/v1',status:'CANDIDATE_REQUIRES_LIVE_QA',scope:'isolated_rebuild_walk_preview_not_main',metresPerCell:M,pendingHostSnapshot:topology.pendingHostSnapshot===true,
    counts:{instances:instances.length,assetTypesPlaced:new Set(instances.map(i=>i.assetId)).size,residences:instances.filter(i=>i.role==='residence').length,fixedSiteCandidates:instances.filter(i=>i.gameplayId).length},
    errors,instances,unresolved,protectedRects,footprints:instances.map(i=>({id:i.id,...i.footprint})),doorCorridors:instances.map(i=>({id:i.id,...i.entryCorridor})),
    limitations:['No persistent identity created for visual infill residences/business facades.','No final art acceptance implied.','Collision is conservative exterior only, not accepted playable interiors.','No procedural boxes or terrain repainting.','Full-envelope land checks are against the exact staged topology.']};
}
