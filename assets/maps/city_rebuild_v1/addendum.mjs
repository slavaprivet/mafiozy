import {TILES,pointInPolygon,roadCells,isSimpleBoundedPolygon} from './topology.mjs';
import {policeShapesFromAddendum,policeCellOverlapsShape} from './police_snapshot.mjs';
const rectContains=(r,c,a)=>r>=a.minR&&r<=a.maxR&&c>=a.minC&&c<=a.maxC;
const boundsRect=a=>({minR:a.north,maxR:a.south,minC:a.west,maxC:a.east});
const pointOK=p=>Array.isArray(p)&&p.length===2&&p.every(Number.isFinite)&&p[0]>=0&&p[0]<=180&&p[1]>=0&&p[1]<=200;
const polygonsContain=(p,polys)=>polys.some(poly=>pointInPolygon(p,poly));
export function policeUnionContains(source,r,c){
  if(!source||source.surface_protected_rule!=='distance([r,c],[76,76]) < 8.0 OR any rectangle/causeway below')throw new Error('Unsupported police union rule');
  const rects=[boundsRect(source.island_bounds_rc),boundsRect(source.intake_bounds_rc),source.west_vehicle_causeway_rect_rc,source.north_causeway_rect_rc,source.police_admin_rect_rc,...source.solid_rects_rc];
  return Math.hypot(r-76,c-76)<8||rects.some(a=>rectContains(r,c,a));
}
function connectivity(grid,owners){
  const labels=new Int32Array(36000).fill(-1),parts=[];
  const road=i=>[0,19].includes(grid[Math.floor(i/180)][i%180]);
  for(let start=0;start<36000;start++){
    if(labels[start]>=0||!road(start))continue;
    const n=parts.length,queue=[start],ids=new Set();labels[start]=n;
    for(let k=0;k<queue.length;k++){
      const i=queue[k],r=Math.floor(i/180),c=i%180;for(const id of owners.get(i)||[])ids.add(id);
      for(const j of [r>0?i-180:-1,r<199?i+180:-1,c>0?i-1:-1,c<179?i+1:-1])if(j>=0&&labels[j]<0&&road(j)){labels[j]=n;queue.push(j);}
    }
    parts.push({id:n,cells:queue.length,firstRC:[Math.floor(start/180),start%180],roadIds:[...ids].sort(),keys:queue});
  }
  const largest=parts.reduce((a,b)=>!a||b.cells>a.cells?b:a,null);
  // Exact nearest-cell pairs, suggestions only; never draw these connectors.
  if(largest)for(const part of parts)if(part!==largest){
    let best=Infinity,pair=null;
    for(const a of part.keys)for(const b of largest.keys){const dr=Math.floor(a/180)-Math.floor(b/180),dc=a%180-b%180,d=dr*dr+dc*dc;if(d<best){best=d;pair=[[Math.floor(a/180),a%180],[Math.floor(b/180),b%180]];}}
    part.nearestMainlandGap={distanceGrid:Math.sqrt(best),pairRC:pair,automaticConnectionAllowed:false};
  }
  return {components:parts.map(({keys,...rest})=>rest).sort((a,b)=>b.cells-a.cells||a.id-b.id),labels};
}

/** Hash verification belongs to the CLI; this routine is pure and accepts
 * explicit source objects only. analysisGrid is NOT a publishable game grid.
 * It exposes rejected geometry for review without overriding fail-closed grid:null.
 */
