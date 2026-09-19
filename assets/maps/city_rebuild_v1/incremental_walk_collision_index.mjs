// Placement-cell broadphase, equivalent to createWalkCollisionIndex's ordered
// candidates. Exact polygon/height checks remain with the movement consumers.
// Dirty groups replace only their own contributions; queries cache local merges.
export function createIncrementalWalkCollisionIndex(cellSize = 4) {
  if (!Number.isFinite(cellSize) || cellSize <= 0) throw new RangeError('Invalid collision cell size');
  const rows = new Map(), groups = new Map(), membership = new Map(), empty = Object.freeze([]);
  let sequence = 0, cellCount = 0, bodyReferences = 0, bucketReferences = 0, allCache = null;
  const counters = { replacements: 0, orderUpdates: 0, removals: 0, bodiesVisited: 0, verticesVisited: 0, bucketReferencesBuilt: 0, queryCalls: 0, queryCacheBuilds: 0, queryCacheReferences: 0, allBodiesBuilds: 0 };
  const compare = (a, b) => a.order - b.order || a.sequence - b.sequence;

  function cellAt(c, r, create = false) {
    let row = rows.get(r);
    if (!row && create) rows.set(r, row = new Map());
    let cell = row?.get(c);
    if (!cell && create) { cell = { c, r, groups: new Map(), cache: null }; row.set(c, cell); cellCount++; }
    return cell;
  }

  function detach(record) {
    for (const { cell, bodies } of record.buckets) {
      cell.groups.delete(record); cell.cache = null; bucketReferences -= bodies.length;
      if (!cell.groups.size) {
        const row = rows.get(cell.r); row.delete(cell.c); if (!row.size) rows.delete(cell.r); cellCount--;
      }
    }
    // The source array may have been spliced in place (cuttable fences). Keep
    // our own previous membership snapshot, not a second pointer to that array.
    for (const body of record.members) {
      const count = membership.get(body); if (count === 1) membership.delete(body); else membership.set(body, count - 1);
    }
    bodyReferences -= record.members.length;
  }

  function replaceGroup(key, bodies, options = {}) {
    const old = groups.get(key), order = options.order ?? old?.order ?? sequence;
    if (!Number.isFinite(order)) throw new RangeError('Invalid collision group order');
    if (!Array.isArray(bodies)) throw new TypeError('Collision group requires a body array');
    if (old && old.source === bodies && old.revision === options.revision && !options.force) {
      if (old.order === order) return false;
      old.order = order; for (const { cell } of old.buckets) cell.cache = null;
      allCache = null; counters.orderUpdates++; return true;
    }

    // Prepare the replacement before removing the old geometry. Invalid input
    // cannot leave a half-replaced group visible to the next movement query.
    const localRows = new Map(); let references = 0;
    for (const body of bodies) {
      counters.bodiesVisited++;
      const polygon = body.polygonCR; if (!polygon?.length) continue;
      let minC = Infinity, minR = Infinity, maxC = -Infinity, maxR = -Infinity;
      for (const [c, r] of polygon) {
        counters.verticesVisited++;
        if (!Number.isFinite(c) || !Number.isFinite(r)) throw new RangeError('Non-finite collision polygon');
        minC = Math.min(minC, c); maxC = Math.max(maxC, c); minR = Math.min(minR, r); maxR = Math.max(maxR, r);
      }
      for (let r = Math.floor(minR / cellSize); r <= Math.floor(maxR / cellSize); r++) {
        let row = localRows.get(r); if (!row) localRows.set(r, row = new Map());
        for (let c = Math.floor(minC / cellSize); c <= Math.floor(maxC / cellSize); c++) {
          let bucket = row.get(c); if (!bucket) row.set(c, bucket = []); bucket.push(body); references++;
        }
      }
    }
    if (old) detach(old);
    const record = old || { sequence: sequence++ };
    record.order = order; record.source = bodies; record.revision = options.revision; record.members = bodies.slice(); record.buckets = [];
    groups.set(key, record);
    for (const [r, row] of localRows) for (const [c, contribution] of row) {
      const cell = cellAt(c, r, true); cell.groups.set(record, contribution); cell.cache = null;
      record.buckets.push({ cell, bodies: contribution });
    }
    for (const body of record.members) membership.set(body, (membership.get(body) || 0) + 1);
    bodyReferences += bodies.length; bucketReferences += references;
    counters.replacements++; counters.bucketReferencesBuilt += references; allCache = null; return true;
  }

  function removeGroup(key) {
    const record = groups.get(key); if (!record) return false;
    detach(record); groups.delete(key); allCache = null; counters.removals++; return true;
  }

  function query(c, r) {
    counters.queryCalls++;
    const cell = cellAt(Math.floor(c / cellSize), Math.floor(r / cellSize)); if (!cell) return empty;
    if (cell.cache) return cell.cache;
    const candidates = [];
    for (const record of [...cell.groups.keys()].sort(compare)) {
      for (const body of cell.groups.get(record)) candidates.push(body);
    }
    counters.queryCacheBuilds++; counters.queryCacheReferences += candidates.length;
    return cell.cache = candidates;
  }

  // Callable compatibility keeps bodiesAt adapters and exact narrowphases intact.
  query.queryBounds = (minC,minR,maxC,maxR) => {
    if (![minC,minR,maxC,maxR].every(Number.isFinite)||minC>maxC||minR>maxR) return empty;
    const result=[];
    // Same row-major bucket/source order as the static index. Querying the
    // normal cells preserves dirty-group cache invalidation and reference counts.
    for(let r=Math.floor(minR/cellSize);r<=Math.floor(maxR/cellSize);r++)for(let c=Math.floor(minC/cellSize);c<=Math.floor(maxC/cellSize);c++){
      for(const body of query(c*cellSize,r*cellSize))result.push(body);
    }
    return result;
  };
  query.replaceGroup = replaceGroup;
  query.removeGroup = removeGroup;
  query.has = body => membership.has(body);
  query.allBodies = () => {
    if (allCache) return allCache;
    const result = []; for (const record of [...groups.values()].sort(compare)) for (const body of record.members) result.push(body);
    counters.allBodiesBuilds++; return allCache = result;
  };
  query.clear = () => { rows.clear(); groups.clear(); membership.clear(); sequence = 0; cellCount = 0; bodyReferences = 0; bucketReferences = 0; allCache = null; };
  query.resetCounters = () => { for (const key of Object.keys(counters)) counters[key] = 0; };
  Object.defineProperty(query, 'stats', { get: () => ({ ...counters, groups: groups.size, cells: cellCount, bodyReferences, uniqueBodies: membership.size, bucketReferences }) });
  return query;
}

// No throttling: publish every active entry pose before movement in the same
// frame. Object keys also cover replacement/reordering at unchanged list length.
export function updateWalkEntryCollisionGroups(index, versions, entries, dt, point) {
  for (let i = 0; i < entries.length; i++) {
    const entry = entries[i], previous = versions.get(entry), order = i + 1;
    if (!previous || entry.needsUpdate) {
      entry.update(dt, point);
      const bodies = entry.getCollisionBodies();
      index.replaceGroup(entry, bodies, { order });
      versions.set(entry, { bodies, order });
    } else if (previous.order !== order) {
      index.replaceGroup(entry, previous.bodies, { order }); previous.order = order;
    }
  }
  // This runs only when entries were added/removed/replaced, not on door frames.
  if (versions.size !== entries.length) for (const entry of versions.keys()) {
    if (!entries.includes(entry)) { index.removeGroup(entry); versions.delete(entry); }
  }
}
