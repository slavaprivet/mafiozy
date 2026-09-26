// Publish only hash-verified raw GLBs. .bytes preserves exact GLB data in PCK
// and avoids editor reimport/mesh compression of this runtime-loaded format.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const source = path.join(repo, 'outputs/coordinator21_vehicle_visual');
const destination = path.join(repo, 'godot/mafiozi_walk/assets/vehicle_visual');
const hash = b => createHash('sha256').update(b).digest('hex');
const manifestBytes = fs.readFileSync(path.join(source, 'manifest.json'));
const manifest = JSON.parse(manifestBytes);
assert.equal(manifest.schema, 'mafiozi.vehicle-visual.v1');
assert.equal(manifest.entries.length, 13);
const pending = manifest.entries.map(entry => {
  assert.equal(path.basename(entry.file), entry.file);
  const bytes = fs.readFileSync(path.join(source, entry.file));
  assert.equal(hash(bytes), entry.sha256); assert.equal(bytes.length, entry.bytes);
  return {entry, bytes};
});
fs.mkdirSync(destination, {recursive: true});
for (const {entry, bytes} of pending) {
  entry.file += '.bytes';
  fs.writeFileSync(path.join(destination, entry.file), bytes);
}
manifest.source_manifest_sha256 = hash(manifestBytes);
fs.writeFileSync(path.join(destination, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
console.log(JSON.stringify({models: pending.length, bytes: pending.reduce((sum, row) => sum + row.bytes.length, 0), source_sha256: manifest.source_manifest_sha256}));
