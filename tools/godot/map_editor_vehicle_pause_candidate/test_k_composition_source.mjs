import assert from 'node:assert/strict';
import {buildVehicleWorkspace} from './compose_k_vehicle.mjs';

const source=buildVehicleWorkspace().toString('utf8');
for (const needle of ['_vehicle_lease.acquire()', '_vehicle_lease.verify(_vehicle_receipt)', '_vehicle_lease.release(_vehicle_receipt)', 'vehicle_stability_lease_refused', 'vehicle_release', 'clock.commit_resume(clock_ticket)']) assert.ok(source.includes(needle), needle);
assert.ok(!source.includes('body.linear_velocity.length_squared() > 0.0001'));
const acquire=source.indexOf('_vehicle_lease.acquire()');
const population=source.indexOf('_main.preview_population.begin_editor_pause');
const release=source.lastIndexOf('_vehicle_lease.release(_vehicle_receipt)');
const clock=source.indexOf('clock.commit_resume(clock_ticket)');
const unpause=source.indexOf('_pause_tree.paused = false');
assert.ok(acquire>=0 && acquire<population);
assert.ok(release>=0 && release<clock && clock<unpause);
console.log('vehicle K composition source checks PASS');
