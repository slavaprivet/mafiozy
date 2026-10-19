/** Source-only opt-in native fixture staging. Never launches Godot. */
import {createHash} from 'node:crypto';
import {lstat, readFile, realpath, mkdir, mkdtemp, writeFile} from 'node:fs/promises';
import {resolve, relative, isAbsolute, join} from 'node:path';
import {fileURLToPath} from 'node:url';

const here = resolve(fileURLToPath(new URL('.', import.meta.url)));
const root = resolve(here, '../../..');
const sha = value => createHash('sha256').update(value).digest('hex');
const inside = (parent, child) => {
  const rel = relative(parent, child);
  return rel === '' || (!rel.startsWith('..') && !isAbsolute(rel));
};
async function admitted(relativeSource, expected = '') {
  const absolute = resolve(root, relativeSource);
  if (!inside(root, absolute)) throw Error('Outside repository: ' + relativeSource);
  const stat = await lstat(absolute);
  if (!stat.isFile() || stat.isSymbolicLink() || !inside(root, await realpath(absolute))) throw Error('Unsafe source: ' + relativeSource);
  const bytes = await readFile(absolute);
  if (expected && sha(bytes) !== expected) throw Error('Source drift: ' + relativeSource);
  return bytes;
}
const parent = 'outputs/map-editor-bundle-recovery-4Ib6yD';
const derived = 'f19da51b2f9953a394bb747c61cf6874c6f25a39c701183c00cd7301791f5254';
const parentReceipt = JSON.parse(await admitted(parent + '/receipt.json'));
if (parentReceipt.schema !== 'mafiozi.map-bundle-recovery-source/v1' || parentReceipt.derivedSha256 !== derived) throw Error('Wrong recovered store receipt');
const files = new Map();
files.set('scripts/map_editor/map_bundle_store.gd', await admitted(parent + '/map_bundle_store.gd', derived));
const support = {
  map_bundle: 'd74badabe425107ad0954250e792a9d6ba6434bc14dcf949975dabecbec0c37f',
  map_store: '50f3141541a5802e6224f88b3d7ddd5e439e27e9af2f5bbd98a59745d4fec175',
  map_patch: '7aa183516114a3a6eca6b9d0439423e312d895d321d00df37375b5b779a20077',
  map_document: '09b32b7623dd66aa623fd0fc469fa3feee3d84f6de60ca26d6553f8954b1911e',
};
for (const [name, expected] of Object.entries(support)) files.set('scripts/map_editor/' + name + '.gd', await admitted('tools/godot/map_editor_candidate/scripts/map_editor/' + name + '.gd', expected));
const fixture = 'tools/godot/map_editor_bundle_store_recovery_candidate/native_fixture/';
files.set('project.godot', await admitted(fixture + 'project.godot'));
files.set('test_recovery.gd', await admitted(fixture + 'test_recovery.gd'));
const receipt = {schema: 'mafiozi.map-bundle-recovery-native-fixture/v1', derivedStoreSha256: derived, files: [...files].map(([path, bytes]) => ({path, bytes: bytes.length, sha256: sha(bytes)})), productionWired: false, godotExecuted: false, crashDurabilityProved: false};
if (process.argv[2] === '--check' || process.argv.length === 2) console.log(JSON.stringify({status: 'PASS_SOURCE_ONLY', files: files.size, receiptSha256: sha(Buffer.from(JSON.stringify(receipt))), godotExecuted: false}));
else if (process.argv[2] === '--stage') {
  const destination = await mkdtemp(join(root, 'outputs', 'map-editor-bundle-recovery-native-'));
  for (const [name, bytes] of files) {
    const target = resolve(destination, name);
    if (!inside(destination, target)) throw Error('Unsafe target: ' + name);
    await mkdir(resolve(target, '..'), {recursive: true});
    await writeFile(target, bytes, {flag: 'wx'});
    if (sha(await readFile(target)) !== sha(bytes)) throw Error('Staged byte mismatch: ' + name);
  }
  await writeFile(join(destination, 'source_receipt.json'), JSON.stringify(receipt, null, 2) + '\n', {flag: 'wx'});
  console.log(JSON.stringify({status: 'STAGED_SOURCE_ONLY', destination, files: files.size, godotExecuted: false}));
} else throw Error('Use --check or --stage');
