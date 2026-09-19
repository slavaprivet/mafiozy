import { subtractBoxFromGeometry } from './building_entry.mjs';
import { createInteriorMeshPool } from './interior_mesh_pool.mjs';
import { isBreakableGlass } from './glass_breakage.mjs';
import {getDetentionRoadStopPose} from './detention_road_stop_pose.mjs';

export const DETENTION_NATIVE_MODEL = Object.freeze({
  assetId: 'police_station', url: '/assets/maps/city_rebuild_v1/building_models/police_station/police_station_canon_v2.glb',
  bounds: Object.freeze({ min: Object.freeze([-19, 0, -17]), max: Object.freeze([19, 13.240000382065773, 17]) }),
  metresPerCell: 4.1, floorY: .33, ceilingY: 3.45,
});
// District branch keeps the complete building and portico. The original
// 38×34 m car park belongs to the main-complex presentation, not each branch.
export const DETENTION_BRANCH_BOUNDS = Object.freeze([-15, -9.5, 15, 10.8]);
const M = 4.1, EPS = 1e-6;
const overlap = (a, b) => a.minR < b.maxR - EPS && a.maxR > b.minR + EPS && a.minC < b.maxC - EPS && a.maxC > b.minC + EPS;
const rect = points => ({ minC: Math.min(...points.map(p => p[0])), maxC: Math.max(...points.map(p => p[0])), minR: Math.min(...points.map(p => p[1])), maxR: Math.max(...points.map(p => p[1])) });
const inside = (x, z, p) => { let ok = false; for (let i = 0, j = p.length - 1; i < p.length; j = i++) if ((p[i][1] > z) !== (p[j][1] > z) && x < (p[j][0] - p[i][0]) * (z - p[i][1]) / (p[j][1] - p[i][1]) + p[i][0]) ok = !ok; return ok; };
const round = n => +n.toFixed(8);
export function detentionLocalToWorld(site, x, z) {
  const yaw = site.transform.yawDegrees * Math.PI / 180, c = Math.cos(yaw), s = Math.sin(yaw), p = site.transform.positionM, scale = site.transform.uniformScale || 1;
  return { x: p[0] + (x * c + z * s) * scale, z: p[2] + (-x * s + z * c) * scale };
}
const sourcePoint = (site, x, z) => { const p = detentionLocalToWorld(site, x, z); return { r: round(p.z / M), c: round(p.x / M) }; };
export function detentionDestination(site, nativeReady = false) {
  const pose=getDetentionRoadStopPose(site),stop={r:round(pose.z/M),c:round(pose.x/M)},yaw=pose.yaw;
  return { id: site.detentionId, name: site.name, instanceId: site.id, stop: { ...stop, angle: round(Math.PI / 2 - yaw) }, handoff: sourcePoint(site, -5.1, site.stopLocalZ - 2.2 / (site.transform.uniformScale || 1)), intake: sourcePoint(site, -5.1, 3.5), release: sourcePoint(site, -7.2, 9.8), bookingRadius: 2.5, nativeReady: !!nativeReady };
}

/** Pure construction-time search; never changes topology, placement or registry.
 * Complete station and portico stay on land; only the oversized original
 * parking apron is cropped. The stopped 6.4×2.3 m car stays on the existing
 * road, with a reserved 2.4 m footpath from pavement to intake. */
