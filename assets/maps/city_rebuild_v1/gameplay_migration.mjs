// Pure staging adapter. No global state, MAP writes, network, storage or renderer hooks.
// Input records are plain serializable host definitions, not live class instances.
const clone = value => structuredClone(value);
const point = value => Array.isArray(value) && value.length === 2 && value.every(Number.isFinite);
const same = (a, b) => point(a) && point(b) && a[0] === b[0] && a[1] === b[1];
const primary = id => /^(bank|business|poi):/.test(id);
const sourceId = id => id.slice(id.indexOf(':') + 1);
const has = (object, key) => Object.prototype.hasOwnProperty.call(object, key);
const worldChildren = new Set(['entry', 'door', 'exit', 'approach', 'spawn', 'respawn', 'target',
  'anchor', 'worldAnchor', 'serviceAnchor', 'vehicleAnchor', 'pedestrianAnchor',
  'preferredVehicleStop', 'handoff', 'inside', 'entrances', 'doors', 'serviceAnchors',
  'vehicleStops', 'worldAnchors', 'path', 'route']);
const coordinatePairs = [['r', 'c'], ['entryR', 'entryC'], ['doorR', 'doorC'],
  ['exitR', 'exitC'], ['spawnR', 'spawnC'], ['targetR', 'targetC'], ['buildingR', 'buildingC']];

/** Translate declared WORLD anchor fields only. Interior-local coordinates and
 * arbitrary r/c-bearing metadata are deliberately opaque. Host-specific nested
 * world fields require explicit extraWorldKeys (never include "interior"). */
export function translateWorldAnchors(record, delta, extraWorldKeys = []) {
  if (!point(delta)) throw new TypeError('delta must be finite [dr,dc]');
  if (extraWorldKeys.some(key => ['interior', 'interiors', 'interiorDefinition'].includes(key))) {
    throw new TypeError('Interior-local coordinates cannot be registered as world anchors');
  }
  const keys = new Set([...worldChildren, ...extraWorldKeys]);
  function walk(input) {
    if (point(input)) return input.map((n,i)=>n+delta[i]);
    if (Array.isArray(input)) return input.map(walk);
    if (!input || typeof input !== 'object') return clone(input);
    const out = clone(input);
    for (const [rKey, cKey] of coordinatePairs) {
      if (!has(input, rKey) && !has(input, cKey)) continue;
      if (!Number.isFinite(input[rKey]) || !Number.isFinite(input[cKey])) {
        throw new TypeError(`Incomplete/non-finite anchor ${rKey}/${cKey}`);
      }
      out[rKey] = input[rKey] + delta[0]; out[cKey] = input[cKey] + delta[1];
    }
    for (const key of keys) if (has(input, key)) out[key] = walk(input[key]);
    return out;
  }
  return walk(record);
}

function insideBounds(rc, shape) {
  const b = shape.bounds;
  if (!b || !point(rc)) return false;
  const rMax = b.maxRExclusive ?? b.maxR, cMax = b.maxCExclusive ?? b.maxC;
  return rc[0] >= b.minR && rc[1] >= b.minC &&
    (b.maxRExclusive !== undefined ? rc[0] < rMax : rc[0] <= rMax) &&
    (b.maxCExclusive !== undefined ? rc[1] < cMax : rc[1] <= cMax);
}

/** Build a detached migration stage. ok means identity/translation checks passed,
 * NOT that footprints, roads, exits, rendering or live gameplay were validated.
 * Production application is intentionally unsupported until an ownership
 * snapshot/crosswalk and independent topology/placement/server gates exist.
 *
 * registries: {banks: BANKS, businesses: BUSINESS_POIS, pois: POI} is mandatory.
 * Each registry must exactly cover its ledger namespace. Unknown/missing IDs or
 * stale source coordinates reject the whole stage, never silently drop records.
 */
