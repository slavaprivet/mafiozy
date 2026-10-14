// Exact-source, tools-only proposal. Never patches the running Godot project.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '../../..');
const sourcePath = path.join(root, 'outputs/coordinator22_residents_checkpoint/godot/mafiozi_walk/scripts/preview_printshop_interior.gd');
const sourceSha256 = 'f6f082584ada23dcd55b384c629505730c80a59080768910a17c653d7eb1b5df';
const sha = value => crypto.createHash('sha256').update(value).digest('hex');

function once(source, before, after) {
  if (source.split(before).length !== 2) throw Error('Printshop patch anchor drift: ' + before.slice(0, 70));
  return source.replace(before, after);
}

export function buildSource(input = fs.readFileSync(sourcePath)) {
  if (sha(input) !== sourceSha256) throw Error('Pinned Printshop owner bytes drift');
  let text = input.toString('utf8');
  text = once(text, 'var _visual: Node3D\n', [
    'var _visual: Node3D',
    '',
    '# Counts owner-API mutation history. Direct Node/Resource writes are NOT sealed.',
    'const EDITOR_REVISION_LIMIT := 9223372036854775806',
    'var _editor_mutation_revision: int = 0',
    'var _editor_revision_exhausted := false',
    '',
    'func editor_mutation_revision() -> int:',
    '\treturn _editor_mutation_revision',
    '',
    'func begin_editor_mutation_lease(_owner: Node) -> Dictionary:',
    '\t# API revision cannot attest direct writes or change-and-restore.',
    '\treturn {"ok": false, "error": "printshop-external-writers-unsealed",',
    '\t\t"revision": _editor_mutation_revision, "revisionExhausted": _editor_revision_exhausted, "verifiedRoot": false}',
    '',
    'func _mark_editor_mutation() -> void:',
    '\tif _editor_revision_exhausted or _editor_mutation_revision >= EDITOR_REVISION_LIMIT:',
    '\t\t_editor_revision_exhausted = true',
    '\t\treturn',
    '\t_editor_mutation_revision += 1',
    ''
  ].join('\n') + '\n');
  text = once(text,
    'func attach_existing(visual: Node3D, building: Dictionary, data: Dictionary) -> bool:\n\tif ready_for_use or _visual != null:\n\t\treturn false\n\terrors.clear()',
    'func attach_existing(visual: Node3D, building: Dictionary, data: Dictionary) -> bool:\n\tif ready_for_use or _visual != null:\n\t\treturn false\n\t_mark_editor_mutation()\n\terrors.clear()');
  text = once(text,
    '\tif not _sweep_clear(d, float(d.fraction), target, occupants):\n\t\treturn {"accepted": false, "reason": "door-sweep-occupied"}\n\td.target = target',
    '\tif not _sweep_clear(d, float(d.fraction), target, occupants):\n\t\treturn {"accepted": false, "reason": "door-sweep-occupied"}\n\t_mark_editor_mutation()\n\td.target = target');
  text = once(text,
    '\t\tif not _sweep_clear(d, float(d.fraction), next, occupants):\n\t\t\tcontinue\n\t\td.fraction = next',
    '\t\tif not _sweep_clear(d, float(d.fraction), next, occupants):\n\t\t\tcontinue\n\t\t_mark_editor_mutation()\n\t\td.fraction = next');
  text = once(text,
    'func restore_original() -> void:\n\tfor saved: Dictionary in _restores:',
    'func restore_original() -> void:\n\t_mark_editor_mutation()\n\tfor saved: Dictionary in _restores:');
  return {text, sourceSha256, derivedSha256: sha(Buffer.from(text, 'utf8'))};
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const result = buildSource();
  console.log(JSON.stringify({sourceSha256: result.sourceSha256, derivedSha256: result.derivedSha256,
    changedProduction: false, godotExecuted: false, verifiedRoots: 0}));
}
