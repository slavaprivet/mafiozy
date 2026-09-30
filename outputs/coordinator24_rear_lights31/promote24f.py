"""Prepare or verify 24f; only an explicit --apply promotes the eight source files."""
from pathlib import Path
import argparse
import datetime
import difflib
import hashlib
import json
import shutil

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
OUT = REPO / 'outputs/coordinator24_delivery24f'
SHARED = REPO / 'godot/mafiozi_walk'
REVISION = 's01-20260930-quality24f'
M30 = REPO / 'outputs/coordinator24_building30/ASSEMBLY30.json'
M31 = HERE / 'ASSEMBLY31.json'
PIN30 = '18670dcf97af806bad0d36e1f5b94bb47503affdfcc1d89c9ee19ed9e3abc7a2'
PIN31 = '3309bf75e46aab302793fab686373e4e8597ed714efb01f631117fdea0f93945'
PACK = '0bd000e02db726dd9e7eccff565982222ce8dc0ef5b950209edf0c0f600d945e'
EXE = 'd34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562'
BUILD = 'fa27ab4d982ce86c9d177bb66e885edb13f4c9864a9650645c063185ec7a2ad2'
QA = '857a11f1f4b501ff233acb570837a4bf7bb01a474bef0153852251d19e543d65'
SCOPE = tuple(sorted((
    'data/preview_updates.json',
    'export_presets.cfg',
    'scripts/main.gd',
    'scripts/npc_visual/npc_bullet_marks.gd',
    'scripts/quick_controls/quick_controls.gd',
    'scripts/quick_controls/scene_hook.gd',
    'scripts/destruction/modular30/modular30_host.gd',
    'scripts/quick_controls/car_rear_lights.gd',
)))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def actual(path):
    return sha(path) if path.is_file() else None


def unscoped():
    return {p.relative_to(SHARED).as_posix(): sha(p) for p in SHARED.rglob('*')
            if p.is_file() and not any(x in ('.godot', 'exports') for x in p.relative_to(SHARED).parts)
            and p.relative_to(SHARED).as_posix() not in SCOPE}


def validate():
    require(sha(M30) == PIN30 and sha(M31) == PIN31, 'Frozen assembly changed')
    before, after = read(M30), read(M31)
    bp, ap = before['source_pins'], after['source_pins']
    require(len(bp) == 271 and len(ap) == 272, 'Unexpected closure sizes')
    require(before['revision'] == 's01-20260930-quality24e' and after['revision'] == REVISION, 'Revision mismatch')
    require(after['base_manifest_sha256'] == PIN30, 'Candidate31 base mismatch')
    require(set(bp) <= set(ap), 'Source removal forbidden')
    require({n for n in ap if bp.get(n) != ap[n]} == set(SCOPE), 'Delta differs from exact eight paths')
    require(set(ap) - set(bp) == {'scripts/quick_controls/car_rear_lights.gd'}, 'Unexpected new source')
    for manifest in (before, after):
        game = Path(manifest['game'])
        for name, pin in manifest['source_pins'].items():
            require(sha(game / name) == pin, 'Frozen source changed: ' + name)
    changes = {n: {'before': bp.get(n), 'after': ap[n]} for n in SCOPE}
    for name, pins in changes.items():
        dest = SHARED / name
        require(not dest.exists() or dest.is_file(), 'Shared destination is not a file: ' + name)
        require(actual(dest) == pins['before'], 'Concurrent scoped shared change requires merge: ' + name)
    game = Path(after['game'])
    require(REVISION in (game / 'scripts/main.gd').read_text(encoding='utf-8-sig'), 'Main revision absent')
    require(read(game / 'data/preview_updates.json')['runtime_revision'] == REVISION, 'Notes revision mismatch')
    native = HERE / 'native02/RUN.json'
    require(sha(native) == QA, 'Native QA receipt changed')
    result = read(native)
    require(result['passed'] and not result['native_errors'] and not result['source_changed'], 'Native QA failed')
    require(not result['result']['failures'] and result['result']['checks'] == 33, 'Expected native33 result missing')
    export = game / 'exports/win64' / REVISION
    require(sha(export / 'build_receipt.json') == BUILD, 'Build receipt changed')
    receipt = read(export / 'build_receipt.json')
    require(receipt['sourceInputsUnchangedDuringExport'], 'Export source guard failed')
    for row in receipt['artifacts']:
        require(Path(row['filename']).name == row['filename'], 'Invalid artifact filename')
        path = export / row['filename']
        require(sha(path) == row['sha256'] and path.stat().st_size == row['bytes'], 'Export artifact changed')
    require(sha(export / 'MafioziPreview.pck') == PACK and sha(export / 'MafioziPreview.exe') == EXE, 'Wrong 24f binary')
    return before, after, changes, export, receipt


def verify_prepared(changes, receipt):
    prepared = read(OUT / 'PREPARATION.json')
    require(prepared['status'] == 'PREPARED_NOT_APPLIED_NOT_LAUNCHED', 'Unexpected preparation status')
    require(prepared['changes'] == changes and prepared['script_sha256'] == sha(Path(__file__)), 'Prepared scope/script changed')
    require(prepared['launcher_sha256'] == sha(OUT / 'launch.ps1'), 'Launcher changed')
    require(sha(OUT / 'build_receipt.json') == BUILD, 'Copied build receipt changed')
    for row in receipt['artifacts']:
        require(sha(OUT / 'play' / row['filename']) == row['sha256'], 'Prepared artifact changed')
    require(not (OUT / 'PROMOTION.json').exists(), 'Promotion already recorded')


