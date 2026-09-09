// Bridges native placement metadata and the new optional landscape layer.
export function explorationKeepouts(instances,metresPerCell=4.1){
 const out=[];
 for(const item of instances){
  for(const b of [item.clearance,item.footprint,item.entryCorridor].filter(Boolean))if(Number.isFinite(b.minC))out.push({minX:b.minC*metresPerCell,maxX:b.maxC*metresPerCell,minZ:b.minR*metresPerCell,maxZ:b.maxR*metresPerCell});
  for(const p of [item.clearancePolygonCR,...(item.collision?.worldBodies||[]).map(b=>b.placementKeepoutPolygonCR||b.polygonCR)].filter(p=>p?.length)){
   const xs=p.map(p=>p[0]*metresPerCell),zs=p.map(p=>p[1]*metresPerCell);out.push({minX:Math.min(...xs),maxX:Math.max(...xs),minZ:Math.min(...zs),maxZ:Math.max(...zs)});
  }
 }
 return out;
}

export function resolveLandscapeCamera(from,desired,terrain,clearance=.35){
 if(!terrain)return {...desired};
 const distance=Math.hypot(desired.x-from.x,desired.y-from.y,desired.z-from.z),steps=Math.max(1,Math.ceil(distance/.4));
 let previous={...from};
 for(let i=1;i<=steps;i++){
  const t=i/steps,p={x:from.x+(desired.x-from.x)*t,y:from.y+(desired.y-from.y)*t,z:from.z+(desired.z-from.z)*t};
  if(terrain.contains(p.x,p.z)&&p.y<terrain.groundHeight(p.x,p.z)+clearance)return previous;
  previous=p;
 }
 return previous;
}
