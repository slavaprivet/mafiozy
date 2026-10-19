/** Source-only proposed controller variant. Never edits the frozen candidate. */
import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {dirname, resolve} from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
export const controllerPath = resolve(here, '../map_editor_candidate/scripts/map_editor/editor_controller.gd');
export const frozenSha256 = 'd1812cb127b6526a14e12cbf047ef2a0365aba036d031060844dfc369b5e40c4';
const sha256 = text => createHash('sha256').update(text).digest('hex');

export function buildVariant(sourceBytes) {
  if (sha256(sourceBytes) !== frozenSha256) throw Error('Frozen controller changed; re-review source and hash pins');
  const source = sourceBytes.toString('utf8');
  const eol = source.includes('\r\n') ? '\r\n' : '\n';
  const anchor = [
    '\t\ttransform_extras[baseline_row.id] = extra',
    '\tfor row: Dictionary in checked.document.objects:',
  ].join(eol);
  if (source.split(anchor).length !== 2) throw Error('Protected guard insertion point is not unique');
  const insertion = [
    '\t\ttransform_extras[baseline_row.id] = extra',
    '\t# An imported document must preserve every non-editable source record',
    '\t# exactly; a native owner may accept sub-epsilon geometry as unchanged.',
    '\tvar supplied_rows := {}',
    '\tfor row: Dictionary in checked.document.objects: supplied_rows[row.id] = row',
    '\tfor baseline_row: Dictionary in _baseline.objects:',
    '\t\tif registry.is_editable(baseline_row.id): continue',
    '\t\tif not supplied_rows.has(baseline_row.id) or not _json_equal(baseline_row, supplied_rows[baseline_row.id]):',
    '\t\t\treturn {"ok": false, "error": "Защищённый исходный объект нельзя изменять или удалять: " + baseline_row.id}',
    '\tfor row: Dictionary in checked.document.objects:',
  ].join(eol);
  return source.replace(anchor, insertion);
}

export async function loadVariant() {
  return buildVariant(await readFile(controllerPath));
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const variant = await loadVariant();
  process.stdout.write(JSON.stringify({sourceSha256: frozenSha256, variantSha256: sha256(variant), bytes: Buffer.byteLength(variant), productionInstalled: false, godotExecuted: false}) + '\n');
}