export function planDetentionNativeSites({ topology, placement, decor = { instances: [] }, ledger = { rows: [] }, rail = null, count = 3, modelScale = .8 } = {}) {
  if (!topology?.grid || !topology.roadMask || !topology.walkableMask || !placement?.instances || !Number.isInteger(count) || count < 1 || count > 3) throw new TypeError('Detention planning requires map masks, final building placement and 1–3 sites');
  const blockers = [
    ...(placement.protectedRects || []),
    ...placement.instances.flatMap(b => [b.clearance || b.footprint, b.entryCorridor].filter(Boolean).map(r => ({ ...r, id: b.id }))),
    ...(decor.instances || []).filter(d => d.clearancePolygonCR?.length).map(d => ({ ...rect(d.clearancePolygonCR), id: d.id })),
    ...(ledger.rows || []).filter(r => r.plannedRC && /^(bank|business|poi):/.test(r.id)).map(r => ({ minR: r.plannedRC[0] - 2.5, maxR: r.plannedRC[0] + 2.5, minC: r.plannedRC[1] - 2.5, maxC: r.plannedRC[1] + 2.5, id: r.id })),
  ];
  const safeCell = (r, c, road) => !topology.protectedMask?.[r]?.[c] && !topology.policeMask?.[r]?.[c] && (road ? topology.grid[r]?.[c] === 0 && !!topology.roadMask[r]?.[c] : [8, 9].includes(topology.grid[r]?.[c]) && !topology.roadMask[r]?.[c]);
  const clearRect = (r, road) => {
    for (let z = Math.floor(r.minR + EPS); z < Math.ceil(r.maxR - EPS); z++) for (let x = Math.floor(r.minC + EPS); x < Math.ceil(r.maxC - EPS); x++) if (!safeCell(z, x, road)) return false;
    return !blockers.some(b => overlap(r, b));
  };
  const worldRect = (site, bounds) => rect([[bounds[0], bounds[1]], [bounds[2], bounds[1]], [bounds[2], bounds[3]], [bounds[0], bounds[3]]].map(([x, z]) => { const p = detentionLocalToWorld(site, x, z); return [p.x / M, p.z / M]; }));
  const candidates = [], searchCounts = { landPlots: 0, railClear: 0, roadStops: 0, approaches: 0, lanes: 0 };
  if (!Number.isFinite(modelScale) || modelScale < .8 || modelScale > 1) throw new RangeError('Authored police copies support scale .8–1');
  for (let r = 6; r < topology.grid.length - 6; r += .5) for (let c = 6; c < topology.grid[Math.floor(r)].length - 6; c += .5) {
    if (!safeCell(Math.floor(r), Math.floor(c), false)) continue;
    const district = topology.districts?.find(d => inside(c, r, d.polygon_grid));
    if (!district || district.id === 'central_district') continue;
    for (const yawDegrees of [0, 90, 180, 270]) {
      const site = { compactSite: true, transform: { positionM: [c * M, 0, r * M], yawDegrees, uniformScale: modelScale, modelLocalOffsetM: [0, 0, 0] } };
      const footprint = worldRect(site, DETENTION_BRANCH_BOUNDS);
      if (!clearRect(footprint, false)) continue;
      searchCounts.landPlots++;
      if (rail && rail.blocksPlacement(c * M, r * M, Math.hypot(15, 10.8) * modelScale)) continue;
      searchCounts.railClear++;
      for (let stopLocalZ = 13; stopLocalZ <= 31; stopLocalZ += .5) {
        const car = worldRect(site, [-5.1 - 3.2 / modelScale, stopLocalZ - 1.15 / modelScale, -5.1 + 3.2 / modelScale, stopLocalZ + 1.15 / modelScale]);
        if (!clearRect(car, true)) continue;
        searchCounts.roadStops++;
        const approach = worldRect(site, [-5.1 - 1.2 / modelScale, 10.7, -5.1 + 1.2 / modelScale, stopLocalZ - 1.3 / modelScale]);
        if (!clearRect(approach, false)) continue;
        searchCounts.approaches++;
        // Need road longitudinal clearance for approach/departure, beyond the
        // stopped car: this rejects tiny driveways and cross-road orientations.
        const lane = worldRect(site, [-5.1 - 8 / modelScale, stopLocalZ - 1.05 / modelScale, -5.1 + 8 / modelScale, stopLocalZ + 1.05 / modelScale]);
        if (!clearRect(lane, true)) continue;
        searchCounts.lanes++;
        candidates.push({ ...site, footprint, entryCorridor: approach, stopFootprint: car, stopLane: lane, stopLocalZ, districtId: district.id, districtName: district.display_name, score: stopLocalZ - 13 + Math.hypot(c - district.center_grid[0], r - district.center_grid[1]) * .08 });
        break;
      }
    }
  }
  const selected = [], used = new Set();
  candidates.sort((a, b) => a.score - b.score || a.transform.positionM[2] - b.transform.positionM[2] || a.transform.positionM[0] - b.transform.positionM[0]);
  // Spread sites around the city, not three neighbouring copies at one junction.
  while (selected.length < count) {
    const choices = candidates.filter(a => !used.has(a.districtId) && selected.every(b => Math.hypot(a.transform.positionM[0] - b.transform.positionM[0], a.transform.positionM[2] - b.transform.positionM[2]) >= 140 && !overlap(a.footprint, b.footprint)));
    if (!choices.length) break;
    choices.sort((a, b) => {
      const cost = x => x.score - (selected.length ? Math.min(...selected.map(y => Math.hypot(x.transform.positionM[0] - y.transform.positionM[0], x.transform.positionM[2] - y.transform.positionM[2]))) * .015 : 0);
      return cost(a) - cost(b);
    });
    const chosen = choices[0], id = 'REBUILD-DETENTION-' + chosen.districtId;
    const site={ ...chosen, id, detentionId: 'detention:' + chosen.districtId, name: 'Районный изолятор — ' + chosen.districtName.split(' · ')[0], assetId: DETENTION_NATIVE_MODEL.assetId, role: 'district_detention', gameplayId: null, binding: { url: DETENTION_NATIVE_MODEL.url }, bounds: { min: [-15, 0, -9.5], max: [15, 13.240000382065773, 10.8] }, renderContract: 'Parent positionM/yaw/uniformScale. Call createDetentionNativeEntry for compact apron, hollowing, physical doors, floors and collision bodies.' };
    // Vehicle physics uses placement bodies, while pedestrians use the entry
    // bodies. Keep cars out of the actual station mass and portico posts;
    // the authored walk and shortened parking apron remain driveable surfaces.
    site.collision={method:'authored_police_mass_for_vehicles_only',worldBodies:[
      ['Main_Hall',[-14.5,-9,10.5,7],.1,7],['Service_Wing',[6,-8.5,14,2.5],.1,4.9],
      ['Portico_Column',[-6.93,7.92,-6.37,8.48],0,4.7],['Portico_Column001',[-2.03,7.92,-1.47,8.48],0,4.7],['Public_Door_Frame',[-6.12,7.325,-2.28,8.19],0,3.59],
    ].map(([node,b,y0,y1])=>{const polygonCR=[[b[0],b[1]],[b[2],b[1]],[b[2],b[3]],[b[0],b[3]]].map(([x,z])=>{const p=detentionLocalToWorld(site,x,z);return[p.x/M,p.z/M];});return{node,polygonCR,rectangleRC:rect(polygonCR),minYM:y0*modelScale,maxYM:y1*modelScale,buildingEntryId:id,carOnly:true};})};
    selected.push(site);
    used.add(chosen.districtId);
  }
  return { version: 1, instances: selected, candidateCount: candidates.length, searchCounts, destinations: selected.map(s => detentionDestination(s, false)), livePlacementWritten: false, liveRegistryWritten: false };
}

