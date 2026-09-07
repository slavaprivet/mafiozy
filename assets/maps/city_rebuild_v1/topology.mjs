// Pure, deterministic native-grid compiler. No imports, global state, or game hooks.
export const TILES=Object.freeze({water:16,grass:8,sand:14,sidewalk:9,road:0,bridge:19});
export const SIZE=Object.freeze({rows:200,cols:180});
const groups=['arterials','collectors','local_roads','alleys_service'];
const EPS=1e-9;
const finitePoint=p=>Array.isArray(p)&&p.length===2&&p.every(Number.isFinite);
const cross=(a,b,c)=>(b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0]);
const onSegment=(p,a,b)=>Math.abs(cross(a,b,p))<EPS&&p[0]>=Math.min(a[0],b[0])-EPS&&p[0]<=Math.max(a[0],b[0])+EPS&&p[1]>=Math.min(a[1],b[1])-EPS&&p[1]<=Math.max(a[1],b[1])+EPS;
export function pointInPolygon(p,polygon){
  let inside=false;
  for(let i=0,j=polygon.length-1;i<polygon.length;j=i++){
    const a=polygon[j],b=polygon[i];if(onSegment(p,a,b))return true;
    if((a[1]>p[1])!==(b[1]>p[1])&&p[0]<(b[0]-a[0])*(p[1]-a[1])/(b[1]-a[1])+a[0])inside=!inside;
  }return inside;
}
export function segmentDistance(p,a,b){
  const dx=b[0]-a[0],dy=b[1]-a[1],d=dx*dx+dy*dy;
  const t=d?Math.max(0,Math.min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dy)/d)):0;
  return Math.hypot(p[0]-a[0]-t*dx,p[1]-a[1]-t*dy);
}
function intersects(a,b,c,d){
  if(onSegment(a,c,d)||onSegment(b,c,d)||onSegment(c,a,b)||onSegment(d,a,b))return true;
  return (cross(a,b,c)>0)!==(cross(a,b,d)>0)&&(cross(c,d,a)>0)!==(cross(c,d,b)>0);
}
export function isSimpleBoundedPolygon(poly){
  if(!Array.isArray(poly)||poly.length<3||!poly.every(p=>finitePoint(p)&&p[0]>=0&&p[0]<=180&&p[1]>=0&&p[1]<=200))return false;
  let area=0;for(let i=0;i<poly.length;i++){const a=poly[i],b=poly[(i+1)%poly.length];area+=a[0]*b[1]-b[0]*a[1];}
  if(Math.abs(area)<EPS)return false;
  for(let i=0;i<poly.length;i++)for(let j=i+1;j<poly.length;j++)if(j!==i+1&&!(i===0&&j===poly.length-1)&&intersects(poly[i],poly[(i+1)%poly.length],poly[j],poly[(j+1)%poly.length]))return false;
  return true;
}
const contains=(p,polygons)=>polygons.some(poly=>pointInPolygon(p,poly));
const redCell=(r,c)=>r>=47&&r<=56&&c>=80&&c<=100;
export function roadCells(points,width){
  const result=new Set(),radius=width/2;
  for(let i=1;i<points.length;i++){
    const a=points[i-1],b=points[i];
    const minC=Math.max(0,Math.floor(Math.min(a[0],b[0])-radius)),maxC=Math.min(179,Math.ceil(Math.max(a[0],b[0])+radius));
    const minR=Math.max(0,Math.floor(Math.min(a[1],b[1])-radius)),maxR=Math.min(199,Math.ceil(Math.max(a[1],b[1])+radius));
    for(let r=minR;r<=maxR;r++)for(let c=minC;c<=maxC;c++)if(segmentDistance([c+.5,r+.5],a,b)<=radius+EPS)result.add(r*180+c);
  }return [...result].sort((a,b)=>a-b);
}
export function components(grid){
  const visited=new Uint8Array(36000),out=[];
  for(let start=0;start<36000;start++){
    const drive=i=>grid[Math.floor(i/180)][i%180]===0||grid[Math.floor(i/180)][i%180]===19;
    if(visited[start]||!drive(start))continue;
    const queue=[start];visited[start]=1;
    for(let k=0;k<queue.length;k++){
      const i=queue[k],r=Math.floor(i/180),c=i%180;
      for(const j of [r>0?i-180:-1,r<199?i+180:-1,c>0?i-1:-1,c<179?i+1:-1])if(j>=0&&!visited[j]&&drive(j)){visited[j]=1;queue.push(j);}
    }
    out.push({cells:queue.length,firstRC:[Math.floor(start/180),start%180]});
  }return out.sort((a,b)=>b.cells-a.cells||a.firstRC[0]-b.firstRC[0]||a.firstRC[1]-b.firstRC[1]);
}

