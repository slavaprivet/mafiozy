/** Opt-in source/byte staging only. Never launches Godot or imports assets. */
import {createHash} from 'node:crypto';
import {lstat, readFile, realpath, mkdir, mkdtemp, writeFile} from 'node:fs/promises';
import {resolve, relative, isAbsolute, join} from 'node:path';
import {fileURLToPath} from 'node:url';

const here = resolve(fileURLToPath(new URL('.', import.meta.url)));
const root = resolve(here, '../../..');
const sha = bytes => createHash('sha256').update(bytes).digest('hex');
const inside = (parent, child) => {
  const rel = relative(parent, child);
  return rel === '' || (!rel.startsWith('..') && !isAbsolute(rel));
};
const variant = {
  'editor_controller.gd': '4878b8b9c9d8b5f4594f3c5858ada9d799f80239e6426eab18369797ac808e97',
  'editor_workspace.gd': '681fd1a7f5971634260eca69f96f831072fc6e5e47f0e62eebb4551f2547116a',
};
const support = {
  editor_camera: '89562525890296611ce4593117b0564dff33902fd22dcca8877a80e9ce35e02a',
  editor_panel: 'af393e8eef857e60933705dd64b4fd03131133439b6be12d5dc3d8fa909f44ce',
  editor_persistence: 'fe94be02f75e26b2dbefe723c6e6439854952091f0df8268309c6fdf77613fed',
  map_bundle: 'd74badabe425107ad0954250e792a9d6ba6434bc14dcf949975dabecbec0c37f',
  map_bundle_store: 'ff7ce8f802c99d17647909bb8ebe93865f6f6479eea8f5c91b2e08074256ae56',
  map_document: '09b32b7623dd66aa623fd0fc469fa3feee3d84f6de60ca26d6553f8954b1911e',
  map_patch: '7aa183516114a3a6eca6b9d0439423e312d895d321d00df37375b5b779a20077',
  map_store: '50f3141541a5802e6224f88b3d7ddd5e439e27e9af2f5bbd98a59745d4fec175',
  object_registry: '369c9457a4fc47fe59c2a876194d0dba2037d5d48b4dc84758a4b3c6349e0749',
  selection_outline: '8c202d0853352be1435612777a83643955254ffc3899dc3805318f7457a670e3',
  trusted_json: '40e455e671f00bb130cbcdf8ce119a95ef0ef6dcfa4d8772790568efe48a7ccb',
};
const ground = {
  ground_brush: '61411e3e2c6e1233418c0e7e8a2ed05928778ec753311667c9b026b8753ecbbb',
  ground_panel: '7e7ca4b0ef2a51608b6ec1d1c2e3f960a4d56f366ad8d570c9ad467e55336f48',
};
async function admitted(relativeSource, expected) {
  const absolute = resolve(root, relativeSource);
  if (!inside(root, absolute)) throw Error(`Outside repository: ${relativeSource}`);
  const stat = await lstat(absolute);
  if (!stat.isFile() || stat.isSymbolicLink() || !inside(root, await realpath(absolute))) throw Error(`Not a regular repository file: ${relativeSource}`);
  const bytes = await readFile(absolute);
  if (expected && sha(bytes) !== expected) throw Error(`Source drift: ${relativeSource}`);
  return bytes;
}

const sourceStage = 'outputs/map-editor-unified-persistence-KKEd3m';
const parentReceipt = JSON.parse(await admitted(sourceStage + '/receipt.json'));
if (parentReceipt.schema !== 'mafiozi.unified-persistence-guard-candidate/v1') throw Error('Wrong combined variant receipt');
const files = new Map();
for (const [name, expected] of Object.entries(variant)) {
  if (parentReceipt.derivedSha256[name] !== expected) throw Error(`Combined variant receipt drift: ${name}`);
  files.set('scripts/map_editor/' + name, await admitted(sourceStage + '/' + name, expected));
}
for (const [name, expected] of Object.entries(support)) files.set('scripts/map_editor/' + name + '.gd', await admitted('tools/godot/map_editor_candidate/scripts/map_editor/' + name + '.gd', expected));
for (const [name, expected] of Object.entries(ground)) files.set('scripts/map_editor/' + name + '.gd', await admitted('tools/godot/map_editor_ground_candidate/' + name + '.gd', expected));
const fixture = 'tools/godot/map_editor_unified_persistence_guard_candidate/native_fixture/';
files.set('project.godot', await admitted(fixture + 'project.godot'));
files.set('test_unified_guard.gd', await admitted(fixture + 'test_unified_guard.gd'));
const receipt = {schema: 'mafiozi.unified-persistence-native-fixture/v1', combinedVariant: sourceStage, files: [...files].map(([path, bytes]) => ({path, bytes: bytes.length, sha256: sha(bytes)})), importedAssets: 0, productionWired: false, godotExecuted: false};
if (process.argv[2] === '--check' || process.argv.length === 2) {
  console.log(JSON.stringify({status: 'PASS_SOURCE_ONLY', files: files.size, receiptSha256: sha(Buffer.from(JSON.stringify(receipt))), godotExecuted: false}));
} else if (process.argv[2] === '--stage') {
  const destination = await mkdtemp(join(root, 'outputs', 'map-editor-unified-guard-native-'));
  for (const [name, bytes] of files) {
    const target = resolve(destination, name);
    if (!inside(destination, target)) throw Error(`Unsafe target: ${name}`);
    await mkdir(resolve(target, '..'), {recursive: true});
    await writeFile(target, bytes, {flag: 'wx'});
    if (sha(await readFile(target)) !== sha(bytes)) throw Error(`Staged mismatch: ${name}`);
  }
  await writeFile(join(destination, 'source_receipt.json'), JSON.stringify(receipt, null, 2) + '\n', {flag: 'wx'});
  console.log(JSON.stringify({status: 'STAGED_SOURCE_ONLY', destination, files: files.size, godotExecuted: false}));
} else throw Error('Use --check or --stage');
