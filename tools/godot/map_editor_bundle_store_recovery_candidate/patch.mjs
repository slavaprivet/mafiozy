/** Reviewed source-only derivative; does not edit frozen or production GDScript. */
import {readFile, mkdir, mkdtemp, writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {resolve, join} from 'node:path';
import {fileURLToPath} from 'node:url';

const here = resolve(fileURLToPath(new URL('.', import.meta.url)));
const root = resolve(here, '../../..');
const sourcePath = join(root, 'tools/godot/map_editor_candidate/scripts/map_editor/map_bundle_store.gd');
const sourceSha256 = 'ff7ce8f802c99d17647909bb8ebe93865f6f6479eea8f5c91b2e08074256ae56';
const sha = value => createHash('sha256').update(value).digest('hex');
function once(source, before, after, name) {
  if (source.split(before).length !== 2) throw Error(`Ambiguous source seam: ${name}`);
  return source.replace(before, after);
}
export function buildVariant(sourceBytes) {
  if (sha(sourceBytes) !== sourceSha256) throw Error('Frozen bundle store changed; re-review before deriving');
  let body = sourceBytes.toString('utf8');
  body = once(body,
    'static func _failure(message: String) -> Dictionary:\n\treturn {"ok": false, "error": message}\n',
    'static func _failure(message: String) -> Dictionary:\n\treturn {"ok": false, "error": message}\n\n## Test-only deterministic refusal; default Callable() never trips.\nstatic func _trip(failpoint: Callable, phase: String) -> bool:\n\treturn failpoint.is_valid() and failpoint.call(phase) == true\n\nstatic func _injected(phase: String) -> Dictionary:\n\treturn {"ok": false, "error": "Проверочный отказ сохранения: " + phase, "phase": phase}\n', 'test failpoint helper');
  body = once(body,
    '\treturn result\n\nstatic func save_bundle(',
    '\tvar temp := _read(path + ".tmp", baseline, requirements, resources, ground_validator)\n\tif temp.ok:\n\t\ttemp["recovered"] = true\n\t\ttemp["warning"] = "Основной и резервный файлы недоступны. Открыта полностью проверенная незавершённая запись."\n\t\treturn temp\n\treturn result\n\nstatic func save_bundle(', 'verified temp recovery');
  body = once(body,
    'static func save_bundle(bundle: Dictionary, baseline: Dictionary, requirements: Dictionary, resources: Dictionary, path: String = DEFAULT_PATH, ground_validator: Callable = Callable()) -> Dictionary:',
    'static func save_bundle(bundle: Dictionary, baseline: Dictionary, requirements: Dictionary, resources: Dictionary, path: String = DEFAULT_PATH, ground_validator: Callable = Callable(), failpoint: Callable = Callable()) -> Dictionary:', 'save signature');
  body = once(body,
    '\tvar temp := absolute + ".tmp"\n\tvar file := FileAccess.open(temp, FileAccess.WRITE)',
    '\tvar temp := absolute + ".tmp"\n\tvar backup := absolute + ".bak"\n\t# A prior verified temp may be the only recoverable map after first-save\n\t# interruption. Preserve it before opening the temp path for WRITE.\n\tvar primary_before := _read(absolute, baseline, requirements, resources, ground_validator)\n\tvar backup_before := _read(backup, baseline, requirements, resources, ground_validator)\n\tif not primary_before.ok and not backup_before.ok:\n\t\tvar temp_before := _read(temp, baseline, requirements, resources, ground_validator)\n\t\tif temp_before.ok:\n\t\t\terror = DirAccess.copy_absolute(temp, backup)\n\t\t\tif error != OK: return _failure("Не удалось сохранить единственную проверенную временную карту")\n\t\t\tvar preserved := _read(backup, baseline, requirements, resources, ground_validator)\n\t\t\tif not preserved.ok or Patch._canonical(preserved.bundle) != Patch._canonical(temp_before.bundle): return _failure("Резерв временной карты не прошёл проверку")\n\tif _trip(failpoint, "before_temp_write"): return _injected("before_temp_write")\n\tvar file := FileAccess.open(temp, FileAccess.WRITE)', 'prior temp preservation');
  body = once(body,
    '\tvar backup := absolute + ".bak"\n\tif FileAccess.file_exists(absolute):',
    '\tif _trip(failpoint, "after_temp_verified"): return _injected("after_temp_verified")\n\tif FileAccess.file_exists(absolute):', 'temp failpoint');
  body = once(body,
    '\t\tif _read(absolute, baseline, requirements, resources, ground_validator).ok:\n\t\t\terror = DirAccess.copy_absolute(absolute, backup)\n\t\t\tif error != OK: return _failure("Не удалось записать резервную карту")\n\t\terror = DirAccess.remove_absolute(absolute)\n\t\tif error != OK: return _failure("Не удалось заменить файл карты")\n\terror = DirAccess.rename_absolute(temp, absolute)',
    '\t\tvar admitted_primary := _read(absolute, baseline, requirements, resources, ground_validator)\n\t\tif admitted_primary.ok:\n\t\t\terror = DirAccess.copy_absolute(absolute, backup)\n\t\t\tif error != OK: return _failure("Не удалось записать резервную карту")\n\t\t\tvar admitted_backup := _read(backup, baseline, requirements, resources, ground_validator)\n\t\t\tif not admitted_backup.ok or Patch._canonical(admitted_backup.bundle) != Patch._canonical(admitted_primary.bundle): return _failure("Резервная карта не совпала с прежней")\n\t\tif _trip(failpoint, "after_backup_verified"): return _injected("after_backup_verified")\n\t\terror = DirAccess.remove_absolute(absolute)\n\t\tif error != OK: return _failure("Не удалось заменить файл карты")\n\t\tif _trip(failpoint, "after_primary_removed"): return _injected("after_primary_removed")\n\tif _trip(failpoint, "before_promote"): return _injected("before_promote")\n\terror = DirAccess.rename_absolute(temp, absolute)', 'verified backup and failpoints');
  body = once(body,
    '\treturn {"ok": true, "path": path, "bytes": encoded.text.to_utf8_buffer().size()}\n',
    '\tvar promoted := _read(absolute, baseline, requirements, resources, ground_validator)\n\tif not promoted.ok or Patch._canonical(promoted.bundle) != Patch._canonical(bundle): return _failure("Новая карта не прошла проверку после замены")\n\tif _trip(failpoint, "after_promote"): return _injected("after_promote")\n\treturn {"ok": true, "path": path, "bytes": encoded.text.to_utf8_buffer().size()}\n', 'post-promotion verification');
  return body;
}

const variant = buildVariant(await readFile(sourcePath));
const receipt = {schema: 'mafiozi.map-bundle-recovery-source/v1', frozenSourceSha256: sourceSha256, derivedSha256: sha(variant), failpoints: ['before_temp_write', 'after_temp_verified', 'after_backup_verified', 'after_primary_removed', 'before_promote', 'after_promote'], productionInstalled: false, godotExecuted: false};
if (process.argv[2] === '--check' || process.argv.length === 2) console.log(JSON.stringify({status: 'PASS_SOURCE_ONLY', receipt}));
else if (process.argv[2] === '--stage') {
  const destination = await mkdtemp(join(root, 'outputs', 'map-editor-bundle-recovery-'));
  await mkdir(destination, {recursive: true});
  await writeFile(join(destination, 'map_bundle_store.gd'), variant, {flag: 'wx'});
  await writeFile(join(destination, 'receipt.json'), JSON.stringify(receipt, null, 2) + '\n', {flag: 'wx'});
  console.log(JSON.stringify({status: 'STAGED_SOURCE_ONLY', destination, receipt}));
} else throw Error('Use --check or --stage');