/**
 * Source extensions required for an executable plan:
 * road.width_grid (full drivable width); optional sidewalk_width_grid (each side).
 * bridge.envelope_polygon_grid and road_ids explicitly bind the crossing.
 * green_public.big_beach.polygon_grid explicitly defines sand (no guessed buffer).
 * host.policeProtectedCells is an exact [{r,c,tile}] preservation ledger.
 * Submerged tunnels require a future multilayer graph; never paved over as bridges.
 * A rejected result NEVER publishes a grid. Counts describe analysis only.
 */
export function compileTopology(source,host={}){
  const errors=[],warnings=[];
  const error=(code,id,detail={})=>errors.push({code,id,...detail});
  if(source?.schema!=='mafiozy.city-masterplan/v3')error('SCHEMA','source');
  if(source?.map?.rows!==200||source?.map?.cols!==180)error('MAP_SIZE','map',{expected:SIZE});
  const bounded=p=>finitePoint(p)&&p[0]>=0&&p[0]<=180&&p[1]>=0&&p[1]<=200;
  function polygon(poly,id){
    if(!Array.isArray(poly)||poly.length<3||!poly.every(bounded)){error('POLYGON_BOUNDS',id);return false;}
    let area=0;for(let i=0;i<poly.length;i++){const a=poly[i],b=poly[(i+1)%poly.length];area+=a[0]*b[1]-b[0]*a[1];}
    if(Math.abs(area)<EPS){error('POLYGON_DEGENERATE',id);return false;}
    for(let i=0;i<poly.length;i++)for(let j=i+1;j<poly.length;j++){
      if(j===i+1||(i===0&&j===poly.length-1))continue;
      if(intersects(poly[i],poly[(i+1)%poly.length],poly[j],poly[(j+1)%poly.length])){error('POLYGON_SELF_INTERSECTION',id);return false;}
    }return true;
  }
  function line(points,id){
    if(!Array.isArray(points)||points.length<2||!points.every(bounded)){error('LINE_BOUNDS',id);return false;}return true;
  }
  const water=[],islets=[],sand=[],sidewalks=[];
  for(const body of source?.water?.waterbodies||[])if(polygon(body.polygon_grid,body.id))water.push(body.polygon_grid);
  for(const island of source?.water?.islets||[])if(polygon(island.polygon_grid,island.id))islets.push(island.polygon_grid);
  const beach=source?.green_public?.big_beach;
  if(beach){if(!beach.polygon_grid)error('BEACH_ENVELOPE_REQUIRED',beach.id);else if(polygon(beach.polygon_grid,beach.id))sand.push(beach.polygon_grid);}
  for(const park of source?.green_public?.parks||[])if(polygon(park.polygon_grid,park.id)&&(park.kind==='plaza'||park.kind==='promenade'))sidewalks.push(park.polygon_grid);
  for(const zone of source?.green_public?.pedestrian_zones||[]){
    if(zone.polygon_grid){if(polygon(zone.polygon_grid,zone.id))sidewalks.push(zone.polygon_grid);}
    else if(zone.points_grid)error('PEDESTRIAN_ENVELOPE_REQUIRED',zone.id);
  }
  const immutable=source?.immutable;
  if(JSON.stringify(immutable?.bridge?.rows)!=='[47,56]'||JSON.stringify(immutable?.bridge?.canal_c)!=='[80,100]'||JSON.stringify(immutable?.bridge?.centerline_grid)!=='[[78.25,51.5],[101.75,51.5]]'||immutable?.bridge?.moved!==false)error('IMMUTABLE_RED_BRIDGE_CHANGED','XR-RED-01');
  if(JSON.stringify(immutable?.police_jail?.center_rc)!=='[76,76]'||immutable?.police_jail?.moved!==false)error('IMMUTABLE_POLICE_CHANGED','police_jail');
  const protectedCells=new Map();
  if(!Array.isArray(host.policeProtectedCells)||!host.policeProtectedCells.length)error('EXACT_POLICE_CELLS_REQUIRED','host');
  else for(const cell of host.policeProtectedCells){
    const {r,c,tile}=cell||{};
    if(!Number.isInteger(r)||!Number.isInteger(c)||r<0||r>=200||c<0||c>=180||!Number.isInteger(tile)||tile<0||tile>255){error('PROTECTED_CELL_INVALID','police_jail',{cell});continue;}
    const key=r*180+c;if(protectedCells.has(key))error('PROTECTED_CELL_DUPLICATE','police_jail',{r,c});
    protectedCells.set(key,tile);
  }
  if(protectedCells.size&&!protectedCells.has(76*180+76))error('POLICE_ANCHOR_NOT_PROTECTED','police_jail');
  const roads=[],roadIds=new Set();
  for(const group of groups)for(const road of source?.transport?.[group]||[]){
    if(typeof road.id!=='string'||roadIds.has(road.id))error('ROAD_ID_DUPLICATE_OR_INVALID',road.id??group);roadIds.add(road.id);
    const validLine=line(road.points_grid,road.id),validWidth=Number.isFinite(road.width_grid)&&road.width_grid>0&&road.width_grid<=30;
    if(!validWidth)error('ROAD_WIDTH_REQUIRED',road.id,{group});
    const sw=road.sidewalk_width_grid??0;if(!Number.isFinite(sw)||sw<0||sw>10)error('SIDEWALK_WIDTH_INVALID',road.id);
    roads.push({road,validLine,validWidth,sidewalk:Number.isFinite(sw)&&sw>=0?sw:0});
  }
  const crossings=[];
  for(const crossing of source?.transport?.crossings||[]){
    if(!line(crossing.points_grid,crossing.id))continue;
    if(crossing.mode==='rail')continue; // Independent non-surface rail layer, not car permission.
    if(/tunnel/.test(crossing.kind)){error('MULTILAYER_TUNNEL_UNSUPPORTED',crossing.id);continue;}
    if(crossing.id==='XR-RED-01'){
      if(JSON.stringify(crossing.points_grid)!=='[[78.25,51.5],[101.75,51.5]]')error('IMMUTABLE_RED_BRIDGE_CHANGED',crossing.id);
      continue; // Exact immutable rectangle only; it is not a general water exemption.
    }
    if(!crossing.envelope_polygon_grid){error('CROSSING_ENVELOPE_REQUIRED',crossing.id);continue;}
    const valid=polygon(crossing.envelope_polygon_grid,crossing.id);
    if(!Array.isArray(crossing.road_ids)||!crossing.road_ids.length||crossing.road_ids.some(id=>!roadIds.has(id))){error('CROSSING_ROAD_BINDING_REQUIRED',crossing.id);continue;}
    if(!/bridge/.test(crossing.kind)){error('CROSSING_KIND_UNSUPPORTED',crossing.id);continue;}
    if(valid)crossings.push(crossing);
  }
  const wetPoint=p=>contains(p,water)&&!contains(p,islets);
  const wet=new Uint8Array(36000),grid=Array.from({length:200},()=>Array(180).fill(TILES.grass));
  for(let r=0;r<200;r++)for(let c=0;c<180;c++){
    const p=[c+.5,r+.5],key=r*180+c;wet[key]=wetPoint(p)?1:0;
    if(wet[key])grid[r][c]=TILES.water;
    else if(contains(p,sand))grid[r][c]=TILES.sand;
    else if(contains(p,sidewalks))grid[r][c]=TILES.sidewalk;
  }
  // Exact red deck exists independently of proposed road widths.
  for(let r=47;r<=56;r++)for(let c=80;c<=100;c++)grid[r][c]=TILES.bridge;
  const allowed=(road,p,r,c)=>redCell(r,c)||crossings.some(x=>x.road_ids.includes(road.id)&&pointInPolygon(p,x.envelope_polygon_grid));
  const roadCoverage=[],unauthorized=new Map();
  for(const {road,validLine,validWidth,sidewalk} of roads){
    if(!validLine)continue;
    // Independent centerline audit still works when widths are absent. It does
    // not certify finite-width roads; sample pitch is 0.2 grid units.
    const centerlineWet=[];
    for(let i=1;i<road.points_grid.length;i++){
      const a=road.points_grid[i-1],b=road.points_grid[i],n=Math.max(1,Math.ceil(Math.hypot(b[0]-a[0],b[1]-a[1])*5));
      for(let j=0;j<=n;j++){const t=j/n,p=[a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t];if(wetPoint(p)&&!allowed(road,p,Math.floor(p[1]),Math.floor(p[0]))){if(centerlineWet.length<6)centerlineWet.push(p.map(v=>Math.round(v*1000)/1000));}}
    }
    if(centerlineWet.length)error('ROAD_CENTERLINE_UNAUTHORIZED_WATER',road.id,{sampleCR:centerlineWet});
    if(!validWidth)continue;
    const cells=roadCells(road.points_grid,road.width_grid),blocked=[];
    if(sidewalk)for(const key of roadCells(road.points_grid,road.width_grid+2*sidewalk)){
      const r=Math.floor(key/180),c=key%180;
      if(!wet[key]&&!protectedCells.has(key)&&grid[r][c]!==TILES.bridge&&grid[r][c]!==TILES.road)grid[r][c]=TILES.sidewalk;
    }
    for(const key of cells){
      const r=Math.floor(key/180),c=key%180,p=[c+.5,r+.5];
      if(protectedCells.has(key)){if(protectedCells.get(key)!==TILES.road&&protectedCells.get(key)!==TILES.bridge)blocked.push([r,c]);continue;}
      if(wet[key]&&!allowed(road,p,r,c)){unauthorized.set(key,[r,c]);continue;}
      grid[r][c]=redCell(r,c)||wet[key]?TILES.bridge:TILES.road;
    }
    if(blocked.length)error('ROAD_POLICE_PROTECTION_CONFLICT',road.id,{count:blocked.length,sampleRC:blocked.slice(0,8)});
    if(!cells.length)error('ROAD_RASTER_EMPTY',road.id);
    roadCoverage.push({id:road.id,widthGrid:road.width_grid,rasterCells:cells.length});
  }
  if(unauthorized.size)error('ROAD_FOOTPRINT_UNAUTHORIZED_WATER','road-grid',{count:unauthorized.size,sampleRC:[...unauthorized.values()].slice(0,20)});
  for(const [key,tile] of protectedCells){
    const r=Math.floor(key/180),c=key%180;
    if(wet[key])error('POLICE_WATER_CONFLICT','police_jail',{r,c});
    if(redCell(r,c)&&tile!==TILES.bridge)error('POLICE_RED_BRIDGE_CONFLICT','police_jail',{r,c});
    grid[r][c]=tile;
  }
  const connectivity=components(grid);
  if(connectivity.length!==1)error('ROAD_GRID_DISCONNECTED','roads',{componentCount:connectivity.length,components:connectivity.slice(0,20)});
  if(!roadCoverage.length)error('NO_ROADS_COMPILED','roads');
  // Final invariants, separate from source-raster pass.
  let badWater=0,redChanged=0;const counts={};
  for(let r=0;r<200;r++)for(let c=0;c<180;c++){
    const tile=grid[r][c];counts[tile]=(counts[tile]||0)+1;
    if(tile===TILES.road&&wet[r*180+c])badWater++;
    if(redCell(r,c)&&tile!==TILES.bridge)redChanged++;
  }
  if(badWater)error('FINAL_ROAD_ON_WATER','grid',{count:badWater});
  if(redChanged)error('FINAL_RED_BRIDGE_CHANGED','grid',{count:redChanged});
  const compare=(a,b)=>a.code<b.code?-1:a.code>b.code?1:String(a.id)<String(b.id)?-1:String(a.id)>String(b.id)?1:0;
  errors.sort(compare);
  warnings.push({code:'RUNTIME_NOT_CONNECTED',detail:'No gameplay, buildings, vehicles, rail or spawn migration is performed.'});
  const status=errors.length?'REJECTED':'CANDIDATE_TOPOLOGY_ONLY';
  return {schema:'mafiozy.native-topology-candidate/v1',status,map:{...SIZE},tiles:{...TILES},sourceVersion:source?.version??null,
    grid:errors.length?null:grid,validation:{errors,warnings,counts,waterMaskCells:wet.reduce((a,b)=>a+b,0),roadCoverage,connectivity,
      policeProtectedCellCount:protectedCells.size,immutableRedBridgeCells:210,allCells:36000}};
}
