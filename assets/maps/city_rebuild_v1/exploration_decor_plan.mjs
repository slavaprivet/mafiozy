/** Deterministic world-metres placement. The original city, IDs and roads are read-only. */
export const EXPLORATION_DECOR_VERSION = 1;
const TAU = Math.PI * 2;
const TYPES = {
  pine: {radius:2.85, ground:.34, height:8, label:'Сосна'},
  spruce: {radius:2.15, ground:.34, height:7.786, label:'Ель'},
  oak: {radius:2.65, ground:.38, height:6.35, label:'Дуб'},
  birch: {radius:1.85, ground:.24, height:6.8, label:'Берёза'},
  cypress: {radius:1.2, ground:.25, height:7.3, label:'Кипарис'},
  cedar: {radius:2.55, ground:.42, height:8.1, label:'Кедр'},
  willow: {radius:2.85, ground:.42, height:6.25, label:'Ива'},
  rock: {radius:1.15, ground:1.05, height:1.35, label:'Валун'},
  shrub: {radius:.85, ground:0, height:1, label:'Кустарник'},
  bench: {radius:1.5, ground:1.3, height:1.1, label:'Скамья'},
  planter: {radius:1.05, ground:.72, height:1.2, label:'Цветочная чаша'},
  fountain: {radius:3, ground:2.65, height:3.7, label:'Каскадный фонтан'},
  monument: {radius:2.1, ground:1.65, height:5.2, label:'Памятник основателям'},
  armillary: {radius:2.1, ground:1.5, height:4.8, label:'Латунная сфера'},
  clock: {radius:1.1, ground:.55, height:4.8, label:'Городские часы'},
  kiosk: {radius:1.7, ground:1.3, height:2.8, label:'Афишная тумба'},
  bin: {radius:.6, ground:.42, height:1.1, label:'Урна'},
  lamp: {radius:.8, ground:.22, height:3.9, label:'Парковый фонарь'},
  picnic: {radius:2, ground:1.65, height:.95, label:'Стол для пикника'},
  sign: {radius:.95, ground:.22, height:2.45, label:'Указатель троп'},
  telescope: {radius:1, ground:.6, height:1.7, label:'Смотровой бинокль'},
};
export const EXPLORATION_DECOR_TYPES = Object.freeze(TYPES);
export const TREE_SPECIES=Object.freeze(['pine','spruce','oak','birch','cypress','cedar','willow']);
export const TREE_SIZE_CLASSES=Object.freeze({sapling:{min:2.2,max:4.1,crown:.75,trunk:.72},adult:{min:6.2,max:10.5,crown:1,trunk:1},large:{min:12,max:17.5,crown:1.08,trunk:1.25},giant:{min:21,max:28.5,crown:1.15,trunk:1.4}});
function random(seed) { let a=seed>>>0; return () => {a=(a+0x6D2B79F5)|0;let t=Math.imul(a^a>>>15,1|a);t^=t+Math.imul(t^t>>>7,61|t);return ((t^t>>>14)>>>0)/4294967296;}; }
const circleRect = (x,z,r,b) => Math.hypot(Math.max(b.minX-x,0,x-b.maxX),Math.max(b.minZ-z,0,z-b.maxZ)) < r;
const rectCR = (b,m) => b&&Number.isFinite(b.minC)?{minX:b.minC*m,maxX:b.maxC*m,minZ:b.minR*m,maxZ:b.maxR*m}:null;
const polygonRect = (p,m) => p?.length?{minX:Math.min(...p.map(v=>v[0]))*m,maxX:Math.max(...p.map(v=>v[0]))*m,minZ:Math.min(...p.map(v=>v[1]))*m,maxZ:Math.max(...p.map(v=>v[1]))*m}:null;

