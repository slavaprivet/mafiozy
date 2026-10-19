import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {buildLinkedPacket} from './build_linked_packet.mjs';

const packet=buildLinkedPacket();
const sha=v=>crypto.createHash('sha256').update(JSON.stringify(v)).digest('hex');
assert.equal(sha(packet),'259ede19883bf73da85f3436661f77ab1ca1cba5fc7bc1d3f49c392d4671689c');
assert.equal(packet.lot_ids.length,39);
assert.equal(packet.bay_ids.length,59);
assert.equal(packet.sign_ids.length,57);
assert.ok(packet.bay_ids.includes(packet.parked_bay.parking_id));
assert.equal(packet.parked_bay.native_yaw_rad,0);
assert.equal(packet.parked_bay.source_yaw_rad,Math.PI);
assert.equal(packet.baseline.walkingRoutes.length,packet.revised.walkingRoutes.length);
assert.notEqual(packet.baseline_sha256,packet.revised_sha256);
assert.deepEqual(packet.baseline.lots.map(x=>x.id),packet.revised.lots.map(x=>x.id));
assert.ok(packet.revised.coverage.find(x=>x.buildingId===packet.source_id&&x.status==='served'));
console.log('linked stationary bay source plan PASS (11 static checks; no Godot/LIVE claim)');