export function prepareGameplayMigration(ledger, options = {}) {
  const errors = [], warnings = [];
  const reject = (code, id = null, detail = null) => errors.push({code, id, detail});
  if (ledger?.schema !== 'mafiozi.city-rebuild.loss-prevention-ledger/v1') reject('LEDGER_SCHEMA');
  if (JSON.stringify(ledger?.coordinateOrder) !== '["r","c"]') reject('COORDINATE_ORDER');
  if (options.mode !== 'isolated-preview') reject('MAIN_MIGRATION_NOT_ENABLED', null,
    ledger?.coverage?.allLivePersistentInstancesComplete === true ? 'production adapter not audited' : 'dynamic ownership coverage unknown');
  if (options.persistence !== 'disabled') reject('PERSISTENCE_MUST_BE_DISABLED');
  if (options.serverSession !== 'isolated-preview') reject('ISOLATED_SERVER_REQUIRED');
  if (!Array.isArray(ledger?.rows)) reject('LEDGER_ROWS');
  if (errors.length) return {ok:false, errors, warnings, stage:null};

  const byId = new Map(), aliasIndex = Object.create(null), remaps = [];
  const size = options.mapSize || {rows:200, cols:180};
  if (!Number.isInteger(size.rows) || !Number.isInteger(size.cols) || size.rows < 1 || size.cols < 1) reject('MAP_SIZE');
  for (const row of ledger.rows) {
    if (typeof row.id !== 'string' || !row.id || byId.has(row.id)) { reject('DUPLICATE_OR_INVALID_ID', row.id); continue; }
    byId.set(row.id, row);
  }
  for (const row of ledger.rows) {
    for (const alias of row.aliases || []) {
      if (typeof alias !== 'string' || byId.has(alias) || has(aliasIndex, alias)) reject('ALIAS_COLLISION', alias);
      else aliasIndex[alias] = row.id;
    }
    if (!primary(row.id)) continue;
    if (!point(row.oldRC)) reject('OLD_ANCHOR_INVALID', row.id);
    if (!point(row.plannedRC)) { reject('PRIMARY_DESTINATION_MISSING', row.id); continue; }
    if (row.plannedRC[0] < 0 || row.plannedRC[0] >= size.rows || row.plannedRC[1] < 0 || row.plannedRC[1] >= size.cols) reject('DESTINATION_OUT_OF_BOUNDS', row.id);
    if (row.id === 'poi:police' && (!same(row.oldRC, [76,76]) || !same(row.plannedRC,[76,76]))) reject('POLICE_IMMUTABLE', row.id);
    if (row.id !== 'poi:police') for (const shape of ledger.immutableGeometry || []) {
      if (shape.immutable && insideBounds(row.plannedRC, shape)) reject('PROTECTED_ENVELOPE_ANCHOR', row.id, shape.id);
    }
    remaps.push({id:row.id, persistentId:sourceId(row.id), oldRC:clone(row.oldRC),
      plannedRC:clone(row.plannedRC), delta:point(row.oldRC) ? row.plannedRC.map((n,i)=>n-row.oldRC[i]) : [0,0],
      aliases:clone(row.aliases || []), interior:clone(row.interior ?? null), district:row.plannedDistrict ?? null});
  }
  if (!byId.has('poi:police')) reject('POLICE_DEFINITION_MISSING');
  for (const id of ['casino','market','factory','mansion','port']) {
    if (aliasIndex['major:'+id] !== 'poi:'+id) reject('MAJOR_ALIAS_MISSING_OR_CHANGED','major:'+id);
  }
  const remapIndex = Object.fromEntries(remaps.map(row => [row.id,row]));
  const registries = {};
  for (const [name, prefix] of [['banks','bank'],['businesses','business'],['pois','poi']]) {
    const input = options.registries?.[name];
    if (!Array.isArray(input)) { reject('HOST_REGISTRY_MISSING',name); continue; }
    const seen = new Set(); registries[name] = [];
    for (const record of input) {
      const id = `${prefix}:${record.id}`, remap = remapIndex[id];
      if (seen.has(id)) {reject('HOST_DUPLICATE_ID',id);continue;} seen.add(id);
      if (!remap) {reject('HOST_ID_NOT_IN_PLAN',id);continue;}
      if (!same([record.r,record.c],remap.oldRC)) {reject('STALE_HOST_ANCHOR',id);continue;}
      try { registries[name].push(translateWorldAnchors(record,remap.delta,options.extraWorldKeys || [])); }
      catch (error) {reject('NESTED_ANCHOR_INVALID',id,error.message);}
    }
    for (const remap of remaps.filter(r=>r.id.startsWith(prefix+':'))) if (!seen.has(remap.id)) reject('HOST_INSTANCE_MISSING',remap.id);
  }
  const services = [];
  for (const service of ledger.serviceAnchors || []) {
    const owner = aliasIndex[service.owner] || service.owner, remap = remapIndex[owner];
    if (!remap) {reject('SERVICE_OWNER_UNKNOWN',service.id,service.owner);continue;}
    try {services.push(translateWorldAnchors(service,remap.delta,options.extraWorldKeys || []));}
    catch(error) {reject('SERVICE_ANCHOR_INVALID',service.id,error.message);}
  }
  for (let i=0;i<remaps.length;i++) for(let j=i+1;j<remaps.length;j++) {
    if (same(remaps[i].plannedRC,remaps[j].plannedRC)) warnings.push({code:'DISTINCT_IDENTITIES_SHARE_DESTINATION',ids:[remaps[i].id,remaps[j].id],rc:clone(remaps[i].plannedRC)});
  }
  const deferred = ledger.rows.filter(row=>!primary(row.id)).map(row=>({id:row.id,
    oldRC:clone(row.oldRC),plannedRC:clone(row.plannedRC ?? null),
    disposition:'retained_in_ledger_not_instantiated',reason:'needs explicit topology/placement and owning-system adapter'}));
  if (deferred.length) warnings.push({code:'DEFERRED_SYSTEM_INSTANCES',count:deferred.length});
  warnings.push({code:'DYNAMIC_PROPERTIES_SUSPENDED',detail:'Not rendered or rekeyed in isolated preview. Snapshot is preserved byte-for-byte as serializable data, never written back.'});
  warnings.push({code:'FOOTPRINT_ROUTES_LIVE_SERVER_NOT_VALIDATED'});
  if (errors.length) return {ok:false,errors,warnings,stage:null};

  const businessWorldPosXY = Object.fromEntries(registries.businesses.map(x=>[x.id,[x.c,x.r]]));
  const majorObjectsRC = {};
  for (const [alias, canonical] of Object.entries(aliasIndex)) if(alias.startsWith('major:')) {
    const remap=remapIndex[canonical];
    if(!remap){reject('MAJOR_ALIAS_WITHOUT_REMAP',alias);continue;}
    majorObjectsRC[sourceId(alias)]={r:remap.plannedRC[0],c:remap.plannedRC[1],canonicalId:canonical,interior:clone(remap.interior)};
  }
  if(errors.length) return {ok:false,errors,warnings,stage:null};
  return {ok:true,errors,warnings,stage:{schema:'mafiozi.city-rebuild.gameplay-migration/v1',
    mode:'isolated-preview',persistence:'disabled',readyForMain:false,readyForWorldPlacement:false,
    sourceApplyGate:clone(ledger.applyGate),registries,remaps,aliasIndex,services,deferred,
    immutableGeometry:clone(ledger.immutableGeometry || []),
    dynamicProperties:{disposition:'suspended_unchanged',snapshot:clone(options.dynamicProperties ?? null),
      eligibleKeys:clone(ledger.genericPotentialProperties),coverage:clone(ledger.coverage)},
    serverAnchors:{businessWorldPosXY,majorObjectsRC,
      banksRC:Object.fromEntries(registries.banks.map(x=>[x.id,{r:x.r,c:x.c,size:x.size}])),
      servicesXY:services.map(x=>({id:x.id,namespace:x.namespace,owner:x.owner,x:x.c,y:x.r,worldAnchors:clone(x)}))},
    requiredHostGates:['native_topology_accepted','full_footprints_clear','doors_and_corridors_passable',
      'vehicle_and_pedestrian_routes_valid','server_anchor_manifest_acknowledged','isolated_session_no_persistence']}};
}

/** Stable identity lookup, including major aliases. No coordinate-based dedupe. */
export function resolveMigrationIdentity(stage,id) {
  const canonical = stage.aliasIndex[id] || id;
  return stage.remaps.find(row=>row.id===canonical) || null;
}
