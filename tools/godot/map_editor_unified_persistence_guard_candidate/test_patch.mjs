import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import {join} from 'node:path';

const stage = process.argv[2];
if (!stage) throw Error('Usage: node test_patch.mjs <staged-directory>');
const sha = text => createHash('sha256').update(text).digest('hex');
const receipt = JSON.parse(await readFile(join(stage, 'receipt.json'), 'utf8'));
const controller = await readFile(join(stage, 'editor_controller.gd'), 'utf8');
const workspace = await readFile(join(stage, 'editor_workspace.gd'), 'utf8');
assert.equal(sha(controller), receipt.derivedSha256['editor_controller.gd']);
assert.equal(sha(workspace), receipt.derivedSha256['editor_workspace.gd']);
assert.match(controller, /not supplied_rows\.has\(baseline_row\.id\) or not _json_equal\(baseline_row, supplied_rows\[baseline_row\.id\]\)/);
assert.match(controller, /if _unified_persistence_only and action in \["save", "load", "import", "export"\]:/);
assert.match(controller, /func install_document\(source: Dictionary\) -> Dictionary:\n\t# Legacy object-only loader[^\n]*\n\tif _unified_persistence_only: return \{"ok": false/);
assert.match(controller, /func install_versioned_patch\(patch: Dictionary\) -> Dictionary:[\s\S]*?return install_document\(expanded\.document\)/);
assert.match(controller, /"add":/);
assert.match(controller, /"undo", "redo":/);
const setup = workspace.slice(workspace.indexOf('func setup('), workspace.indexOf('func _status('));
const handoff = setup.indexOf('var exclusive: Dictionary = object_editor.require_unified_persistence()');
assert(handoff > 0);
for (const needed of [
  'object_editor.panel.has_signal("action_requested")',
  'terrain_panel.has_signal("action_requested")',
  'ground_brush.has_signal("status_changed")',
  'ground_brush.has_signal("committed")',
  'terrain_panel.has_method("input_guard")',
]) assert(setup.indexOf(needed) >= 0 && setup.indexOf(needed) < handoff, `${needed} must preflight before handoff`);
assert(setup.indexOf('editor = object_editor') > handoff);
assert.equal(setup.slice(setup.indexOf('editor = object_editor')).match(/return \{"ok": false/g), null, 'no explicit failure after handoff');
assert.match(workspace, /"save", "load", "import", "export":[\s\S]*?_persistence\.call\(action, payload\)/);
console.log(JSON.stringify({suite: 'unified-persistence-guard-static', checks: 16, stage, godotExecuted: false, productionInstalled: false}));
