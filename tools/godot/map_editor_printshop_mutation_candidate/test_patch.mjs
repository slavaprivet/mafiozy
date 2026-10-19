import assert from 'node:assert/strict';
import fs from 'node:fs';
import {buildSource} from './patch.mjs';

const result = buildSource();
const text = result.text;
let checks = 0;
function expect(ok, label) { checks++; assert.ok(ok, label); }
const count = pattern => [...text.matchAll(pattern)].length;
expect(result.sourceSha256 === 'f6f082584ada23dcd55b384c629505730c80a59080768910a17c653d7eb1b5df', 'immutable owner pinned');
expect(result.derivedSha256 === '76fc236779b8174c3487d43d924946177941a1d9d1388e5a67cdb038a1008cab', 'derived bytes pinned');
expect(count(/func editor_mutation_revision\(\)/g) === 1, 'revision getter');
expect(count(/func begin_editor_mutation_lease\(/g) === 1, 'admission entry');
expect(text.includes('"ok": false, "error": "printshop-external-writers-unsealed"'), 'external writes force HOLD');
expect(text.includes('"verifiedRoot": false'), 'no root grant');
expect(text.includes('"revisionExhausted": _editor_revision_exhausted'), 'saturation is explicit');
expect(count(/func _mark_editor_mutation\(\)/g) === 1, 'one mutator');
expect(count(/_mark_editor_mutation\(\)/g) === 5, 'attach, request, advance, restore paths only');
expect(text.includes('_editor_mutation_revision >= EDITOR_REVISION_LIMIT'), 'overflow marks diagnostic exhaustion');
expect(text.includes('_editor_mutation_revision += 1'), 'monotonic increment');
expect(text.includes('if ready_for_use or _visual != null:\n\t\treturn false\n\t_mark_editor_mutation()\n\terrors.clear()'), 'attach original guard preserved');
expect(text.includes('return {"accepted": false, "reason": "door-sweep-occupied"}\n\t_mark_editor_mutation()\n\td.target = target'), 'accepted door command recorded, original rejection preserved');
expect(text.includes('\t\t_mark_editor_mutation()\n\t\td.fraction = next'), 'door motion marked before state change');
expect(text.includes('func restore_original() -> void:\n\t_mark_editor_mutation()\n\tfor saved: Dictionary in _restores:'), 'restore always reaches original loop');
expect(!text.includes('if not _mark_editor_mutation()'), 'diagnostic exhaustion cannot gate gameplay or restoration');
expect(!text.includes('printshop-revision-exhausted'), 'no new door refusal');
for (const phrase of [
  'func nearest_action(actor_position: Vector3) -> Dictionary:',
  'func _sweep_clear(door: Dictionary, from: float, to: float, occupants: Array) -> bool:',
  'func _mesh(spec: Dictionary) -> ArrayMesh:',
  'func _material(index: int, colored: bool) -> Material:',
  'func _add_floor_faces(mesh: ArrayMesh, spec: Dictionary) -> void:',
  'func _add_convex(points: PackedVector3Array, parent: Node3D, kind: String) -> void:',
  'func _add_shape(shape: Shape3D, parent: Node3D, kind: String) -> void:'
]) expect(text.includes(phrase), 'original behavior retained: ' + phrase);
const source = fs.readFileSync(new URL('../../../outputs/coordinator22_residents_checkpoint/godot/mafiozi_walk/scripts/preview_printshop_interior.gd', import.meta.url));
const drift = Buffer.from(source);
drift[drift.length - 1] ^= 1;
assert.throws(() => buildSource(drift), /Pinned Printshop owner bytes drift/); checks++;
console.log(JSON.stringify({checks, failures: [], sourceOnly: true, godotExecuted: false, verifiedRoots: 0,
  derivedSha256: result.derivedSha256}));
