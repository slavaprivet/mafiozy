import fs from 'node:fs';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { performance } from 'node:perf_hooks';
import { createNarrowPassagePaintMask, narrowPassageSignApproaches } from '../../assets/maps/city_rebuild_v1/city_road_dressing_plan.mjs';
import { createCarWorld, carFits } from '../../assets/maps/city_rebuild_v1/car_drive.mjs';

const out = 'outputs/roads_logical_20260912/', input = out + (process.argv[2] || 'integration_candidate_snapshot.json'), bytes = fs.readFileSync(input), source = JSON.parse(bytes), started = performance.now();
const plan = source.roadPlan, passages = plan.trafficPlan.narrowPassages || [], errors = [], checks = [];
const topology = JSON.parse(fs.readFileSync('assets/maps/city_rebuild_v1/topology_for_placement.json'));
const allBodies = [...source.buildings, ...source.authoredDecor].flatMap(i => i.collision?.worldBodies || []).concat(source.decorPlan.colliders, plan.colliders, source.parkingPlan.colliders);
const asphalt = (x, z) => { const r = Math.floor(z / 4.1), c = Math.floor(x / 4.1); return topology.grid[r]?.[c] === 0 && !!topology.roadMask[r]?.[c] && !topology.policeMask?.[r]?.[c] && !topology.protectedMask?.[r]?.[c]; };
const fullWorld = createCarWorld(topology, allBodies, 4.1, { surfaceAt: asphalt }), blockedPaint = createNarrowPassagePaintMask(passages);
const falsePaint = plan.markings.filter(blockedPaint); if (falsePaint.length) errors.push({ reason: 'two_way_paint_in_narrow_passage', ids: falsePaint.map(m => m.id) });
if (!passages.length) errors.push({ reason: 'missing_narrow_passage_metadata' });
for (const passage of passages) {
  const signs = narrowPassageSignApproaches(passage).map(expected => {
    const actual = plan.signs.find(s => s.passageId === passage.id && s.kind === expected.kind);
    const facing = actual ? Math.sin(actual.yaw) * expected.outward.x + Math.cos(actual.yaw) * expected.outward.z : -1;
    const valid = !!actual && facing > .99 && actual.approachId === expected.approachId && actual.roadId === passage.roadId && passage.signIds?.includes(actual.id);
    if (!valid) errors.push({ reason: 'missing_or_misfacing_narrow_sign', passageId: passage.id, kind: expected.kind, actual, facing });
    return { kind: expected.kind, id: actual?.id, x: actual?.x, z: actual?.z, facing, valid };
  });
  const from = plan.junctionRules.flatMap(j => j.approaches).find(a => a.id === passage.fromApproachId), to = plan.junctionRules.flatMap(j => j.approaches).find(a => a.id === passage.toApproachId);
  if (from?.oneWay !== 'outgoing_only' || to?.oneWay !== 'incoming_only' || from.incomingLaneIds.length || to.outgoingLaneIds.length) errors.push({ reason: 'directional_approach_metadata_mismatch', passageId: passage.id });
  const edge = plan.preparedLaneGraph?.plan.connections.find(e => e.id === passage.id);
  if (!edge || edge.fromLaneId !== passage.fromLaneId || edge.toLaneId !== passage.toLaneId) errors.push({ reason: 'missing_prepared_narrow_edge', passageId: passage.id });
  if (plan.preparedLaneGraph?.plan.connections.some(e => e.fromLaneId === passage.toLaneId && e.toLaneId === passage.fromLaneId)) errors.push({ reason: 'reverse_edge_through_narrow_passage', passageId: passage.id });
  let samples = 0; const bodyFailures = [];
  for (let i = 1; i < passage.points.length; i++) {
    const a = passage.points[i - 1], b = passage.points[i], steps = Math.max(1, Math.ceil(Math.hypot(b.x - a.x, b.z - a.z) / .02)), dyaw = Math.atan2(Math.sin(b.yaw - a.yaw), Math.cos(b.yaw - a.yaw));
    for (let k = 0; k <= steps; k++) { const t = k / steps, x = a.x + (b.x - a.x) * t, z = a.z + (b.z - a.z) * t, yaw = a.yaw + dyaw * t; samples++; if (!carFits(x, z, yaw, fullWorld)) bodyFailures.push({ segment: i, x, z, yaw }); }
  }
  if (bodyFailures.length) errors.push({ reason: 'full_car_conflict_final_asphalt_or_bodies', passageId: passage.id, count: bodyFailures.length, examples: bodyFailures.slice(0, 4) });
  checks.push({ id: passage.id, signs, arrowParts: plan.markings.filter(m => m.narrowPassageId === passage.id).map(m => m.id), bodySamples: samples, bodyFailures: bodyFailures.length, prepared: !!edge });
}
const report = { status: errors.length ? 'FAIL' : 'PASS', input, inputSHA256: createHash('sha256').update(bytes).digest('hex'), inputStable: fs.readFileSync(input).equals(bytes), elapsedMs: performance.now() - started, passages: checks, falsePaint: falsePaint.length, errors,
  limits: ['Final serialized worker plan only; no worker rebuild or GPU scene.', 'Two-centimetre full default-car sampling against native asphalt and final building/decor/road/parking bodies; canonical route decisions are separately covered by graph-owner tests.'] };
fs.writeFileSync(out + 'final_narrow_dressing_audit.json', JSON.stringify(report, null, 2) + '\n'); console.log(JSON.stringify(report, null, 2)); assert.equal(errors.length, 0);
