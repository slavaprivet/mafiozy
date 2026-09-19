// Conservative broadphase in placement cells. The caller retains the exact
// height and polygon narrowphase. Rebuild when body arrays/door poses change.
export function createWalkCollisionIndex(collections, cellSize = 4) {
  const rows = new Map();
  for (const collection of collections) for (const body of collection) {
    const polygon = body.polygonCR;
    if (!polygon?.length) continue;
    let minC = Infinity, maxC = -Infinity, minR = Infinity, maxR = -Infinity;
    for (const [c, r] of polygon) {
      minC = Math.min(minC, c); maxC = Math.max(maxC, c);
      minR = Math.min(minR, r); maxR = Math.max(maxR, r);
    }
    for (let r = Math.floor(minR / cellSize); r <= Math.floor(maxR / cellSize); r++) {
      let row = rows.get(r);
      if (!row) rows.set(r, row = new Map());
      for (let c = Math.floor(minC / cellSize); c <= Math.floor(maxC / cellSize); c++) {
        let cell = row.get(c);
        if (!cell) row.set(c, cell = []);
        cell.push(body);
      }
    }
  }
  const empty = Object.freeze([]);
  const query = (c, r) => rows.get(Math.floor(r / cellSize))?.get(Math.floor(c / cellSize)) || empty;
  // Stable row-major bucket order, preserving source order and duplicates in
  // each bucket. Narrowphases may deduplicate body identity without a full scan.
  query.queryBounds = (minC,minR,maxC,maxR) => {
    if (![minC,minR,maxC,maxR].every(Number.isFinite)||minC>maxC||minR>maxR) return empty;
    const result=[];
    for(let r=Math.floor(minR/cellSize);r<=Math.floor(maxR/cellSize);r++){
      const row=rows.get(r);if(!row)continue;
      for(let c=Math.floor(minC/cellSize);c<=Math.floor(maxC/cellSize);c++){
        const bucket=row.get(c);if(bucket)for(const body of bucket)result.push(body);
      }
    }
    return result;
  };
  return query;
}
