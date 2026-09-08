// Conservative broadphase in placement cells. The caller retains the exact
// height and polygon narrowphase. Rebuild when body arrays/door poses change.
export function createWalkCollisionIndex(collections, cellSize = 4) {
  const cells = new Map();
  for (const collection of collections) for (const body of collection) {
    const polygon = body.polygonCR;
    if (!polygon?.length) continue;
    let minC = Infinity, maxC = -Infinity, minR = Infinity, maxR = -Infinity;
    for (const [c, r] of polygon) {
      minC = Math.min(minC, c); maxC = Math.max(maxC, c);
      minR = Math.min(minR, r); maxR = Math.max(maxR, r);
    }
    for (let r = Math.floor(minR / cellSize); r <= Math.floor(maxR / cellSize); r++) {
      for (let c = Math.floor(minC / cellSize); c <= Math.floor(maxC / cellSize); c++) {
        const key = `${c},${r}`;
        if (!cells.has(key)) cells.set(key, []);
        cells.get(key).push(body);
      }
    }
  }
  const empty = Object.freeze([]);
  return (c, r) => cells.get(`${Math.floor(c / cellSize)},${Math.floor(r / cellSize)}`) || empty;
}
