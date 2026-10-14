import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { buildVariant as addExactProtectedGuard } from '../map_editor_protected_exact_variant/variant.mjs';

// Source-only derivative. The frozen assembly and production game are untouched.
const root = fs.realpathSync(process.cwd());
const source = path.join(root, 'tools/godot/map_editor_candidate/scripts/map_editor');
const output = path.join(root, 'outputs');
const names = ['editor_controller.gd', 'editor_workspace.gd'];
const expected = [
  'd1812cb127b6526a14e12cbf047ef2a0365aba036d031060844dfc369b5e40c4',
  '4981d9596ec1fd9d09497f070432fc78188c24843857e72a9e5b10a45bd61a8d',
];
const hash = b => crypto.createHash('sha256').update(b).digest('hex');
const raw = names.map((name, i) => {
  const file = path.join(source, name);
  if (fs.lstatSync(file).isSymbolicLink()) throw Error(`Symlink source refused: ${name}`);
  const bytes = fs.readFileSync(file);
  if (hash(bytes) !== expected[i]) throw Error(`Frozen source drift: ${name}`);
  return bytes.toString('utf8');
});
function replaceOnce(body, before, after, name) {
  if (body.split(before).length !== 2) throw Error(`Ambiguous seam: ${name}`);
  return body.replace(before, after);
}
// Compose the independently reviewed exact protected-row guard on the same
// frozen controller bytes before adding the unified file-action gate.
let controller = replaceOnce(addExactProtectedGuard(Buffer.from(raw[0])),
  'var atomic_install_active := false\n',
  'var atomic_install_active := false\nvar _unified_persistence_only := false\n', 'controller state');
controller = replaceOnce(controller,
  'func handle_action(action: String, payload: Dictionary = {}) -> Dictionary:\n\tif atomic_install_active:',
  'func require_unified_persistence() -> Dictionary:\n\t# One-way switch: direct callers must never write only the object half.\n\tif _unified_persistence_only: return {"ok": true}\n\tif atomic_install_active: return {"ok": false, "error": "Сначала завершите общую загрузку карты"}\n\t_unified_persistence_only = true\n\treturn {"ok": true}\n\nfunc handle_action(action: String, payload: Dictionary = {}) -> Dictionary:\n\tif _unified_persistence_only and action in ["save", "load", "import", "export"]:\n\t\treturn {"ok": false, "error": "Используйте единое сохранение объектов и земли"}\n\tif atomic_install_active:', 'direct file actions');
controller = replaceOnce(controller,
  'func install_document(source: Dictionary) -> Dictionary:\n\tif atomic_install_active:',
  'func install_document(source: Dictionary) -> Dictionary:\n\t# Legacy object-only loader is not a route for a combined-map session.\n\tif _unified_persistence_only: return {"ok": false, "error": "Используйте единую загрузку объектов и земли"}\n\tif atomic_install_active:', 'direct object-only install');
let workspace = replaceOnce(raw[1],
  'if not object_editor.has_method("handle_input") or not ground_brush.has_method("handle_input")',
  'if not object_editor.has_method("handle_input") or not object_editor.has_method("require_unified_persistence") or not ground_brush.has_method("handle_input")', 'workspace setup gate');
workspace = replaceOnce(workspace,
  '\tif terrain_preview != null and (not terrain_preview.has_method("show_cursor") or not terrain_preview.has_method("clear_preview") or not terrain_preview.has_method("hide_cursor")): return {"ok": false, "error": "Несовместимая подсветка кисти"}\n',
  '\tif terrain_preview != null and (not terrain_preview.has_method("show_cursor") or not terrain_preview.has_method("clear_preview") or not terrain_preview.has_method("hide_cursor")): return {"ok": false, "error": "Несовместимая подсветка кисти"}\n\t# Complete setup preflight before the irreversible object-only file-route lock.\n\tif not is_instance_valid(object_editor.outline) or not is_instance_valid(object_editor.registry): return {"ok": false, "error": "Несовместимые части редактора"}\n\tif not object_editor.panel.has_signal("action_requested") or not object_editor.panel.has_method("set_active") or not object_editor.panel.has_method("set_status"): return {"ok": false, "error": "Несовместимые части редактора"}\n\tif not terrain_panel.has_signal("action_requested") or not terrain_panel.has_method("set_active") or not terrain_panel.has_method("set_status") or not terrain_panel.has_method("input_guard"): return {"ok": false, "error": "Несовместимые части редактора"}\n\tif not ground_brush.has_signal("status_changed") or not ground_brush.has_signal("committed") or not ground_brush.has_method("set_active") or not ground_brush.has_method("cancel_preview") or not ground_brush.has_method("focus_lost"): return {"ok": false, "error": "Несовместимые части редактора"}\n', 'complete setup preflight');
workspace = replaceOnce(workspace,
  '\teditor = object_editor\n\tbrush = ground_brush\n',
  '\tvar exclusive: Dictionary = object_editor.require_unified_persistence()\n\tif not exclusive.get("ok", false): return exclusive\n\teditor = object_editor\n\tbrush = ground_brush\n', 'workspace file-route handoff');

// Static boundary proof; a native fixture is still required before adoption.
for (const a of ['"save"', '"load"', '"import"', '"export"']) {
  if (!controller.includes(`action in ["save", "load", "import", "export"]`) || !workspace.includes(a)) throw Error(`Missing file guard ${a}`);
}
if (!controller.includes('"add":') || !controller.includes('"undo", "redo":')) throw Error('Object actions were lost');
if (!controller.includes('not _json_equal(baseline_row, supplied_rows[baseline_row.id])')) throw Error('Exact protected-row guard was lost');
if (!controller.includes('if _unified_persistence_only: return {"ok": false, "error": "Используйте единую загрузку объектов и земли"}')) throw Error('Legacy object-only install guard was lost');
if (!workspace.includes('result = value if value is Dictionary') || !workspace.includes('_persistence.call(action, payload)')) throw Error('Unified route was lost');
const files = { 'editor_controller.gd': controller, 'editor_workspace.gd': workspace };
const receipt = { schema: 'mafiozi.unified-persistence-guard-candidate/v1', frozenSourceSha256: Object.fromEntries(names.map((n, i) => [n, expected[i]])), derivedSha256: Object.fromEntries(names.map(n => [n, hash(Buffer.from(files[n]))])), scope: 'source-only; native and production not verified' };
if (process.argv[2] === '--stage') {
  const dir = fs.mkdtempSync(path.join(output, 'map-editor-unified-persistence-'));
  for (const [name, body] of Object.entries(files)) {
    const target = path.join(dir, name);
    fs.writeFileSync(target, body, { flag: 'wx' });
    if (hash(fs.readFileSync(target)) !== receipt.derivedSha256[name]) throw Error(`Staged byte mismatch: ${name}`);
  }
  fs.writeFileSync(path.join(dir, 'receipt.json'), JSON.stringify(receipt, null, 2), { flag: 'wx' });
  console.log(JSON.stringify({ stage: dir, receipt }));
} else if (process.argv.length === 2 || process.argv[2] === '--check') {
  console.log(JSON.stringify({ status: 'PASS_SOURCE_ONLY', receipt }));
} else throw Error('Use --check or --stage');