const live = new WeakMap();
const shellResources = new WeakMap();
export function detentionShellResourceStats(T) {
  const records = shellResources.get(T); return { entries: records?.size || 0, references: records ? [...records.values()].reduce((sum,r)=>sum+r.refs,0) : 0, geometries: records ? [...records.values()].reduce((sum,r)=>sum+r.groups.length,0) : 0 };
}
function batchStaticShell(T, root, visual, nodes, movedNodes, changes, hide) {
  const inverse = visual.matrixWorld.clone().invert();
  const eligible = nodes.filter(n=>n.visible&&!movedNodes.has(n)&&!n.isSkinnedMesh&&!Array.isArray(n.material)&&!n.material.transparent&&!isBreakableGlass(n,n.material));
  const original = n => changes.find(c=>c.node===n)?.geometry || n.geometry;
  // Cloned GLTF scenes share immutable input geometries/materials. All three
  // branches also share their compiled shell buffers; per-instance transforms
  // remain at the parent, including yaw and the approved .8 branch scale.
  const key=eligible.map(n=>[original(n).uuid,n.material.uuid,n.name,...inverse.clone().multiply(n.matrixWorld).elements.map(v=>Math.round(v*1e6))].join(':')).join('|');
  let records=shellResources.get(T);if(!records){records=new Map();shellResources.set(T,records);}let record=records.get(key),cacheHit=!!record;
  if(!record){
    const buckets=new Map();
    for(const node of eligible){
      const schema=Object.entries(node.geometry.attributes).map(([name,a])=>name+':'+a.itemSize+':'+a.normalized+':'+a.array.constructor.name).sort().join(','),id=node.material.uuid+'|'+schema;
      if(!buckets.has(id))buckets.set(id,{material:node.material,geometries:[],names:[]});
      const b=buckets.get(id),geometry=node.geometry.clone();geometry.applyMatrix4(inverse.clone().multiply(node.matrixWorld));b.geometries.push(geometry);b.names.push(node.name);
    }
    const groups=[];
    for(const bucket of buckets.values()){
      const geometry=new T.BufferGeometry(),vertexCount=bucket.geometries.reduce((n,g)=>n+g.attributes.position.count,0),indexCount=bucket.geometries.reduce((n,g)=>n+(g.index?.count??g.attributes.position.count),0),indices=new (vertexCount>65535?Uint32Array:Uint16Array)(indexCount);
      for(const[name,attribute]of Object.entries(bucket.geometries[0].attributes)){
        const values=new attribute.array.constructor(vertexCount*attribute.itemSize);let cursor=0;for(const g of bucket.geometries){values.set(g.attributes[name].array,cursor);cursor+=g.attributes[name].array.length;}geometry.setAttribute(name,new T.BufferAttribute(values,attribute.itemSize,attribute.normalized));
      }
      let vertexOffset=0,indexOffset=0;for(const g of bucket.geometries){const n=g.index?.count??g.attributes.position.count;for(let i=0;i<n;i++)indices[indexOffset++]=vertexOffset+(g.index?g.index.array[i]:i);vertexOffset+=g.attributes.position.count;g.dispose();}
      geometry.setIndex(new T.BufferAttribute(indices,1));geometry.computeBoundingBox();geometry.computeBoundingSphere();geometry.name='Detention_Shared_Shell';groups.push({geometry,material:bucket.material,names:bucket.names});
    }
    record={refs:0,groups};records.set(key,record);
  }
  record.refs++;const meshes=[];
  for(const[groupIndex,group]of record.groups.entries()){
    const mesh=new T.Mesh(group.geometry,group.material);mesh.name='Detention_Shell_Batch_'+groupIndex;mesh.userData.sourceNodeNames=group.names;mesh.castShadow=mesh.receiveShadow=true;root.add(mesh);meshes.push(mesh);
    // Rendering uses one merged buffer. Picking/camera rays retain the small
    // authored mesh bounds, avoiding a whole-building triangle scan per ray.
    const proxies=eligible.filter(n=>group.names.includes(n.name)),hits=[];
    mesh.raycast=(raycaster,intersections)=>{for(const proxy of proxies){hits.length=0;proxy.raycast(raycaster,hits);for(const hit of hits){hit.detentionSourceNodeName=proxy.name;hit.object=mesh;intersections.push(hit);}}};
  }
  for(const n of eligible)hide(n);
  const beforeTriangles=eligible.reduce((n,s)=>n+(s.geometry.index?.count??s.geometry.attributes.position.count)/3,0),afterTriangles=record.groups.reduce((n,s)=>n+s.geometry.index.count/3,0);
  let disposed=false;
  return {stats:{sourceDraws:eligible.length,batchDraws:record.groups.length,beforeTriangles,afterTriangles,excludedBreakableMeshes:nodes.filter(n=>n.visible&&(Array.isArray(n.material)?n.material:[n.material]).some(m=>isBreakableGlass(n,m))).length,geometryEquivalent:beforeTriangles===afterTriangles,cacheHit},dispose(){if(disposed)return;disposed=true;for(const mesh of meshes)mesh.removeFromParent();if(--record.refs===0){for(const group of record.groups)group.geometry.dispose();records.delete(key);if(records.size===0)shellResources.delete(T);}}};
}
/** The caller owns the GLTF clone and applies the instance parent transform.
 * This adapter owns only its cuts/generated contents, never the source GLB or
 * source materials. It deliberately leaves gameplay arrest/release authority
 * to the host; a physical gate API is not a new detention economy. */
