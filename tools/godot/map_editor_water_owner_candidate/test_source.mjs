import assert from 'node:assert/strict';
import {buildWaterCandidate} from './build_candidate.mjs';

const {workspace,guard,baseSha256}=buildWaterCandidate();
const text=workspace.toString('utf8');
assert.equal(baseSha256,'7aa4ec78e89da3edd4ccfc8f09881e63197b5e1450d3a6507b4d1d0cfae36eb0');
assert.equal((text.match(/WaterOwnerGuard\.snapshot\(_main\)/g)||[]).length,5);
assert.ok(text.includes('if not WaterOwnerGuard.snapshot(_main).get("ok", false): return "water_owner_lifetime"'));
assert.ok(text.includes('and WaterOwnerGuard.snapshot(_main).get("ok", false) and _capture() == _snapshot'));
assert.ok(text.includes('return WaterOwnerGuard.snapshot(_main).get("ok", false) and _without_focus_state(_capture()) == _critical_snapshot'));
assert.ok(text.includes('"water_owner":water_receipt'));
assert.ok(text.includes('"water_owner":WaterOwnerGuard.snapshot(_main)'));
assert.ok(!text.includes('_main._water_host._factory._time'));
assert.ok(!text.includes('_main._water_host.get_instance_id()'));
assert.ok(guard.toString('utf8').includes('factory._disposed'));
console.log(JSON.stringify({checks:9,failures:[],scope:'source composition; no native K/LIVE'}));
