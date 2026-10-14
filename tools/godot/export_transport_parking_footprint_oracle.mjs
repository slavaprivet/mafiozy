import fs from 'node:fs';
import vm from 'node:vm';
import crypto from 'node:crypto';

const root = new URL('../../', import.meta.url);
const sourceUrl = new URL('assets/maps/city_rebuild_v1/civilian_parking_trip_source.js', root);
const worldUrl = new URL('world.html', root);
const snapshotUrl = new URL('outputs/roads_logical_20260912/integration_candidate_snapshot.json', root);
const outputUrl = new URL('godot/mafiozi_walk/data/transport/parking_footprint_oracle.v1.json', root);
const source = fs.readFileSync(sourceUrl, 'utf8');
const overlapBody = text => {
  const start = text.indexOf('function _nativeParkingBoxesOverlap(');
  const end = text.indexOf('function _nativeParkingAdmissionTick(', start);
  if (start < 0 || end < 0) throw Error('source overlap function missing');
  return text.slice(start, end).trim().replace(/\r/g, '');
};
const body = overlapBody(source);
if (body !== overlapBody(fs.readFileSync(worldUrl, 'utf8'))) throw Error('tracked source and live world parking overlap differ');
const sourceOverlap = vm.runInNewContext(body + '\n_nativeParkingBoxesOverlap');
const sha256 = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
let state = 0x6d5a9b41;
const random = () => ((state = (Math.imul(state, 1664525) + 1013904223) >>> 0) / 4294967296);
const between = (lo, hi) => lo + (hi - lo) * random();
const boxes = [];
for (let index = 0; index < 1024; index++) {
  const a = {r: between(-150, 150), c: between(-150, 150), angle: between(-Math.PI, Math.PI), halfLength: between(.2, 1.2), halfWidth: between(.1, .65)};
  const displacement = index % 4 === 0 ? .12 : index % 4 === 1 ? 1.6 : index % 4 === 2 ? 3 : 300;
  const b = {r: a.r + between(-displacement, displacement), c: a.c + between(-displacement, displacement), angle: between(-Math.PI, Math.PI), halfLength: between(.2, 1.2), halfWidth: between(.1, .65)};
  boxes.push({a, b, overlap: sourceOverlap(a, b)});
}
const snapshot = JSON.parse(fs.readFileSync(snapshotUrl, 'utf8'));
const plan = snapshot.parkingPlan;
if (plan.bays.length !== 59 || plan.metresPerCell !== 4.1) throw Error('unexpected source parking plan');
const slots = plan.bays.map(b => ({id: b.id, lotId: b.lotId, r: b.z / plan.metresPerCell, c: b.x / plan.metresPerCell, angle: Math.PI / 2 - b.yaw, widthM: b.width, lengthM: b.length}));
const fits = [];
for (let index = 0; index < 1024; index++) {
  const slot = slots[index % slots.length];
  const halfLength = slot.lengthM / 8.2 + between(-.08, .08);
  const halfWidth = slot.widthM / 8.2 + between(-.08, .08);
  fits.push({slotId: slot.id, halfLength, halfWidth, fits: !(halfLength * 8.2 > slot.lengthM + .05 || halfWidth * 8.2 > slot.widthM + .05)});
}
const document = {
  schema: 'mafiozi.transport.parking-footprint-oracle.v1',
  authority: {source_path: 'assets/maps/city_rebuild_v1/civilian_parking_trip_source.js', source_sha256: sha256(Buffer.from(source)), snapshot_sha256: sha256(fs.readFileSync(snapshotUrl))},
  slots, boxes, fits,
  stats: {slots: slots.length, boxes: boxes.length, box_overlaps: boxes.filter(x => x.overlap).length, fits: fits.length, fitting: fits.filter(x => x.fits).length},
};
fs.writeFileSync(outputUrl, JSON.stringify(document) + '\n');
console.log(JSON.stringify({output: outputUrl.pathname, bytes: fs.statSync(outputUrl).size, sha256: sha256(fs.readFileSync(outputUrl)), stats: document.stats}));