export function planExplorationDecor({terrain,topology,metresPerCell=4.1,keepouts=[],buildings=[],existingDecor=[],railPlan=null,seed=91426,maxTrees=2000,maxCityVignettes=18}={}) {
  if(!terrain||typeof terrain.groundHeight!=='function'||!Array.isArray(topology?.grid))throw Error('Exploration decor requires terrain and the current city topology');
  const m=metresPerCell,grid=topology.grid,cityWidth=grid[0].length*m,cityDepth=grid.length*m,rng=random(seed);
  const forbidden=[...keepouts];
  for(const b of buildings){for(const r of[b.clearance,b.footprint,b.entryCorridor]){const q=rectCR(r,m);if(q)forbidden.push(q);}for(const body of b.collision?.worldBodies||[]){const q=polygonRect(body.polygonCR,m);if(q)forbidden.push(q);}}
  for(const d of existingDecor){const q=polygonRect(d.clearancePolygonCR,m);if(q)forbidden.push(q);for(const body of d.collision?.worldBodies||[]){const p=polygonRect(body.polygonCR,m);if(p)forbidden.push(p);}}
  for(const crossing of topology.crossings||[])for(const p of[crossing.no_build_envelope_polygon_grid_cr,crossing.deck_envelope_polygon_grid_cr]){const q=polygonRect(p,m);if(q)forbidden.push(q);}
  // Preserve the red bridge and its approaches even in an incomplete topology ledger.
  forbidden.push({minX:78.25*m,maxX:101.75*m,minZ:47*m,maxZ:57*m});
  const objects=[],colliders=[],mapFeatures=[],skipped={},vignettes=[],spatial=new Map(),bucketSize=12;
  let largestPlacedRadius=0;
  const key=(x,z)=>`${Math.floor(x/bucketSize)},${Math.floor(z/bucketSize)}`;
  function neighbors(x,z,r){const out=[],pad=r+largestPlacedRadius+.6;for(let iz=Math.floor((z-pad)/bucketSize);iz<=Math.floor((z+pad)/bucketSize);iz++)for(let ix=Math.floor((x-pad)/bucketSize);ix<=Math.floor((x+pad)/bucketSize);ix++)out.push(...(spatial.get(`${ix},${iz}`)||[]));return out;}
  function safe(x,z,r,{extension=false,maxSlope=.7}={}){
    if(!Number.isFinite(x+z+r)||forbidden.some(b=>circleRect(x,z,r+.8,b)))return false;
    if(railPlan?.blocksPlacement(x,z,r+.8))return false;
    const inside=x>=0&&x<cityWidth&&z>=0&&z<cityDepth;
    if(extension&&inside)return false;
    if(inside){
      for(let rr=Math.floor((z-r)/m);rr<=Math.floor((z+r)/m);rr++)for(let cc=Math.floor((x-r)/m);cc<=Math.floor((x+r)/m);cc++){
        if(!circleRect(x,z,r,{minX:cc*m,maxX:(cc+1)*m,minZ:rr*m,maxZ:(rr+1)*m}))continue;
        if(![8,9,14].includes(grid[rr]?.[cc])||topology.policeMask?.[rr]?.[cc])return false;
      }
    }else{
      if(!terrain.contains(x,z))return false;
      for(let i=0;i<48;i++){
        const px=x+Math.cos(i*TAU/48)*(r+.25),pz=z+Math.sin(i*TAU/48)*(r+.25);
        if(!terrain.contains(px,pz)||terrain.waterAt(px,pz))return false;
        const path=terrain.pathAt?.(px,pz);if(path&&path.distance<(path.path?.width??4)/2+2)return false;
      }
      if(terrain.waterAt(x,z))return false;
      const path=terrain.pathAt?.(x,z);if(path&&path.distance<(path.path?.width??4)/2+r+2)return false;
    }
    const y=terrain.groundHeight(x,z);
    if(!Number.isFinite(y))return false;
    for(let i=0;i<8;i++){const a=i*TAU/8,py=terrain.groundHeight(x+Math.cos(a)*r,z+Math.sin(a)*r);if(!Number.isFinite(py)||Math.abs(py-y)>maxSlope*r)return false;}
    return true;
  }
  function place(kind,x,z,{scale=1,yaw=0,zone='city',id,variant=0,maxSlope,skipOverlap=false,sizeClass=null}={}){
    const spec=TYPES[kind],tree=TREE_SPECIES.includes(kind),sizeSpec=tree?TREE_SIZE_CLASSES[sizeClass||'adult']:null,r=spec.radius*scale*(sizeSpec?.crown||1);
    if(!safe(x,z,r,{extension:zone!=='city',maxSlope:maxSlope??(zone==='city'?.1:.7)})||(!skipOverlap&&neighbors(x,z,r).some(p=>Math.hypot(p.x-x,p.z-z)<p.radius+r+.6))){skipped[kind]=(skipped[kind]||0)+1;return null;}
    const item={id:id||`explore-${kind}-${objects.length}`,kind,x,z,y:terrain.groundHeight(x,z),scale,yaw,variant,zone,radius:r,...(tree?{sizeClass:sizeClass||'adult',height:spec.height*scale}:{})};
    objects.push(item);largestPlacedRadius=Math.max(largestPlacedRadius,r);const k=key(x,z);if(!spatial.has(k))spatial.set(k,[]);spatial.get(k).push(item);
    const bodyRadius=spec.ground*scale*(sizeSpec?.trunk||1);
    if(bodyRadius){
      // Trees collide with their trunks, never the AABB of overhead foliage.
      const placementPolygonCR=Array.from({length:12},(_,i)=>[(x+Math.cos(i*TAU/12)*bodyRadius)/m,(z+Math.sin(i*TAU/12)*bodyRadius)/m]);
      // Long furniture needs its actual oriented footprint: a circumscribed
      // trunk-style circle otherwise blocks empty pavement in front of a bench.
      // Keep the original circle for placement consumers, so shrinking physical
      // collision does not move the decor or surrounding road dressing.
      const halfSize=kind==='bench'?[1.3,.39]:kind==='picnic'?[1.35,.99]:null;
      const polygonCR=halfSize?[[ -1,-1],[1,-1],[1,1],[-1,1]].map(([sx,sz])=>{
        const lx=sx*halfSize[0]*scale,lz=sz*halfSize[1]*scale;
        return [(x+lx*Math.cos(yaw)+lz*Math.sin(yaw))/m,(z-lx*Math.sin(yaw)+lz*Math.cos(yaw))/m];
      }):placementPolygonCR;
      colliders.push({id:item.id,node:`${kind}_ground`,polygonCR,minYM:item.y,maxYM:item.y+spec.height*scale,source:'exploration_decor',groundRadius:bodyRadius,...(halfSize?{placementKeepoutPolygonCR:placementPolygonCR}:{})});
    }
    const mapType=tree?'tree':kind;
    mapFeatures.push({id:item.id,type:mapType,kind:mapType,name:(sizeClass==='giant'?'Вековой ':sizeClass==='sapling'?'Молодой ':'')+spec.label,x,z,y:item.y,radius:r,zone,icon:kind,...(tree?{sizeClass:item.sizeClass,height:item.height}:{})});
    return item;
  }
  function vignette(x,z,index,zone='city',landmarkName){
    const kinds=['fountain','monument','armillary','clock','kiosk'],central=zone==='city'?kinds[index%kinds.length]:(index%3===0?'armillary':index%3===1?'picnic':'telescope');
    const focus=place(central,x,z,{zone,id:`explore-${zone}-focus-${index}`,yaw:index*.8,maxSlope:.13});
    if(!focus)return false;
    const radius=central==='fountain'?6:4.8,rotation=index*.73;
    for(let i=0;i<4;i++){
      const a=rotation+i*TAU/4,px=x+Math.sin(a)*radius,pz=z+Math.cos(a)*radius;
      place(i%2===0?'bench':zone==='city'?'planter':'rock',px,pz,{zone,yaw:a+Math.PI,variant:index%3,maxSlope:.15});
    }
    for(let i=0;i<2;i++){const a=rotation+(i+.5)*Math.PI;place(zone==='city'?'lamp':'sign',x+Math.sin(a)*(radius+2.6),z+Math.cos(a)*(radius+2.6),{zone,yaw:a,maxSlope:.2});}
    if(zone==='city')place('bin',x+Math.sin(rotation+.8)*radius,z+Math.cos(rotation+.8)*radius,{zone,yaw:rotation});
    vignettes.push({id:focus.id,x,z,kind:central,zone,name:landmarkName||TYPES[central].label});
    if(landmarkName)mapFeatures.find(p=>p.id===focus.id).name=landmarkName;
    return true;
  }
  // Walkable existing grass/sidewalk pockets near roads, distributed across districts.
  const cityCandidates=[];
  for(let r=3;r<grid.length-3;r+=2)for(let c=3;c<grid[r].length-3;c+=2){
    if(![8,9].includes(grid[r][c]))continue;
    let roadDistance=Infinity;for(let rr=r-5;rr<=r+5;rr++)for(let cc=c-5;cc<=c+5;cc++)if(grid[rr]?.[cc]===0)roadDistance=Math.min(roadDistance,Math.hypot(rr-r,cc-c)*m);
    if(roadDistance>=7&&roadDistance<=22)cityCandidates.push({x:(c+.5)*m,z:(r+.5)*m,score:rng()});
  }
  cityCandidates.sort((a,b)=>a.score-b.score);
  for(const p of cityCandidates){if(vignettes.filter(v=>v.zone==='city').length>=maxCityVignettes)break;if(vignettes.some(v=>Math.hypot(v.x-p.x,v.z-p.z)<65))continue;vignette(p.x,p.z,vignettes.length);}
  // Trail-side destinations sit off the hiking corridor, never in the route itself.
  let ruralIndex=0;
  for(const landmark of terrain.landmarks||[]){
    let placed=false;
    for(let ring=7;ring<=22&&!placed;ring+=5)for(let i=0;i<8&&!placed;i++){const a=i*TAU/8;placed=vignette(landmark.x+Math.cos(a)*ring,landmark.z+Math.sin(a)*ring,ruralIndex,'rural',landmark.name);}
    if(placed)ruralIndex++;
  }
  for(const path of terrain.paths||[]){const points=path.points||[];for(let i=2;i<points.length-2;i+=Math.max(3,Math.floor(points.length/3))){
    const p=points[i],prev=points[i-1],next=points[i+1],a=Math.atan2(next.z-prev.z,next.x-prev.x)+Math.PI/2;
    const distance=(path.width||4)/2+7;
    for(const side of[1,-1]){if(vignette(p.x+Math.cos(a)*distance*side,p.z+Math.sin(a)*distance*side,ruralIndex,'rural')){ruralIndex++;break;}}
  }}
  for(const path of terrain.paths||[])for(let i=8;i<path.points.length-8;i+=75){
    const p=path.points[i],q=path.points[i+1],a=Math.atan2(q.z-p.z,q.x-p.x)+Math.PI/2,d=(path.width||4)/2+5;
    for(const side of[1,-1])if(place('sign',p.x+Math.cos(a)*d*side,p.z+Math.sin(a)*d*side,{zone:'rural',yaw:-a,maxSlope:.5}))break;
  }
  let treeCount=0;
  const forestWeight=(terrain.forestZones||[]).reduce((n,z)=>n+Math.sqrt(z.rx*z.rz),0);
  for(const [zi,zone]of(terrain.forestZones||[]).entries()){
    const area=Math.PI*zone.rx*zone.rz,attempts=Math.min(5500,Math.ceil(area/20)),quota=Math.floor(maxTrees*Math.sqrt(zone.rx*zone.rz)/forestWeight);
    let zoneTrees=0;
    // Old specimen trees get room before ordinary scatter. Five per woodland,
    // placed in a loose outer ring around its centre, with full enlarged crown checks.
    let giants=0;
    for(let i=0;i<250&&giants<5&&treeCount<maxTrees;i++){
      const a=rng()*TAU,rad=.35+Math.sqrt(rng())*.5,x=zone.x+Math.cos(a)*rad*zone.rx,z=zone.z+Math.sin(a)*rad*zone.rz;
      const kind=['pine','cedar','oak','spruce','cedar'][zi%5],height=21+rng()*7.5,scale=height/TYPES[kind].height;
      if(place(kind,x,z,{zone:zone.id||'forest',scale,yaw:rng()*TAU,variant:zi%4,sizeClass:'giant'})){giants++;treeCount++;zoneTrees++;}
    }
    for(let i=0;i<attempts&&treeCount<maxTrees&&zoneTrees<quota;i++){
      const a=rng()*TAU,rad=Math.sqrt(rng()),x=zone.x+Math.cos(a)*rad*zone.rx,z=zone.z+Math.sin(a)*rad*zone.rz;
      // Dense groves alternate with soft-edged clearings, not an artificial grid.
      const clearing=.5+.24*Math.sin(x*.038+zi)*Math.cos(z*.027-zi),density=Math.min(1,(zone.density??.85));
      if(rng()>density*clearing*1.6)continue;
      const nearShore=(terrain.lakes||[]).some(l=>{const r=terrain.lakeRadius?terrain.lakeRadius(l,x,z):Math.hypot((x-l.x)/l.rx,(z-l.z)/l.rz);return r>1&&(r-1)*Math.min(l.rx,l.rz)<32;});
      const selector=rng(),kind=nearShore&&selector>.6?'willow':zi%3===0?(selector<.37?'pine':selector<.65?'spruce':selector<.86?'birch':'cedar'):zi%3===1?(selector<.4?'cedar':selector<.63?'pine':selector<.82?'spruce':'oak'):(selector<.42?'oak':selector<.65?'birch':selector<.83?'cypress':'spruce');
      const age=rng(),nursery=Math.sin(x*.08+zi)*Math.cos(z*.06-zi)>.42,sizeClass=age<(nursery?.57:.22)?'sapling':age<.91?'adult':'large',size=TREE_SIZE_CLASSES[sizeClass],height=size.min+rng()*(size.max-size.min),scale=height/TYPES[kind].height;
      if(place(kind,x,z,{zone:zone.id||'forest',scale,yaw:rng()*TAU,variant:Math.floor(rng()*4),sizeClass})){treeCount++;zoneTrees++;}
    }
    for(let i=0;i<Math.min(85,Math.round(area/650));i++){
      const a=rng()*TAU,rad=Math.sqrt(rng()),x=zone.x+Math.cos(a)*rad*zone.rx,z=zone.z+Math.sin(a)*rad*zone.rz;
      place(i%3===0?'rock':'shrub',x,z,{zone:zone.id||'forest',scale:.65+rng()*.85,yaw:rng()*TAU,variant:zi%4});
    }
  }
  // Small planted groups make the built city feel related to the surrounding landscape.
  for(const v of vignettes.filter(v=>v.zone==='city'))for(let i=0;i<5;i++){const a=i*TAU/5,kind=i%2?'cypress':'oak',sizeClass=i%3===0?'sapling':'adult',height=sizeClass==='sapling'?3:6.4;place(kind,v.x+Math.sin(a)*11,v.z+Math.cos(a)*11,{scale:height/TYPES[kind].height,variant:i%3,yaw:a,sizeClass});}
  const counts={},treeSizeCounts={sapling:0,adult:0,large:0,giant:0};for(const p of objects){counts[p.kind]=(counts[p.kind]||0)+1;if(p.sizeClass)treeSizeCounts[p.sizeClass]++;}
  return {version:EXPLORATION_DECOR_VERSION,objects,colliders,mapFeatures,vignettes,stats:{objects:objects.length,trees:treeCount,treeSizeCounts,colliders:colliders.length,cityVignettes:vignettes.filter(v=>v.zone==='city').length,ruralVignettes:ruralIndex,counts,skipped},placement:{metresPerCell:m,seed,canopiesAreNotColliders:true},};
}
