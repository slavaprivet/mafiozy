"""Freeze final lamp/dashboard receipts and assemble isolated25a; never launch."""
import argparse
import difflib
import shutil
from common34 import *

NOTES = [
    'N — день/ночь. Пули разбивают стекло уличных фонарей со звуком и гасят свет; металл свет не выключает.',
    'За рулём справа — скорость в км/ч, состояние фар F и ручника Space. Работают габариты, стопы и огни заднего хода.',
    'РПГ разрушает стены трёхэтажного дома; обломки остаются на земле. Расширяйте пробоину попаданиями в разные места.',
    'Тела жителей мешают проходу, сдвигаются ногами и сохраняют следы пуль. Житель посещает типографию.',
    'E удержать — сесть/выйти. F у багажника — открыть; E/G — взять/положить; Esc — закрыть. Q — арсенал; ЛКМ/ПКМ — огонь/прицел; R — перезарядка. B/H — взгляд назад/гудок; T — пауза времени.',
]


def inspect_package(path, expected_sha, supplied_sha, pins, scope, count, status):
    require(supplied_sha.lower() == expected_sha and sha(path) == expected_sha, 'Wrong reviewed manifest: ' + str(path))
    package = read(path)
    require(package.get('schema_version') == 2 and package.get('status') == status and package.get('gpu_tested') is True,
            'Unexpected owner schema/status')
    require(package.get('owner_thread') == '01a0f37d-8a6f-7560-a8a1-53fca08ba0e1' and
            package.get('base_revision') == OLD_REVISION and package.get('base_pack_sha256') == BASE_PACK_SHA, 'Wrong owner/base')
    rows = package['pins']
    require(len(rows) == count and len({r['path'] for r in rows}) == count, 'Payload count/uniqueness changed')
    destinations = {r['destination']: r for r in rows if r.get('destination')}
    require(len(destinations) == sum(bool(r.get('destination')) for r in rows) and set(destinations) == scope, 'Runtime scope changed')
    origins = {r['path']: safe_child(path.parent, r['path']) for r in rows}
    frozen = {r['path']: r['sha256'] for r in rows}
    for row in rows:
        if row.get('destination'):
            name = row['destination']
            require(row.get('base_sha256') == pins.get(name), 'Before-SHA mismatch: ' + name)
            if name in REFERENCES:
                require(row['sha256'] == pins[name] and row['change'] == 'unchanged_reference', 'Existing lights/time changed')
    for row in package['evidence']:
        if 'repo_relative_path' in row:
            relative = 'evidence/' + row['repo_relative_path']
            origin = safe_child(REPO, row['repo_relative_path'])
        else:
            relative = row['path']
            origin = safe_child(path.parent, relative)
        origins[relative] = origin
        frozen[relative] = row['sha256']
        if 'checks' in row:
            result = read(origin)
            require(result.get('checks') == row['checks'] and result.get('failures') == [], 'Acceptance differs from receipt')
    for name, origin in origins.items():
        require(sha(origin) == frozen[name], 'Owner payload/evidence changed: ' + str(origin))
    return package, destinations, origins, frozen


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest', required=True, type=Path, help='Final optimized24f lamp manifest')
    parser.add_argument('--manifest-sha256', required=True)
    parser.add_argument('--dashboard-manifest', required=True, type=Path)
    parser.add_argument('--dashboard-manifest-sha256', required=True)
    parser.add_argument('--check-only', action='store_true', help='Read-only verification; creates nothing')
    args = parser.parse_args()
    manifest = args.manifest.resolve()
    dashboard_manifest = args.dashboard_manifest.resolve()
    require(sha(BASE_MANIFEST) == BASE_SHA, 'Candidate31 manifest changed')
    base = read(BASE_MANIFEST)
    source, pins = Path(base['game']), base['source_pins']
    require(len(pins) == 272 and base['revision'] == OLD_REVISION, 'Expected accepted272 source closure')
    verify_pins(source, pins)
    require(sha(source / 'exports/win64' / OLD_REVISION / 'MafioziPreview.pck') == BASE_PACK_SHA, 'Accepted31 pack changed')
    for row in base['build_support']:
        require(sha(Path(base['candidate_root']) / row['Rel']) == row['Sha'], 'Export support changed')
    lamp_scope = set(LAMP_SCRIPTS + NEW_AUDIO + OWNER_REPLACEMENTS + REFERENCES)
    owner, lamp_dest, owner_origins, owner_pins = inspect_package(
        manifest, OWNER_MANIFEST_SHA, args.manifest_sha256, pins, lamp_scope, 17,
        'FUNCTIONAL_COMPONENT_OPTIMIZED_COLD_FIRST_SHOT_UNRESOLVED')
    dashboard, destinations, dash_origins, dash_pins = inspect_package(
        dashboard_manifest, DASHBOARD_MANIFEST_SHA, args.dashboard_manifest_sha256, pins,
        set(NEW_SCRIPTS + NEW_AUDIO + OWNER_REPLACEMENTS + REFERENCES + ('data/preview_updates.json',)), 20,
        'DASHBOARD_NATIVE_GPU_88_PASS_LAMPS_OPTIMIZED_COLD_WEAPON_SPIKE_OPEN')
    require((dashboard_manifest.parent / dashboard['lamp_receipt']).resolve() == manifest, 'Dashboard lamp receipt differs')
    for name in lamp_scope - {'scripts/quick_controls/quick_controls.gd'}:
        require(lamp_dest[name]['sha256'] == destinations[name]['sha256'], 'Combined lamp/reference differs: ' + name)
    require(owner.get('full_cold_performance_pass') is False and dashboard.get('dashboard_checks') == 88 and
            dashboard.get('dashboard_failures') == 0 and dashboard.get('dashboard_native_F_Space') is True, 'Reviewed acceptance changed')
    accepted = safe_child(manifest.parent, owner['accepted_test'])
    require(sha(accepted) == owner['accepted_test_sha256'] and read(accepted).get('checks') == 99 and
            read(accepted).get('failures') == [], 'Lamp99 evidence missing')
    owner_origins[owner['accepted_test']] = accepted
    owner_pins[owner['accepted_test']] = owner['accepted_test_sha256']
    for rel, checks in [('headless01/RESULT.json', 73), ('gpu01/RESULT.json', 85), ('gpu03/RESULT.json', 88)]:
        result = read(safe_child(dashboard_manifest.parent, rel))
        require(result.get('checks') == checks and result.get('failures') == [], 'Dashboard result missing: ' + rel)
    received = {r.get('repo_relative_path'): r.get('checks') for r in owner['evidence']}
    for rel, checks in [('perf24f/baseline01/RESULT.json', 117), ('perf24f/optimized01/RESULT.json', 117),
                        ('perf24f/debris_parity_gpu01/DEBRIS_PARITY_RESULT.json', 4894)]:
        require(received.get('outputs/street_lamps_20260930/' + rel) == checks, 'Lamp GPU/parity result missing')
    for relative, origin, pin, origins, frozen in [
        ('HANDOFF.txt', manifest.parent / owner['handoff'], owner['handoff_sha256'], owner_origins, owner_pins),
        ('HANDOFF.txt', dashboard_manifest.parent / 'HANDOFF.txt', '9aa6caf84bcef30ab473d6c14707907711aff4f4bae879a60ca51f55c10a9164', dash_origins, dash_pins),
        ('evidence/ACCEPTANCE.txt', dashboard_manifest.parent / dashboard['lamp_performance'], 'e3d820d6c208a54a055638f9acc8a218593275517b8f8ea2c74ae70162392c63', dash_origins, dash_pins),
    ]:
        require(sha(origin) == pin, 'Reviewed handoff/performance text changed')
        origins[relative], frozen[relative] = origin, pin
    hook = safe_child(dashboard_manifest.parent, destinations[OWNER_REPLACEMENTS[1]]['path']).read_text(encoding='utf-8-sig')
    require('notes.setup' not in hook and 'preview_updates.json' not in hook, 'Review unexpected runtime notes override')
    panel = (source / 'scripts/preview_update_panel.gd').read_text(encoding='utf-8-sig')
    require('for i in range(5):' in panel and 'items.size() < 5' in panel, 'Panel capacity changed')
    require(len(NOTES) == 5 and all(0 < len(n) <= 240 for n in NOTES) and sum(map(len, NOTES)) <= 650, 'Notes exceed limits')
    main_text = (source / 'scripts/main.gd').read_text(encoding='utf-8-sig')
    require(main_text.count(OLD_REVISION) == 1, 'Unexpected main revision references')
    notes = read(source / 'data/preview_updates.json')
    require(len(notes['items']) == 5, 'Expected five action lines')
    cfg = (source / 'export_presets.cfg').read_text(encoding='utf-8-sig')
    require(cfg.count('export_files=PackedStringArray(') == 1 and all('res://' + n not in cfg for n in NEW_SCRIPTS), 'Unexpected export script selection')
    require(cfg.count('include_filter="') == 1 and 'audio/*.bytes' not in cfg, 'Unexpected audio filter')
    if args.check_only:
        print(json.dumps({'status': 'read_only_inputs_verified', 'base_pins': 272, 'final_pins': 279,
                          'lamp_checks': [99, 117, 117, 4894], 'dashboard_checks': [73, 85, 88],
                          'notes_chars': sum(map(len, NOTES)), 'cold_metal_spike_resolved': False}))
        return
    candidate = HERE / 'candidate34'
    snapshot, dash_snapshot = HERE / 'owner_snapshot', HERE / 'dashboard_snapshot'
    require(not any(p.exists() for p in (candidate, snapshot, dash_snapshot, ASSEMBLY)), 'Preserve existing staging; do not overwrite')
    game = candidate / 'godot/mafiozi_walk'

    def copy(src, dst):
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)

    for original, target, origins in [(manifest, snapshot, owner_origins), (dashboard_manifest, dash_snapshot, dash_origins)]:
        copy(original, target / 'MANIFEST.json')
        for relative, origin in origins.items():
            copy(origin, safe_child(target, relative))
    for name in pins:
        copy(source / name, game / name)
    for file in source.rglob('*.uid'):
        if not any(p in ('.godot', 'exports') for p in file.relative_to(source).parts):
            copy(file, game / file.relative_to(source))
    copy(source / 'scripts/weapons/scope_optic.svg.import', game / 'scripts/weapons/scope_optic.svg.import')
    shutil.copytree(source / '.godot', game / '.godot')
    for row in base['build_support']:
        copy(Path(base['candidate_root']) / row['Rel'], candidate / row['Rel'])
    for name in NEW_SCRIPTS + NEW_AUDIO + OWNER_REPLACEMENTS:
        copy(safe_child(dash_snapshot, destinations[name]['path']), game / name)
    (game / 'scripts/main.gd').write_text(main_text.replace(OLD_REVISION, REVISION), encoding='utf-8', newline='\n')
    notes.update(items=NOTES, title='30.09 · Фонари и приборная панель · 25a', runtime_revision=REVISION)
    write(game / 'data/preview_updates.json', notes)
    cfg = cfg.replace('export_files=PackedStringArray(', 'export_files=PackedStringArray(' + ''.join('"res://' + n + '", ' for n in NEW_SCRIPTS), 1)
    cfg = cfg.replace('include_filter="', 'include_filter="audio/*.bytes,', 1)
    (game / 'export_presets.cfg').write_text(cfg, encoding='utf-8', newline='\n')
    source_pins = {n: sha(game / n) for n in tuple(pins) + NEW_SCRIPTS + NEW_AUDIO}
    changed = sorted(n for n in pins if source_pins[n] != pins[n])
    require(len(source_pins) == 279 and set(changed) == set(OWNER_REPLACEMENTS +
            ('scripts/main.gd', 'data/preview_updates.json', 'export_presets.cfg')), 'Unexpected accepted gameplay modification')
    verify_pins(source, pins)
    verify_pins(snapshot, owner_pins)
    verify_pins(dash_snapshot, dash_pins)
    require(sha(manifest) == OWNER_MANIFEST_SHA and sha(dashboard_manifest) == DASHBOARD_MANIFEST_SHA, 'Owner manifest changed during staging')
    patch = ''.join(''.join(difflib.unified_diff((source / n).read_text(encoding='utf-8-sig').splitlines(True),
                       (game / n).read_text(encoding='utf-8-sig').splitlines(True), fromfile='candidate31/' + n,
                       tofile='candidate34/' + n)) for n in changed)
    (HERE / 'DELTA_VS31.patch').write_text(patch, encoding='utf-8')
    # Pinned hook is already clean. Excluded local installer stays intact as evidence.
    (HERE / 'REMOVED_LOCAL_NOTES_BLOCK.txt').write_bytes(b'')
    write(ASSEMBLY, {'status': 'ISOLATED_25A_ASSEMBLED_QA_PENDING', 'revision': REVISION,
                    'candidate_root': str(candidate), 'game': str(game), 'source_count': len(source_pins),
                    'source_pins': source_pins, 'base_manifest_sha256': BASE_SHA,
                    'base_pack_sha256': BASE_PACK_SHA, 'base272_unchanged': True,
                    'changed_existing': changed, 'added': list(NEW_SCRIPTS + NEW_AUDIO),
                    'build_support': base['build_support'], 'owner_manifest_sha256': OWNER_MANIFEST_SHA,
                    'owner_original_manifest': str(manifest), 'owner_snapshot_pins': owner_pins,
                    'owner_status': owner['status'], 'owner_accepted_test_sha256': owner['accepted_test_sha256'],
                    'dashboard_manifest_sha256': DASHBOARD_MANIFEST_SHA,
                    'dashboard_original_manifest': str(dashboard_manifest), 'dashboard_snapshot_pins': dash_pins,
                    'dashboard_status': dashboard['status'], 'owner_checks': [99, 117, 117, 4894], 'dashboard_checks': 88,
                    'notes_capacity': 5, 'notes_total_chars': sum(map(len, NOTES)), 'owner_notes_not_copied': True,
                    'runtime_notes_override_removed': False, 'removed_local_notes_block': 'REMOVED_LOCAL_NOTES_BLOCK.txt',
                    'removed_local_notes_block_sha256': sha(HERE / 'REMOVED_LOCAL_NOTES_BLOCK.txt'),
                    'notes_removal_reason': 'Pinned hook clean; local installer frozen as evidence and excluded from runtime.',
                    'assembler_sha256': sha(Path(__file__)), 'common_sha256': sha(HERE / 'common34.py'),
                    'shared_modified': False, 'engine_started': False, 'full_city_performance_accepted': False,
                    'cold_metal_spike_resolved': False, 'cold_metal_observed_max_ms': 148.914,
                    'listening_accepted': False, 'integrated_dashboard_layout_accepted': False})
    print(json.dumps({'status': 'assembled_not_run', 'source_count': len(source_pins), 'assembly_sha256': sha(ASSEMBLY)}))


if __name__ == '__main__':
    main()