export function compileAddendum(addendum,{base,policeProtectedCells}={}){
  const errors=[],warnings=[],add=(code,id,detail={})=>errors.push({code,id,...detail});
  if(addendum?.schema!=='mafiozy.city-masterplan-v3-topology-ready-addendum/v2')throw new Error('Unsupported topology addendum schema');
  if(base?.schema!=='mafiozy.city-authoritative-topology-handoff/v1')throw new Error('Explicit authoritative base required');
  if(base.main_compatibility?.map_rows!==200||base.main_compatibility?.map_cols!==180)throw new Error('Wrong base dimensions');
  const polys=(items,label)=>items.map(x=>{const p=x.polygon_grid;if(!isSimpleBoundedPolygon(p))throw new Error(`Invalid ${label} polygon ${x.id}`);return p;});
  const water=polys(addendum.waterbodies,'water'),islets=polys(base.water.islets,'islet');
  const wet=p=>polygonsContain(p,water)&&!polygonsContain(p,islets);
  const police=addendum.protected_police_complex;
  if(JSON.stringify(police.gameplay_center_rc)!=='[76,76]')throw new Error('Police anchor changed');
  const policeShapes=policeShapesFromAddendum(police);
  const grid=Array.from({length:200},()=>Array(180).fill(TILES.grass)),waterMask=[],protectedMask=[],hostTiles=new Map(),owners=new Map();
  const centers=fn=>{for(let r=0;r<200;r++)for(let c=0;c<180;c++)fn(r,c,[c+.5,r+.5],r*180+c);};
  centers((r,c,p,k)=>{if(wet(p)){grid[r][c]=TILES.water;waterMask.push(k);}if(policeShapes.some(s=>policeCellOverlapsShape(r,c,s))){protectedMask.push(k);grid[r][c]=TILES.sidewalk;}});
  const protectedSet=new Set(protectedMask),waterSet=new Set(waterMask);
  if(!Array.isArray(policeProtectedCells))add('EXACT_HOST_POLICE_TILES_REQUIRED','host',{reservedCells:protectedMask.length,analysisPlaceholderTile:9});
  else{
    for(const cell of policeProtectedCells){
      if(!Number.isInteger(cell.r)||!Number.isInteger(cell.c)||cell.r<0||cell.r>=200||cell.c<0||cell.c>=180||!Number.isInteger(cell.tile)||cell.tile<0||cell.tile>255)throw new Error('Invalid host protected cell');
      const k=cell.r*180+cell.c;if(hostTiles.has(k))throw new Error('Duplicate host protected cell');hostTiles.set(k,cell.tile);
    }
    const missing=protectedMask.filter(k=>!hostTiles.has(k));if(missing.length)add('HOST_POLICE_UNION_INCOMPLETE','host',{missingCount:missing.length,sampleRC:missing.slice(0,12).map(k=>[Math.floor(k/180),k%180])});
    for(const k of hostTiles.keys())if(!protectedSet.has(k)){protectedSet.add(k);protectedMask.push(k);}protectedMask.sort((a,b)=>a-b);
  }
  const green=base.green_public||{};
  for(const park of green.parks||[])if(['plaza','promenade'].includes(park.kind))centers((r,c,p,k)=>{if(!waterSet.has(k)&&!protectedSet.has(k)&&pointInPolygon(p,park.polygon_grid))grid[r][c]=TILES.sidewalk;});
  if(green.big_beach&&!green.big_beach.polygon_grid)add('BEACH_ENVELOPE_REQUIRED',green.big_beach.id);
  else if(green.big_beach)centers((r,c,p,k)=>{if(!waterSet.has(k)&&!protectedSet.has(k)&&pointInPolygon(p,green.big_beach.polygon_grid))grid[r][c]=TILES.sand;});
  const surface=[],deferred=[];let redDeck=null;
  for(const x of addendum.crossings){
    if(x.status==='deferred_multilayer_not_surface'){
      if(x.no_surface_bridge19!==true||!x.layer.startsWith('subsurface_'))add('INVALID_DEFERRED_CROSSING',x.id);deferred.push(x.id);continue;
    }
    if(!x.kind.startsWith('surface_bridge')||x.layer!=='bridge_deck'||!x.status.startsWith('enabled_')){add('UNSUPPORTED_CROSSING',x.id);continue;}
    if(!isSimpleBoundedPolygon(x.driveable_envelope_polygon_grid_cr)||!isSimpleBoundedPolygon(x.deck_envelope_polygon_grid_cr)||!Array.isArray(x.road_ids)||x.road_ids.some(id=>!addendum.roads.some(r=>r.id===id))){add('CROSSING_ENVELOPE_INVALID',x.id);continue;}
    if(x.id==='XR-RED-01'){
      if(JSON.stringify(x.centerline_grid_cr)!=='[[78.25,51.5],[101.75,51.5]]')add('RED_CENTERLINE_CHANGED',x.id);redDeck=x;
    }surface.push(x);
    centers((r,c,p,k)=>{if(pointInPolygon(p,x.deck_envelope_polygon_grid_cr)&&!protectedSet.has(k)){grid[r][c]=pointInPolygon(p,x.driveable_envelope_polygon_grid_cr)?TILES.bridge:TILES.sidewalk;owners.set(k,[...x.road_ids]);}});
  }
  if(!redDeck)add('IMMUTABLE_RED_BRIDGE_MISSING','XR-RED-01');
  const allowed=(id,p)=>surface.some(x=>x.road_ids.includes(id)&&pointInPolygon(p,x.driveable_envelope_polygon_grid_cr));
  const deck=p=>surface.some(x=>pointInPolygon(p,x.deck_envelope_polygon_grid_cr));
  const roadReport=[],seenRoads=new Set();let fragmentCount=0,gapCount=0;
  for(const road of addendum.roads){
    if(typeof road.id!=='string'||seenRoads.has(road.id)){add('ROAD_ID_DUPLICATE_OR_INVALID',String(road.id));continue;}seenRoads.add(road.id);
    const width=road.width?.carriageway_grid,sw=road.width?.sidewalk_each_grid;
    if(!(width>0)||!(sw>=0)||Math.abs(road.width.total_envelope_grid-width-2*sw)>1e-6){add('WIDTH_PROFILE_INVALID',road.id);continue;}
    if(road.layer!=='surface'||!Array.isArray(road.land_fragments_grid_cr)){add('SURFACE_FRAGMENTS_REQUIRED',road.id);continue;}
    gapCount+=road.water_gaps.length;
    for(const gap of road.water_gaps)if(gap.resolution.surface_jump_allowed!==false)add('SURFACE_GAP_RECONNECT_FORBIDDEN',road.id);
    const overWater=new Set(),overPolice=new Set(),foot=new Set(),sidewalkWet=new Set();
    for(const fragment of road.land_fragments_grid_cr){
      fragmentCount++;if(fragment.length<2||!fragment.every(pointOK)){add('FRAGMENT_BOUNDS',road.id);continue;}
      // Crucially each fragment rasterizes separately; no flattened array.
      for(const k of roadCells(fragment,width+2*sw)){
        const r=Math.floor(k/180),c=k%180,p=[c+.5,r+.5];
        if(waterSet.has(k)&&!deck(p)&&!protectedSet.has(k))sidewalkWet.add(k);
        if(waterSet.has(k)||protectedSet.has(k)||[0,19].includes(grid[r][c]))continue;grid[r][c]=TILES.sidewalk;
      }
      for(const k of roadCells(fragment,width)){
        foot.add(k);const r=Math.floor(k/180),c=k%180,p=[c+.5,r+.5];
        if(protectedSet.has(k)){if(![0,19].includes(hostTiles.get(k)))overPolice.add(k);continue;}
        if(waterSet.has(k)&&!allowed(road.id,p)){overWater.add(k);continue;}
        grid[r][c]=allowed(road.id,p)?TILES.bridge:TILES.road;
        owners.set(k,[...new Set([...(owners.get(k)||[]),road.id])]);
      }
    }
    const rc=keys=>[...keys].sort((a,b)=>a-b).map(k=>[Math.floor(k/180),k%180]);
    if(overWater.size)add('FINITE_WIDTH_ROAD_OVER_WATER',road.id,{count:overWater.size,cellsRC:rc(overWater),minimumCorrection:'Reroute full carriageway or trim fragment at a dry cap; clipping centerline only is insufficient.'});
    if(sidewalkWet.size)add('TOTAL_ENVELOPE_OVER_WATER',road.id,{count:sidewalkWet.size,sampleRC:rc(sidewalkWet).slice(0,12),requiredEdgeSetbackGrid:width/2+sw});
    if(overPolice.size)add('ROAD_INTERSECTS_PROTECTED_POLICE',road.id,{count:overPolice.size,sampleRC:rc(overPolice).slice(0,12),minimumCorrection:'Route around protected union or explicitly reconcile existing host causeway lane.'});
    roadReport.push({id:road.id,fragments:road.land_fragments_grid_cr.length,gaps:road.water_gaps.length,widthGrid:width,rasterCells:foot.size,waterConflictCells:overWater.size,policeConflictCells:overPolice.size});
  }
  for(const [k,tile]of hostTiles)grid[Math.floor(k/180)][k%180]=tile;
  const connected=connectivity(grid,owners);
  const fallbackPoints=(addendum.terrestrial_connectivity?.fixed_intersections_grid_cr||[]).map(p=>{if(!pointOK(p))throw new Error('Fallback point outside map');const r=Math.min(199,Math.floor(p[1])),c=Math.min(179,Math.floor(p[0]));return {pointCR:[...p],cellRC:[r,c],componentId:connected.labels[r*180+c]};});
  const fallbackConnected=fallbackPoints.length>1&&fallbackPoints.every(p=>p.componentId>=0&&p.componentId===fallbackPoints[0].componentId);
  if(fallbackPoints.length&&!fallbackConnected)add('DECLARED_TERRESTRIAL_FALLBACK_DISCONNECTED','fallback',{points:fallbackPoints});
  if(connected.components.length!==1)add('ROAD_GRID_DISCONNECTED','roads',{componentCount:connected.components.length});
  let roadOnWater=0,bridgeOutsideEnvelope=0,subsurfaceBridges=0;const counts={};
  centers((r,c,p,k)=>{
    const t=grid[r][c];counts[t]=(counts[t]||0)+1;
    if(t===0&&waterSet.has(k)&&!protectedSet.has(k))roadOnWater++;
    if(t===19&&!surface.some(x=>pointInPolygon(p,x.driveable_envelope_polygon_grid_cr))&&!protectedSet.has(k))bridgeOutsideEnvelope++;
    if(t===19&&addendum.crossings.some(x=>deferred.includes(x.id)&&x.bore_envelope_polygon_grid_cr&&pointInPolygon(p,x.bore_envelope_polygon_grid_cr)))subsurfaceBridges++;
  });
  if(roadOnWater)add('FINAL_ROAD_ON_WATER','grid',{count:roadOnWater});
  if(bridgeOutsideEnvelope)add('FINAL_BRIDGE_OUTSIDE_ENVELOPE','grid',{count:bridgeOutsideEnvelope});
  if(subsurfaceBridges)add('SUBSURFACE_EMITTED_SURFACE_BRIDGE','grid',{count:subsurfaceBridges});
  warnings.push({code:'NO_RUNTIME_OR_GAMEPLAY_MIGRATION',detail:'analysisGrid is diagnostic only; protected placeholders and disconnected components are not playable.'});
  errors.sort((a,b)=>a.code.localeCompare(b.code,'en')||a.id.localeCompare(b.id,'en'));
  return {schema:'mafiozy.native-addendum-candidate/v1',status:errors.length?'REJECTED':'CANDIDATE_TOPOLOGY_ONLY',map:{rows:200,cols:180},grid:errors.length?null:grid,analysisGrid:grid,
    protectedPoliceCellsRC:protectedMask.map(k=>[Math.floor(k/180),k%180]),protectedRedDeckPolygon:redDeck?.deck_envelope_polygon_grid_cr??null,
    validation:{errors,warnings,counts,roadCount:addendum.roads.length,fragmentCount,gapCount,roadReport,connectivity:connected.components,terrestrialFallback:{connected:fallbackConnected,points:fallbackPoints},deferredCrossings:deferred,roadOnWater,bridgeOutsideEnvelope,subsurfaceBridges}};
}
