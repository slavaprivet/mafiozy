import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import {resolve} from 'node:path';

const stage = resolve('outputs/map-editor-bundle-recovery-4Ib6yD');
const receipt = JSON.parse(await readFile(resolve(stage, 'receipt.json'), 'utf8'));
const source = await readFile(resolve(stage, 'map_bundle_store.gd'), 'utf8');
assert.equal(createHash('sha256').update(source).digest('hex'), receipt.derivedSha256);
const at = value => {
  const index = source.indexOf(value);
  assert(index >= 0, 'missing source contract: ' + value);
  return index;
};
assert(at('var temp_before := _read(temp,') < at('DirAccess.copy_absolute(temp, backup)'));
assert(at('var preserved := _read(backup,') < at('FileAccess.open(temp, FileAccess.WRITE)'));
assert(at('var admitted_backup := _read(backup,') < at('DirAccess.remove_absolute(absolute)'));
assert(at('Patch._canonical(admitted_backup.bundle) != Patch._canonical(admitted_primary.bundle)') < at('DirAccess.remove_absolute(absolute)'));
assert(at('DirAccess.rename_absolute(temp, absolute)') < at('var promoted := _read(absolute,'));
assert(at('var backup := _read(path + ".bak",') < at('var temp := _read(path + ".tmp",'));
for (const phase of receipt.failpoints) assert(source.includes(`_trip(failpoint, "${phase}")`), 'missing failpoint ' + phase);
assert.equal(receipt.productionInstalled, false);
assert.equal(receipt.godotExecuted, false);
console.log(JSON.stringify({suite: 'map-bundle-recovery-source', checks: 15, failpoints: receipt.failpoints.length, godotExecuted: false}));
