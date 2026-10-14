import assert from 'node:assert/strict';
import {buildSource} from './build_candidate.mjs';

const result = buildSource();
for (const key of ['resident', 'policy', 'population']) {
  const source = result[key];
  for (const name of ['prepare_editor_resume_atomic', 'commit_editor_resume_atomic', 'abort_editor_resume_atomic', 'finalize_editor_resume_atomic']) {
    assert.equal(source.split(`func ${name}(`).length, 2, `${key}: ${name} exactly once`);
  }
  assert.match(source, /func finalize_editor_resume_atomic\(ticket: Dictionary\) -> bool:\n\tif _editor_resume_phase != "committed"/);
}
const population = result.population;
const cancel = population.split('func cancel_editor_pause(receipt: Dictionary) -> bool:')[1].split('func prepare_editor_resume_atomic')[0];
assert.ok(cancel);
assert.match(cancel, /navigation\.cancel_editor_pause\(receipt\.navigation\)/);
assert.match(cancel, /policy\.end_editor_pause\(receipt\.policy\)/);
assert.match(cancel, /residents\.end_editor_pause\(receipt\.residents\)/);
assert.ok(cancel.indexOf('navigation.cancel_editor_pause(receipt.navigation)') < cancel.indexOf('policy.end_editor_pause(receipt.policy)'));
assert.ok(cancel.indexOf('policy.end_editor_pause(receipt.policy)') < cancel.indexOf('residents.end_editor_pause(receipt.residents)'));
assert.match(population, /return false # Legacy sequential release is forbidden/);
assert.match(population, /func flush_editor_resume_atomic\(ticket: Dictionary\) -> bool:/);
assert.ok(population.indexOf('residents.finalize_editor_resume_atomic(ticket.residents)') < population.indexOf('navigation.finalize_editor_resume_atomic(ticket.navigation)'));
assert.ok(population.indexOf('navigation.finalize_editor_resume_atomic(ticket.navigation)') < population.indexOf('func flush_editor_resume_atomic'));
assert.match(population, /if owner == null or owner.get_tree\(\).paused: return false\n\tif not _editor_pause_navigation.flush_editor_resume_atomic/);
console.log('resident atomic source checks PASS (no native or LIVE claim)');
