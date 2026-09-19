/** Small, dense grass islands over the current immutable world surface. World metres. */
export const GRASS_LIMITS=Object.freeze({maxTufts:90000,chunkSize:64,viewDistance:105,fadeStart:66,maxVisibleTufts:1200,maxVisibleTriangles:90000,maxVisibleBatches:24});
export const GRASS_PALETTE=Object.freeze([0x70824c,0x849259,0x627b50,0x9a9d66,0x788d62,0xb0a77b]);
function seeded(seed){let n=seed>>>0;return()=>{n=(n+0x6D2B79F5)|0;let t=Math.imul(n^n>>>15,1|n);t^=t+Math.imul(t^t>>>7,61|t);return((t^t>>>14)>>>0)/4294967296;};}
const TAU=Math.PI*2;
const polygonRect=(p,m)=>p?.length?{minX:Math.min(...p.map(v=>v[0]))*m,maxX:Math.max(...p.map(v=>v[0]))*m,minZ:Math.min(...p.map(v=>v[1]))*m,maxZ:Math.max(...p.map(v=>v[1]))*m}:null;
const rectCR=(r,m)=>r&&Number.isFinite(r.minC)?{minX:r.minC*m,maxX:r.maxC*m,minZ:r.minR*m,maxZ:r.maxR*m}:null;
const circleRect=(x,z,r,b)=>Math.hypot(Math.max(b.minX-x,0,x-b.maxX),Math.max(b.minZ-z,0,z-b.maxZ))<r;
export function planEnvironmentGrass({topology,landscape,railPlan=null,keepouts=[],buildings=[],existingDecor=[],decorPlan=null,metresPerCell=4.1,seed=90927,maxTufts=GRASS_LIMITS.maxTufts}={}){
  if(!Array.isArray(topology?.grid)||!landscape?.groundHeight)throw Error('Grass requires current topology and landscape');
  const m=metresPerCell,rng=seeded(seed),grid=topology.grid,rects=[...keepouts],forbiddenBuckets=new Map(),bucketSize=24;
  for(const b of buildings)for(const key of['clearance','footprint','entryCorridor']){const r=rectCR(b[key],m);if(r)rects.push(r);}
  for(const d of existingDecor){const r=polygonRect(d.clearancePolygonCR,m);if(r)rects.push(r);for(const b of d.collision?.worldBodies||[]){const q=polygonRect(b.polygonCR,m);if(q)rects.push(q);}}
  // Grass belongs under the canopy, but never through a trunk or a fountain base.
  for(const b of decorPlan?.colliders||[]){const r=polygonRect(b.polygonCR,m);if(r)rects.push(r);}
  for(const c of topology.crossings||[])for(const p of[c.no_build_envelope_polygon_grid_cr,c.deck_envelope_polygon_grid_cr]){const r=polygonRect(p,m);if(r)rects.push(r);}
  rects.push({minX:78.25*m,maxX:101.75*m,minZ:47*m,maxZ:57*m});
  for(const r of rects)for(let iz=Math.floor((r.minZ-3)/bucketSize);iz<=Math.floor((r.maxZ+3)/bucketSize);iz++)for(let ix=Math.floor((r.minX-3)/bucketSize);ix<=Math.floor((r.maxX+3)/bucketSize);ix++){const k=ix+','+iz;if(!forbiddenBuckets.has(k))forbiddenBuckets.set(k,[]);forbiddenBuckets.get(k).push(r);}
  function eligible(x,z,r=.34){
    if((forbiddenBuckets.get(Math.floor(x/bucketSize)+','+Math.floor(z/bucketSize))||[]).some(b=>circleRect(x,z,r+.16,b)))return false;
    if(railPlan?.blocksPlacement(x,z,r+.35))return false;
    const city=x>=0&&x<grid[0].length*m&&z>=0&&z<grid.length*m;
    if(city){
      for(let rr=Math.floor((z-r)/m);rr<=Math.floor((z+r)/m);rr++)for(let cc=Math.floor((x-r)/m);cc<=Math.floor((x+r)/m);cc++)if(circleRect(x,z,r,{minX:cc*m,maxX:(cc+1)*m,minZ:rr*m,maxZ:(rr+1)*m})&&(grid[rr]?.[cc]!==8||topology.policeMask?.[rr]?.[cc]))return false;
    }else{
      for(let i=0;i<8;i++){const a=i*TAU/8,px=x+Math.cos(a)*(r+.2),pz=z+Math.sin(a)*(r+.2);if(!landscape.contains(px,pz)||landscape.waterAt(px,pz))return false;const p=landscape.pathAt(px,pz);if(p.path&&p.distance<p.path.width/2+.5)return false;}
      if(!landscape.contains(x,z)||landscape.waterAt(x,z)||landscape.slopeAt(x,z)>.54)return false;
    }
    return true;
  }
  const tufts=[],patches=[],tuftBuckets=new Map(),patchBuckets=new Map(),counts={lawn:0,trail:0,woodland:0,shore:0},candidates={lawn:[],trail:[],woodland:[],shore:[]};
  const tuftKey=(x,z)=>Math.floor(x*2)+','+Math.floor(z*2);
  const patchKey=(x,z)=>Math.floor(x/10)+','+Math.floor(z/10);
  function addTuft(px,pz,zone,id,{low=false,shrub=false}={}){
    const key=tuftKey(px,pz);if(tuftBuckets.has(key)||tufts.length>=maxTufts)return false;
    const height=shrub?.65+rng()*.75:low?.23+rng()*.28:(zone==='shore'?.48:zone==='woodland'?.4:.34)+rng()*.53;
    const width=shrub?1.1+rng()*.6:.85+rng()*.5,style=shrub?'shrub':zone==='shore'||rng()>.86?'reed':'grass';
    // Full wind + maximum contact lean envelope, including the authored leaf spread.
    const clearance=Math.max((shrub?.63:.39)*width+height*(shrub?.23:.78),shrub?0:.6);
    if(!eligible(px,pz,clearance))return false;
    const tone=zone==='shore'?4:zone==='woodland'?2:zone==='lawn'?(rng()<.5?0:1):Math.floor(rng()*GRASS_PALETTE.length);
    const slopeX=(landscape.groundHeight(px+.15,pz)-landscape.groundHeight(px-.15,pz))/.3,slopeZ=(landscape.groundHeight(px,pz+.15)-landscape.groundHeight(px,pz-.15))/.3;
    tufts.push({id:'grass-'+tufts.length,patchId:id,x:px,z:pz,y:landscape.groundHeight(px,pz)-.015,slopeX,slopeZ,height,width,yaw:rng()*TAU,phase:rng()*TAU,style,color:GRASS_PALETTE[tone],radius:clearance,zone});tuftBuckets.set(key,true);counts[zone]++;return true;
  }
  function freePatch(x,z){for(let iz=Math.floor(z/10)-1;iz<=Math.floor(z/10)+1;iz++)for(let ix=Math.floor(x/10)-1;ix<=Math.floor(x/10)+1;ix++)for(const p of patchBuckets.get(ix+','+iz)||[])if(Math.hypot(p.x-x,p.z-z)<6.5)return false;return true;}
  function addPatch(candidate){
    const {x,z,zone}=candidate;if(!eligible(x,z)||!freePatch(x,z))return false;
    const radius=zone==='lawn'?3.2+rng()*2.5:zone==='woodland'?2.8+rng()*2:2.1+rng()*2.6,aspect=.55+rng()*.65,yaw=rng()*TAU,cos=Math.cos(yaw),sin=Math.sin(yaw),wanted=zone==='lawn'?38:zone==='trail'?43:35,id='grass-patch-'+patches.length,start=tufts.length;
    for(let i=0;i<wanted*4&&tufts.length-start<wanted&&tufts.length<maxTufts;i++){
      const a=rng()*TAU,d=Math.sqrt(rng())*radius,dx=Math.cos(a)*d,dz=Math.sin(a)*d*aspect,px=x+cos*dx-sin*dz,pz=z+sin*dx+cos*dz;
      addTuft(px,pz,zone,id);
    }
    if(tufts.length===start)return false;
    const patch={id,x,z,radius,aspect,yaw,zone,tufts:tufts.length-start};patches.push(patch);const k=patchKey(x,z);if(!patchBuckets.has(k))patchBuckets.set(k,[]);patchBuckets.get(k).push(patch);return true;
  }
  // Every eligible native lawn cell gets a dense, mostly short understory. Keep the
  // taller accent tufts rare so the lawn reads as continuous turf instead of islands.
  for(let r=1;r<grid.length-1;r++)for(let c=1;c<grid[r].length-1;c++)if(grid[r][c]===8){
    const density=7+Math.floor((.5+.5*Math.sin(c*.61+r*.27))*4);
    for(let i=0;i<density;i++)addTuft((c+.08+rng()*.84)*m,(r+.08+rng()*.84)*m,'lawn','lawn-understory-'+r+'-'+c,{low:i%5!==0});
  }
  // Continuous but ragged shoreline belts, plus taller dense islands below.
  for(const l of landscape.lakes||[])for(let i=0;i<500;i++){
    const a=i*TAU/500;
    for(let j=0;j<10;j++){const d=1.04+j*.028+rng()*.025;addTuft(l.x+Math.cos(a)*l.rx*d,l.z+Math.sin(a)*l.rz*d,'shore','shore-understory-'+l.id,{low:j%4===0});}
  }
  // The tour points are on open trails: the entire near verge needs vegetation,
  // not only islands separated by fifteen metres along the route.
  for(const path of landscape.paths||[])for(let i=1;i<path.points.length-1;i++){
    const p=path.points[i],q=path.points[i+1],a=Math.atan2(q.z-p.z,q.x-p.x)+Math.PI/2;
    for(const side of[-1,1])for(let j=0;j<3;j++){
      const offset=path.width/2+1.45+j*1.15+rng()*.65;
      addTuft(p.x+Math.cos(a)*offset*side+(rng()-.5)*1.2,p.z+Math.sin(a)*offset*side+(rng()-.5)*1.2,'trail','verge-'+path.id,{low:j===0});
    }
  }
  // Short tufts in existing native lawns, never road/sidewalk tiles.
  for(let r=1;r<grid.length-1;r+=2)for(let c=1;c<grid[r].length-1;c+=2)if(grid[r][c]===8)candidates.lawn.push({x:(c+.25+rng()*.5)*m,z:(r+.25+rng()*.5)*m,zone:'lawn',score:rng()});
  // Trail verges are composed as irregular islands with an open walking corridor.
  for(const path of landscape.paths||[])for(let i=2;i<path.points.length-2;i+=5){const p=path.points[i],q=path.points[i+1],a=Math.atan2(q.z-p.z,q.x-p.x)+Math.PI/2;for(const side of[-1,1]){const offset=path.width/2+2.5+rng()*3.2;candidates.trail.push({x:p.x+Math.cos(a)*offset*side,z:p.z+Math.sin(a)*offset*side,zone:'trail',score:rng()});}}
  for(const f of landscape.forestZones||[])for(let i=0;i<110;i++){const a=rng()*TAU,r=Math.sqrt(rng());candidates.woodland.push({x:f.x+Math.cos(a)*f.rx*r,z:f.z+Math.sin(a)*f.rz*r,zone:'woodland',score:rng()});}
  for(const l of landscape.lakes||[])for(let i=0;i<110;i++){const a=rng()*TAU,r=1.08+rng()*.2;candidates.shore.push({x:l.x+Math.cos(a)*l.rx*r,z:l.z+Math.sin(a)*l.rz*r,zone:'shore',score:rng()});}
  const caps={lawn:160,trail:300,woodland:110,shore:52};
  for(const zone of['lawn','trail','shore','woodland']){candidates[zone].sort((a,b)=>a.score-b.score);let accepted=0;for(const p of candidates[zone]){if(accepted>=caps[zone]||tufts.length>=maxTufts)break;if(addPatch(p))accepted++;}}
  for(const f of landscape.forestZones||[])for(let i=0;i<100;i++){const a=rng()*TAU,d=Math.sqrt(rng());addTuft(f.x+Math.cos(a)*f.rx*d,f.z+Math.sin(a)*f.rz*d,'woodland','shrub-'+f.id,{shrub:true});}
  return {version:2,tufts,patches,stats:{tufts:tufts.length,patches:patches.length,counts,shrubs:tufts.filter(t=>t.style==='shrub').length,seed,maxTufts},limits:{...GRASS_LIMITS},policy:{collision:false,mapMarkerPerBlade:false,rootsFixed:true,sourceWorldUnchanged:true}};
}
