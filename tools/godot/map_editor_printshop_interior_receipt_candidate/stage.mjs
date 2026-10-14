/** Source-only opt-in staging from immutable Coordinator22 project checkpoint. */
import {createHash} from 'node:crypto';
import {readdir, lstat, readFile, realpath, mkdir, mkdtemp, writeFile} from 'node:fs/promises';
import {resolve, relative, isAbsolute, join} from 'node:path';
import {fileURLToPath} from 'node:url';

const here = resolve(fileURLToPath(new URL('.', import.meta.url)));
const root = resolve(here, '../../..');
const sourceProject = resolve(root, 'outputs/coordinator22_residents_checkpoint/godot/mafiozi_walk');
const sha = bytes => createHash('sha256').update(bytes).digest('hex');
const within = (parent, child) => {
  const rel = relative(parent, child);
  return rel === '' || (!rel.startsWith('..') && !isAbsolute(rel));
};
const pins = {
  'scripts/main.gd': 'faac92194afdfac5efb4197a17a81d53738a91a46a6e41f96316f9c282112f53',
  'scripts/preview_printshop_interior.gd': 'f6f082584ada23dcd55b384c629505730c80a59080768910a17c653d7eb1b5df',
  'scripts/preview_interior_finish.gd': '666bb28093d3bc9fbf17b702dda9c460d1364c64dee63c236b02fc9d80519ced',
  'data/block.json': '1523f52e2e859c42aec208d4acfffb9714ffb99974823098bb063e31ee61c22e',
  'data/printshop_interior.json': '958a2c2d8cbdc2b2e2e11a57e33bf9bf5a20ec334be8a8997bdad951f9f8086b',
  'assets/buildings/print_shop.ad7b8ef7e7e4.glb': 'ad7b8ef7e7e4143f0e989b7a585c03bb9bd1c13d5efb8689cf67ebcb92ac4d97',
};
async function admitted(base, rel, expected = '') {
  const path = resolve(base, rel);
  if (!within(base, path)) throw Error('Outside source: ' + rel);
  const stat = await lstat(path);
  if (!stat.isFile() || stat.isSymbolicLink() || !within(base, await realpath(path))) throw Error('Unsafe source: ' + rel);
  const bytes = await readFile(path);
  if (expected && sha(bytes) !== expected) throw Error('Source drift: ' + rel);
  return bytes;
}
for (const [name, expected] of Object.entries(pins)) await admitted(sourceProject, name, expected);
const catalog = await admitted(root, 'godot/mafiozi_walk/data/map_editor/catalog.json', 'ae089d73eb61131bc6a38ccc6a2b9b18639f7bd8b65079f7c15c1e1cda9cde6e');
const owner = await admitted(root, 'tools/godot/map_editor_printshop_interior_receipt_candidate/printshop_interior_owner.gd');
const fixture = await admitted(root, 'tools/godot/map_editor_printshop_interior_receipt_candidate/test_printshop_receipt.gd');
const trusted = await admitted(root, 'tools/godot/map_editor_candidate/scripts/map_editor/trusted_json.gd', '40e455e671f00bb130cbcdf8ce119a95ef0ef6dcfa4d8772790568efe48a7ccb');
const excluded = name => name === '.godot' || name.endsWith('.import') || name.endsWith('.uid');
async function sourceFiles(folder = '') {
  const result = [];
  for (const entry of await readdir(resolve(sourceProject, folder), {withFileTypes: true})) {
    if (excluded(entry.name)) continue;
    const rel = join(folder, entry.name);
    if (entry.isSymbolicLink()) throw Error('Symlink source refused: ' + rel);
    if (entry.isDirectory()) result.push(...await sourceFiles(rel));
    else if (entry.isFile()) result.push(rel);
    else throw Error('Unexpected source entry: ' + rel);
  }
  return result;
}
const projectFiles = await sourceFiles();
if (process.argv[2] === '--check' || process.argv.length === 2) {
  console.log(JSON.stringify({status: 'PASS_SOURCE_ONLY', pinned: Object.keys(pins).length + 1, projectFiles: projectFiles.length, importedCacheCopied: false, godotExecuted: false}));
} else if (process.argv[2] === '--stage') {
  const destination = await mkdtemp(join(root, 'outputs', 'map-editor-printshop-owner-'));
  const files = new Map();
  for (const name of projectFiles) files.set(name, await admitted(sourceProject, name, pins[name] || ''));
  let project = files.get('project.godot').toString('utf8');
  const before = 'config/custom_user_dir_name="MafioziGodotPreview"';
  if (project.split(before).length !== 2) throw Error('Project user directory seam changed');
  project = project.replace(before, 'config/custom_user_dir_name="MafioziPrintshopReceiptFixture"');
  files.set('project.godot', Buffer.from(project));
  files.set('data/map_editor/catalog.json', catalog);
  files.set('scripts/map_editor/printshop_interior_owner.gd', owner);
  files.set('scripts/map_editor/trusted_json.gd', trusted);
  files.set('test_printshop_receipt.gd', fixture);
  for (const [name, bytes] of files) {
    const target = resolve(destination, name);
    if (!within(destination, target)) throw Error('Unsafe stage path: ' + name);
    await mkdir(resolve(target, '..'), {recursive: true});
    await writeFile(target, bytes, {flag: 'wx'});
    if (sha(await readFile(target)) !== sha(bytes)) throw Error('Staged mismatch: ' + name);
  }
  const receipt = {schema: 'mafiozi.printshop-interior-owner-source/v1', pinned: pins, catalogSha256: sha(catalog), files: [...files].map(([path, bytes]) => ({path, bytes: bytes.length, sha256: sha(bytes)})), importedCacheCopied: false, productionWired: false, godotExecuted: false, verifiedRoots: 0};
  await writeFile(join(destination, 'source_receipt.json'), JSON.stringify(receipt, null, 2) + '\n', {flag: 'wx'});
  console.log(JSON.stringify({status: 'STAGED_SOURCE_ONLY', destination, files: files.size, godotExecuted: false, verifiedRoots: 0}));
} else throw Error('Use --check or --stage');