def prepare(before, after, changes, export, receipt):
    require(not OUT.exists(), 'Delivery directory already exists; use default verification')
    (OUT / 'play').mkdir(parents=True)
    for row in receipt['artifacts']:
        shutil.copy2(export / row['filename'], OUT / 'play' / row['filename'])
    shutil.copy2(export / 'build_receipt.json', OUT / 'build_receipt.json')
    shutil.copy2(HERE / 'launch24f.template.ps1', OUT / 'launch.ps1')
    (OUT / 'RUNTIME_GIT_FILELIST.txt').write_text(''.join('godot/mafiozi_walk/' + n + '\n' for n in SCOPE), encoding='utf-8')
    chunks = []
    for n in SCOPE:
        old = (Path(before['game']) / n).read_text(encoding='utf-8-sig').splitlines(True) if changes[n]['before'] else []
        new = (Path(after['game']) / n).read_text(encoding='utf-8-sig').splitlines(True)
        chunks.extend(difflib.unified_diff(old, new, fromfile='24e/' + n, tofile='24f/' + n))
    (OUT / 'PROMOTION.patch').write_text(''.join(chunks), encoding='utf-8')
    write(OUT / 'SOURCE_PINS.json', {'source30': before['source_pins'], 'source31': after['source_pins']})
    write(OUT / 'PREPARATION.json', {
        'status': 'PREPARED_NOT_APPLIED_NOT_LAUNCHED', 'revision': REVISION,
        'created_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'assembly30_sha256': PIN30, 'assembly31_sha256': PIN31,
        'source30_count': 271, 'source31_count': 272, 'changes': changes,
        'source_pins_sha256': sha(OUT / 'SOURCE_PINS.json'),
        'expected_shared_revision': 's01-20260930-quality24e',
        'shared_scoped_bytes_match24e': True, 'changed_existing': 7, 'added': 1,
        'script_sha256': sha(Path(__file__)), 'launcher_sha256': sha(OUT / 'launch.ps1'),
        'patch_sha256': sha(OUT / 'PROMOTION.patch'),
        'filelist_sha256': sha(OUT / 'RUNTIME_GIT_FILELIST.txt'),
        'build_receipt_sha256': BUILD, 'pack_sha256': PACK, 'exe_sha256': EXE,
        'play_directory': str(OUT / 'play'), 'native33_run_sha256': QA,
        'native33_passed': True, 'combined_gpu_claim': False,
        'living_projectile_gpu_claim': False,
        'renderer_scope': 'da1cd fixes the alternate npc_bullet_marks renderer; ordinary NPC active marks adapter already uses the corrected postmortem renderer',
        'limitations': before['known_limitations'],
        'source_writes_performed': False, 'processes_started_or_stopped': False,
        'apply_command': 'python outputs/coordinator24_rear_lights31/promote24f.py --apply',
    })


def apply(after, changes):
    untouched = unscoped()
    # All eight preconditions must still hold immediately before the first write.
    for n, pins in changes.items():
        require(actual(SHARED / n) == pins['before'], 'Shared scoped file changed: ' + n)
    for n, pins in changes.items():
        if pins['before'] is not None:
            backup = OUT / 'before' / n
            backup.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(SHARED / n, backup)
            require(sha(backup) == pins['before'], 'Backup mismatch: ' + n)
    for n, pins in changes.items():
        require(actual(SHARED / n) == pins['before'], 'Concurrent scoped write: ' + n)
        src, dest = Path(after['game']) / n, SHARED / n
        require(sha(src) == pins['after'], 'Candidate changed: ' + n)
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dest)
        require(sha(dest) == pins['after'], 'Copy verification failed: ' + n)
    require(unscoped() == untouched, 'Unscoped working files changed during promotion')
    write(OUT / 'PROMOTION.json', {
        'status': 'APPLIED_NOT_LAUNCHED', 'revision': REVISION,
        'assembly30_sha256': PIN30, 'assembly31_sha256': PIN31,
        'pack_sha256': PACK, 'exe_sha256': EXE, 'changes': changes,
        'preserved_unscoped': untouched, 'prepared_receipt_sha256': sha(OUT / 'PREPARATION.json'),
        'export': str(OUT / 'play'), 'native33_run_sha256': QA,
        'GPU_or_game_started': False, 'git_changed': False,
        'limitations': read(OUT / 'PREPARATION.json')['limitations'],
    })


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument('--prepare', action='store_true', help='Create isolated delivery and copy binaries only')
    modes.add_argument('--apply', action='store_true', help='ROOT ONLY: promote exact eight files after guards')
    args = parser.parse_args()
    before, after, changes, export, receipt = validate()
    if args.prepare:
        prepare(before, after, changes, export, receipt)
    verify_prepared(changes, receipt)
    if args.apply:
        apply(after, changes)
    print(json.dumps({'status': 'APPLIED_NOT_LAUNCHED' if args.apply else 'PREPARED_VERIFIED_NOT_APPLIED', 'changes': len(changes), 'play': str(OUT / 'play'), 'revision': REVISION}, ensure_ascii=False))