export function createDetentionNativeEntry({ THREE: T, visual, instance, metresPerCell = M }) {
  if (!T || !visual || instance?.role !== 'district_detention' || instance.assetId !== 'police_station' || metresPerCell !== M) throw new TypeError('Expected a district_detention police clone at 4.1 metres/cell');
  if (live.has(visual)) return live.get(visual);
  if (!visual.getObjectByName('Main_Hall') || !visual.getObjectByName('Public_Door_L')) throw new Error('Police GLB does not match the audited native shell');
  const scale = instance.transform.uniformScale || 1;
  if (scale < .8 || scale > 1) throw new RangeError('Detention headroom requires authored scale .8–1');
  visual.updateWorldMatrix(true, true);
  const inverse = visual.matrixWorld.clone().invert(), root = new T.Group(); root.name = 'Detention_Native_' + instance.id; visual.add(root);
  const changes = [], moved = [], localBodies = [], floors = [], owned = [], pools = [], doors = [], originalNodes = [], lightSources = [];
  let disposed = false, collisionCache = null;
  const box = (a, b) => new T.Box3(new T.Vector3(...a), new T.Vector3(...b));
  const compact = box([-15, -1, -9.5], [15, 20, 10.8]), interior = box([-9.5, .33, -6], [1.5, 3.45, 6.8]), opening = box([-5.88, .32, 6.7], [-4.32, 3.31, 8.55]);
  const remember = node => { if (!changes.some(c => c.node === node)) changes.push({ node, geometry: node.geometry, visible: node.visible }); };
  const replace = (node, geometry) => { remember(node); if (owned.includes(node.geometry)) { node.geometry.dispose(); owned.splice(owned.indexOf(node.geometry), 1); } node.geometry = geometry; owned.push(geometry); };
  const hide = node => { remember(node); node.visible = false; };
  visual.traverse(node => { if (node.isMesh) originalNodes.push(node); });
  const meshBox = node => { if (!node.geometry.boundingBox) node.geometry.computeBoundingBox(); return node.geometry.boundingBox.clone().applyMatrix4(inverse.clone().multiply(node.matrixWorld)); };
  for (const node of originalNodes) {
    const toLocal = inverse.clone().multiply(node.matrixWorld), bounds = meshBox(node);
    if (instance.compactSite) {
      if (!bounds.intersectsBox(compact)) { hide(node); continue; }
      if (!compact.containsBox(bounds)) replace(node, subtractBoxFromGeometry(T, node.geometry, toLocal, compact, true));
    }
    if (node.name === 'Main_Hall') { replace(node, subtractBoxFromGeometry(T, node.geometry, toLocal, interior)); replace(node, subtractBoxFromGeometry(T, node.geometry, toLocal, opening)); }
    if (node.name === 'Public_Recess') replace(node, subtractBoxFromGeometry(T, node.geometry, toLocal, opening));
    if (/CANON_DOOR_034/.test(node.name) && /DEEP_INTERIOR|FURNITURE|WARM_SCONCE/.test(node.name)) hide(node);
  }
  const pool = createInteriorMeshPool(T, root); pools.push(pool);
  const add = (name, x, y, z, w, h, d, color, solid = true, metal = false) => {
    pool.add({ position: [x, y, z], size: [w, h, d], color, metalness: metal ? .65 : 0 });
    if (solid) localBodies.push({ rect: [x - w / 2, z - d / 2, x + w / 2, z + d / 2], minY: y - h / 2, maxY: y + h / 2, kind: name });
  };
  const floor = (name, x, z, w, d, top = .33) => { add(name, x, top - .06, z, w, .12, d, '#a6a18e', false); floors.push({ rect: [x - w / 2, z - d / 2, x + w / 2, z + d / 2], y: top }); };
  floor('intake-floor', -4, .4, 11, 12.8);
  floor('entrance-floor', -5.1, 7.63, 1.56, 1.68);
  const endZ = instance.stopLocalZ - 1.3 / scale;
  // Short ramp takes the raised authored pavement down to road level; its
  // surface is both rendered and sampled, with no invisible step at handoff.
  const rampStart = Math.max(10.4, endZ - 2 / scale), rampLength = endZ - rampStart;
  floor('approach-paving', -5.1, (10.3 + rampStart) / 2, 2.4 / scale, rampStart - 10.3);
  // Replace the flat end of the approach by a wedge. Its floor sampler below
  // takes precedence over the broad pavement rectangle.
  const rampGeometry = new T.BufferGeometry(), rx0 = -5.1 - 1.2 / scale, rx1 = -5.1 + 1.2 / scale;
  rampGeometry.setAttribute('position', new T.Float32BufferAttribute([rx0,.33,rampStart, rx1,.33,rampStart, rx1,0,endZ, rx0,0,endZ], 3)); rampGeometry.setIndex([0,2,1,0,3,2]); rampGeometry.computeVertexNormals();
  const rampMaterial = new T.MeshStandardMaterial({ color: '#a6a18e', roughness: .85, side: T.DoubleSide });
  const ramp = new T.Mesh(rampGeometry, rampMaterial); ramp.name = 'Detention_Approach_Ramp'; root.add(ramp);
  owned.push(rampGeometry);
  // Shell mass remains solid outside the new room, while generated inner
  // faces close the cut volume and make every collision boundary visible.
  for (const [name, r] of [['shell-left',[-14.5,-9,-9.5,7]],['shell-right',[1.5,-9,10.5,7]],['shell-back',[-9.5,-9,1.5,-6]],['shell-front-left',[-9.5,6.8,-5.88,7]],['shell-front-right',[-4.32,6.8,1.5,7]]]) localBodies.push({ rect: r, minY: .1, maxY: 7, kind: name });
  add('inner-wall-left', -9.56, 1.9, .4, .12, 3.14, 12.8, '#d1ccad');
  add('inner-wall-right', 1.56, 1.9, .4, .12, 3.14, 12.8, '#d1ccad');
  add('inner-wall-back', -4, 1.9, -6.06, 11, 3.14, .12, '#d1ccad');
  add('inner-front-left', -7.69, 1.9, 6.84, 3.62, 3.14, .08, '#d1ccad');
  add('inner-front-right', -1.41, 1.9, 6.84, 5.82, 3.14, .08, '#d1ccad');
  add('intake-ceiling', -4, 3.51, .4, 11, .12, 12.8, '#d3cdbb', false);
  for (const [x,z] of [[-4.9,1],[-4.9,4.7],[-1.1,-2.6]]) add('ceiling-luminaire', x, 3.36, z, 1.3, .12, .34, '#f0e7c6', false);
  // Sources are collected by the existing createStableEntryLights pool from
  // entry.object. They consume its fixed 32 slots, not new global GPU lights.
  for (const [name,x,z] of [['Intake',-4.9,2.8],['Cell',-1.1,-2.6]]) {
    const light = new T.PointLight('#fff0d1',8,9,2);light.name='Entry_Warm_Light_Detention_'+name;light.position.set(x,3.13,z);light.castShadow=false;root.add(light);lightSources.push(light);
  }
  // Reception counter, work surface, records, waiting bench and wall notice.
  add('booking-counter', -7.8, .81, 3.6, 2.4, .96, 1.1, '#6d776f');
  add('booking-counter-top', -7.8, 1.33, 3.6, 2.56, .08, 1.25, '#51483b');
  add('booking-ledger', -7.5, 1.41, 3.6, .62, .08, .45, '#ece3c5', false);
  add('booking-phone', -8.45, 1.47, 3.6, .32, .18, .36, '#323b3c', false);
  add('records-cabinet', -8.7, 1.34, -4.8, 1.1, 2.02, 1.1, '#72796e');
  for (let y = .67; y < 2.25; y += .47) { add('records-drawer', -8.7, y, -4.22, .94, .39, .05, '#91958b', false); add('records-handle', -8.7, y, -4.17, .26, .04, .06, '#ced0c4', false, true); }
  add('waiting-seat', -7.55, .82, -.8, 2.9, .18, .72, '#6c7569');
  add('waiting-back', -7.55, 1.18, -1.12, 2.9, .66, .14, '#6c7569');
  for (const x of [-8.65,-6.45]) add('waiting-leg', x, .56, -.8, .11, .46, .57, '#424e48', true, true);
  add('noticeboard-frame', -9.42, 2.01, 3.5, .1, 1.3, 2.1, '#544d40', false);
  add('noticeboard', -9.35, 2.01, 3.5, .03, 1.11, 1.9, '#827b62', false);
  for (const z of [2.9,3.5,4.1]) add('notice-paper', -9.32, 2.01, z, .025, .67, .43, '#e8dfbd', false);
  // Genuine holding cell: three solid sides, a visible barred front and a
  // separately opening gate. Clear floor remains between gate and bed/toilet.
  add('cell-partition', -3.46, 1.9, -3, .12, 3.14, 6, '#b8bea9');
  const gateCentreX = -1.1, gateWidth = 1.9, gateZ = -.08, gateLeft = gateCentreX - gateWidth / 2, gateRight = gateCentreX + gateWidth / 2;
  for (const [a,b] of [[-3.4,gateLeft],[gateRight,1.5]]) {
    for (let x = a + .09; x < b; x += .24) add('cell-fixed-bar', x, 1.86, gateZ, .045, 2.9, .07, '#485956', true, true);
    for (const y of [.45,3.22]) add('cell-fixed-rail', (a+b)/2, y, gateZ, b-a, .09, .09, '#485956', true, true);
    localBodies.push({ rect: [a,gateZ-.055,b,gateZ+.055], minY:.33,maxY:3.27,kind:'cell-bars' });
  }
  add('cell-gate-header',gateCentreX,3.22,gateZ,gateWidth,.12,.14,'#485956',true,true);
  add('cell-bed-frame', .55, .74, -4.22, 1.2, .16, 2.55, '#455554', true, true);
  add('cell-mattress', .55, .91, -4.22, 1.14, .18, 2.46, '#a5b2ad');
  add('cell-pillow', .55, 1.05, -5.07, .93, .12, .45, '#d5d5c8', false);
  add('cell-blanket', .55, 1.03, -3.76, 1.13, .06, 1.34, '#708280', false);
  for (const x of [.03,1.07]) for (const z of [-5.34,-3.1]) add('cell-bed-leg',x,.53,z,.08,.4,.08,'#455554',true,true);
  add('cell-toilet-base', -2.55, .59, -5.13, .62, .52, .78, '#acb7b5');
  add('cell-toilet-seat', -2.55, .88, -5.05, .7, .1, .86, '#d1d6ca');
  add('cell-toilet-cistern', -2.55, 1.13, -5.5, .7, .8, .23, '#acb7b5');
  add('cell-privacy-screen', -1.93, 1.03, -5.16, .1, 1.4, 1.45, '#7f928a');
  add('cell-washbasin', -2.7, 1.05, -3.55, .64, .2, .57, '#c4cdc2');
  add('cell-washbasin-pipe', -2.7, .68, -3.55, .1, .62, .1, '#657a73', true, true);
  add('cell-faucet', -2.7, 1.27, -3.74, .06, .22, .1, '#c3c9c5', false, true);
  const furnitureStats = pool.flush();

  function door(name, x, z, width, height, authored = false) {
    const pivot = new T.Group(); pivot.name = 'Detention_Door_' + name; pivot.position.set(x, .33, z); root.add(pivot);
    const state = { name, pivot, x, z, width, height, fraction: 0, target: 0, authored };
    if (authored) {
      root.updateWorldMatrix(true, true);
      for (const node of originalNodes.filter(n => /^(Public_Door_L|Public_Door_Glass_L|Public_Handle_L)$/.test(n.name) || /CANON_DOOR_034/.test(n.name))) {
        if (!node.visible) continue;
        moved.push({node,parent:node.parent,position:node.position.clone(),quaternion:node.quaternion.clone(),scale:node.scale.clone()}); pivot.attach(node);
      }
    } else {
      const gatePool = createInteriorMeshPool(T, pivot); pools.push(gatePool);
      for (let x = .09; x < width; x += .22) gatePool.add({ position: [x,height/2,0],size:[.045,height,.07],color:'#485956',metalness:.65 });
      for (const y of [.06,height-.06]) gatePool.add({position:[width/2,y,0],size:[width,.1,.1],color:'#485956',metalness:.65});
      gatePool.add({position:[width-.15,height*.48,.06],size:[.16,.3,.1],color:'#5a635b',metalness:.65});
      gatePool.flush();
    }
    doors.push(state); return state;
  }
  const entrance = door('Вход в изолятор', -5.89, 8.04, 1.58, 3, true);
  const gate = door('Решётка камеры', gateLeft, gateZ, gateWidth, 2.9);
  root.updateWorldMatrix(true, true);
  // The remaining authored meshes produce real low-height-aware bodies. The
  // cut main mass and recessed entrance need their decomposed shell bodies.
  const movedNodes = new Set(moved.map(m => m.node));
  for (const node of originalNodes) {
    if (!node.visible || movedNodes.has(node) || ['Main_Hall','Public_Recess'].includes(node.name)) continue;
    const b = meshBox(node); if (b.isEmpty() || b.max.y <= .335 || b.min.y >= 3.45) continue;
    localBodies.push({ rect:[b.min.x,b.min.z,b.max.x,b.max.z],minY:b.min.y,maxY:b.max.y,kind:node.name });
  }
  // Residual recess is a wall, not an invisible doorway blocker.
  for (const r of [[-6.05,7.325,-5.88,7.675],[-4.32,7.325,-2.35,7.675]]) localBodies.push({rect:r,minY:0,maxY:3.5,kind:'Public_Recess'});
  const shellBatch = batchStaticShell(T,root,visual,originalNodes,movedNodes,changes,hide);
  root.updateWorldMatrix(true,true);
  const local = p => new T.Vector3(p.x, p.y || 0, p.z).applyMatrix4(inverse);
  const world = (x,y,z) => new T.Vector3(x,y,z).applyMatrix4(visual.matrixWorld);
  const within = (p,r) => p.x>=r[0]-EPS&&p.x<=r[2]+EPS&&p.z>=r[1]-EPS&&p.z<=r[3]+EPS;
  const bodyWorld = b => {
    const ps=[[b.rect[0],b.rect[1]],[b.rect[2],b.rect[1]],[b.rect[2],b.rect[3]],[b.rect[0],b.rect[3]]].map(([x,z])=>world(x,b.minY,z));
    return {polygonCR:ps.map(p=>[p.x/M,p.z/M]),minYM:ps[0].y,maxYM:world(0,b.maxY,0).y,buildingEntryId:instance.id,detention:true,detentionPart:b.kind};
  };
  const staticBodies = localBodies.map(bodyWorld);
  const getCollisionBodies = () => {
    if (collisionCache) return collisionCache;
    const bodies = staticBodies.slice();
    for(const d of doors) {
      const points=[[0,-.1],[d.width,-.1],[d.width,.1],[0,.1]].map(([x,z])=>d.pivot.localToWorld(new T.Vector3(x,0,z)));
      bodies.push({polygonCR:points.map(p=>[p.x/M,p.z/M]),minYM:points[0].y,maxYM:points[0].y+d.height*scale,buildingEntryId:instance.id,detention:true,detentionPart:d.name,movingDoor:true});
    }
    return collisionCache=bodies;
  };
  const proximity = point => {
    const p=local(point);let nearest=null;
    for(const d of doors){const distance=Math.hypot(p.x-d.x-d.width/2,p.z-d.z)*scale;if(distance<=2.2&&p.y>.03&&p.y<3.3&&(!nearest||distance<nearest.distance))nearest={name:d.name,distance,opening:d.target===1,fraction:d.fraction,door:d,instanceId:instance.id,action:d.target?'Закрыть дверь':'Открыть дверь',anchor:world(d.x+d.width/2,2,d.z)};}
    return nearest;
  };
  const occupied=(d,point)=>{if(!point)return false;const p=local(point),radius=.36/scale;if(p.y<.03||p.y>3.3)return false;const x=p.x-d.x,z=p.z-d.z;return x>=-radius&&z<=radius&&Math.hypot(x,z)<d.width+radius;};
  const sampleBounds=box([-15,-.5,-9.5],[15,14,Math.max(10.8,endZ)]).applyMatrix4(visual.matrixWorld);
  const outside=(x,z)=>x<sampleBounds.min.x-EPS||x>sampleBounds.max.x+EPS||z<sampleBounds.min.z-EPS||z>sampleBounds.max.z+EPS;
  const report={assetId:instance.assetId,instanceId:instance.id,status:'physical-detention-native',sameScene:true,gameplayActive:false,openFraction:0,floorY:world(0,.33,0).y,openingWidth:1.56*scale,room:{minX:-9.5,maxX:1.5,minZ:-6,maxZ:6.8,width:11*scale,usableDepth:12.8*scale,depth:12.8*scale,area:11*12.8*scale*scale,height:3.12*scale,source:'audited_police_GLB_cut_and_native_cell'},contentRootId:root.name};
  const api = { id:instance.id,assetId:instance.assetId,kind:'detention',root,visual,instance,object:root,contentRoot:root,report,sampleBounds,profile:{assetId:'police_station',doorX:-5.1,doorZ:8.04,floorY:.33,room:report.room},doors,lightSources,furnitureStats,staticBatchStats:shellBatch.stats,localBodies,
    get needsUpdate(){return !disposed&&doors.some(d=>d.fraction!==d.target);},
    rooms:[{id:instance.id+':intake',name:'Приёмная изолятора',rect:[-9.5,0,1.5,6.8]},{id:instance.id+':cell',name:'Камера',rect:[-3.4,-6,1.5,-.08]}],
    approachPoint:()=>world(-5.1,.33,9.7), proximity,
    interact(point){const near=proximity(point);if(!near)return{accepted:false,reason:'out_of_range'};if(near.door.target&&occupied(near.door,point))return{accepted:false,reason:'door-sweep-occupied'};near.door.target=1-near.door.target;return{accepted:true,opening:!!near.door.target,name:near.name};},
    setEntranceOpen(open){entrance.target=open?1:0;},setGateOpen(open){gate.target=open?1:0;},
    update(dt,point){if(disposed)return false;if(!Number.isFinite(dt)||dt<0)throw new RangeError('Invalid detention entry timestep');let changed=false;const step=Math.min(.15,dt)*1.8;for(const d of doors){if(!d.target&&d.fraction>0&&occupied(d,point))d.target=1;const next=d.fraction+Math.sign(d.target-d.fraction)*Math.min(Math.abs(d.target-d.fraction),step);if(next!==d.fraction){d.fraction=next;d.pivot.rotation.y=next*Math.PI/2;d.pivot.updateWorldMatrix(true,true);changed=true;}}if(changed){collisionCache=null;report.openFraction=entrance.fraction;}return changed;},
    getCollisionBodies,
    containsInterior(point){if(!Number.isFinite(point.y)||outside(point.x,point.z))return false;const p=local(point);if(p.y<.33-EPS)return false;if(within(p,[-9.5,-6,1.5,6.8]))return p.y<=3.45+EPS;return within(p,[-5.88,6.8,-4.32,7.9])&&p.y<=3.31+EPS;},
    roomPoint:()=>world(-5.1,.33,3.5),roomCenterPoint:()=>world(-5.1,.33,2.5),
    floorHeight(x,z){if(outside(x,z))return null;const p=local({x,z});if(within(p,[rx0,rampStart,rx1,endZ]))return world(0,.33*(endZ-p.z)/rampLength,0).y;for(const f of floors)if(within(p,f.rect))return world(0,f.y,0).y;if(within(p,[-9,8.5,-1,instance.compactSite?10.8:16.5])||within(p,[-6.3,7.7,-2.1,10.7]))return world(0,.33,0).y;return null;},
    ceilingHeight(point){if(outside(point.x,point.z))return null;const p=local(point);if(within(p,[-9.5,-6,1.5,6.8]))return world(0,3.45,0).y;if(within(p,[-5.88,6.8,-4.32,8.55]))return world(0,3.31,0).y;return null;},
    routePoints(){return{handoffToIntake:[[-5.1,instance.stopLocalZ-2.2/scale],[-5.1,9.8],[-5.1,8.1],[-5.1,6.4],[-5.1,3.5]],intakeToCell:[[-5.1,3.5],[-5.1,1.4],[-1.1,1.4],[-1.1,-2.2]],intakeToRelease:[[-5.1,3.5],[-5.1,6.4],[-5.1,8.1],[-5.1,9.8],[-7.2,9.8]]};},
    dispose(){if(disposed)return;disposed=true;shellBatch.dispose();for(const p of pools)p.dispose();for(const m of moved){m.parent.add(m.node);m.node.position.copy(m.position);m.node.quaternion.copy(m.quaternion);m.node.scale.copy(m.scale);}for(const c of changes){c.node.geometry=c.geometry;c.node.visible=c.visible;}for(const g of owned)g.dispose();for(const light of lightSources)light.dispose?.();rampMaterial.dispose();root.removeFromParent();live.delete(visual);},
  };
  live.set(visual,api);return api;
}
