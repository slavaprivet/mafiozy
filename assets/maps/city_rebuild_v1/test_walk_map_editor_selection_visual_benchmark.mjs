import assert from 'node:assert/strict';
import {selectionVisualBenchmark as result} from './test_walk_map_editor_selection_visual.mjs';

// The structural counts are the stable performance oracle; the broad timing
// ceiling only catches a catastrophic synchronous regression on slow CI hosts.
assert.equal(result.traversals,2,'one initial traversal plus one explicit invalidation');assert.equal(result.deepUpdates,2);assert.ok(result.hotElapsed<5000);
console.log(`walk map editor selection visual benchmark: PASS (${result.descendants} descendants, ${result.updates} moves in ${result.hotElapsed.toFixed(1)} ms, no hot-path traversal)`);
