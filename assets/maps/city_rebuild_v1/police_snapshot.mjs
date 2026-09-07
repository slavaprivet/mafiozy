/** Capture ONLY immutable police cells from a built host MAP. No tile values,
 * radius or geometry are inferred. Bounds/shape descriptors must be explicit.
 * A cell is protected when its unit-square footprint has positive-area overlap.
 * Boundary-only contact does not grow the protected region by an extra row.
 */
export function policeCellOverlapsShape(r,c,shape){
  if(shape.shape==='circle'){
    const [cr,cc]=shape.centerRC||[];
    if(![cr,cc,shape.radiusGrid].every(Number.isFinite)||shape.radiusGrid<=0)throw new Error('Invalid police circle');
    const dr=Math.max(r-cr,0,cr-(r+1)),dc=Math.max(c-cc,0,cc-(c+1));
    return dr*dr+dc*dc<shape.radiusGrid*shape.radiusGrid;
  }
  if(!['aabb','aabb_grid_cells'].includes(shape.shape))throw new Error('Unsupported police protection shape');
  const b=shape.bounds,minR=b?.minR,minC=b?.minC,maxR=b?.maxRExclusive??b?.maxR,maxC=b?.maxCExclusive??b?.maxC;
  if(![minR,minC,maxR,maxC].every(Number.isFinite)||maxR<=minR||maxC<=minC)throw new Error('Invalid police bounds');
  return r+1>minR&&r<maxR&&c+1>minC&&c<maxC;
}
export function capturePoliceProtectedCells(oldMAP,immutableGeometry,solidRects=[]){
  if(!Array.isArray(oldMAP)||oldMAP.length!==200||oldMAP.some(row=>!Array.isArray(row)||row.length!==180))throw new Error('Built host MAP must be 200 rows x 180 columns');
  if(!Array.isArray(immutableGeometry)||!Array.isArray(solidRects))throw new Error('Explicit immutable geometry and solid-rect arrays required');
  const policeShapes=immutableGeometry.filter(s=>s.immutable===true&&(s.owner==='poi:police'||s.namespace==='police-envelope'));
  for(const rect of solidRects)policeShapes.push({shape:'aabb',bounds:rect});
  if(!policeShapes.length)throw new Error('No explicit police geometry');
  const cells=[];
  for(let r=0;r<200;r++)for(let c=0;c<180;c++)if(policeShapes.some(shape=>policeCellOverlapsShape(r,c,shape))){
    const tile=oldMAP[r][c];if(!Number.isInteger(tile)||tile<0||tile>255)throw new Error('Invalid protected host tile');cells.push({r,c,tile});
  }
  if(!cells.some(cell=>cell.r===76&&cell.c===76))throw new Error('Police anchor not captured');
  return cells;
}
// Exact descriptors from the planner's explicit full MAIN union. The radius
// is accepted only for the explicitly supported literal source rule, not 6.
export function policeShapesFromAddendum(police){
  if(police?.surface_protected_rule!=='distance([r,c],[76,76]) < 8.0 OR any rectangle/causeway below'||JSON.stringify(police.gameplay_center_rc)!=='[76,76]')throw new Error('Unsupported source police union');
  const bound=a=>({minR:a.north,maxR:a.south,minC:a.west,maxC:a.east});
  return [{shape:'circle',centerRC:[76,76],radiusGrid:8},
    ...[bound(police.island_bounds_rc),bound(police.intake_bounds_rc),police.west_vehicle_causeway_rect_rc,police.north_causeway_rect_rc,police.police_admin_rect_rc,...police.solid_rects_rc].map(bounds=>({shape:'aabb',bounds:{...bounds}}))]
    .map((shape,i)=>({...shape,id:`source-police-${i}`,owner:'poi:police',namespace:'police-envelope',immutable:true}));
}
