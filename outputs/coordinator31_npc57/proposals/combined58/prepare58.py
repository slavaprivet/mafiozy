"""Seal one explicit delta: shop/player + logical routines + four nearby benches."""
from pathlib import Path
import hashlib
import json

HERE = Path(__file__).resolve().parent
WORK = HERE.parents[1]
ROOT = WORK.parents[1]
GAME = WORK / 'game'

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else None

def read(p):
    return json.loads(p.read_text(encoding='utf-8-sig'))

def save(p, data):
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

def main():
    assert not (HERE / 'PATCH.json').exists()
    proposals = WORK / 'proposals'
    inputs = [proposals / 'player_shop58/PATCH.json', proposals / 'logical_routines58/PATCH_FOR_ROOT.json',
              proposals / 'logical_routines58/BENCH_PATCH_FOR_ROOT.json']
    changes = {}
    for manifest in inputs:
        for relative, item in read(manifest).items():
            assert relative not in changes, relative
            source = manifest.parent / 'patch' / relative
            assert sha(source) == item['candidate_sha256'], relative
            assert sha(GAME / relative) == item['base_sha256'], relative
            target = HERE / 'patch' / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(source.read_bytes())
            changes[relative] = item.copy()
    main_path = HERE / 'patch/scripts/main.gd'
    source = main_path.read_text(encoding='utf-8')
    anchor = '\t\t\tpush_error("Residential geometry failed: " + str(homes_result58)); return\n'
    assert source.count(anchor) == 1
    source = source.replace(anchor, anchor +
        '\t\tvar benches_result58: Dictionary = load("res://scripts/homes/npc_home_benches58.gd").install(self, preview_homes58.current_sites())\n'
        '\t\tprint("HOME58_STREET_BENCHES ", benches_result58)\n'
        '\t\tif not benches_result58.get("ok", false):\n'
        '\t\t\tpush_error("Residential street benches failed: " + str(benches_result58)); return\n')
    main_path.write_bytes(source.encode('utf-8'))
    changes['scripts/main.gd']['candidate_sha256'] = sha(main_path)
    save(HERE / 'PATCH.json', changes)
    args = read(ROOT / 'outputs/coordinator31_player_shop57/INTEGRATION.json')['launch_arguments_for_later_review']
    assert '--city-player-shop=1' in args and '--city-qa=10' in args
    save(HERE / 'COMPOSITION.json', {
        'schema': 'mafiozi.combined-candidate58/v1', 'inputs': {str(p.relative_to(ROOT)): sha(p) for p in inputs},
        'shop_commit': 'e0958ff4e0e2fb350c24a126883ffd78abd64414', 'changed_paths': len(changes),
        'components': ['NPC doorway/recovery fixes from stage05', '4 destructible shared homes and 10 personal beds from stage05',
                       'shared day/night clock and logical needs', '4 nearby benches and physical leisure trips',
                       'player weapon shop, armor, ammunition, C4 and throwables', 'player stance and airborne combat fixes'],
        'game_relative': 'outputs/coordinator31_npc57/game', 'launch_arguments': args,
        'baseline_manifest': 'outputs/coordinator31_npc57/extended31/stage58_05/CANDIDATE58.json',
        'baseline_manifest_sha256': sha(WORK / 'extended31/stage58_05/CANDIDATE58.json'),
        'import_pending': True, 'full_gameplay_acceptance_pending': True, 'performance_pending': True,
        'known_open_failures': ['resident_6 HOME_APPROACH local path exhausted near Home2; 9 other residents sleep/exit passed'],
        'f5_release': '57', 'population': {'residents': 10, 'staff': 12, 'catalog': 287},
    })
    print(json.dumps({'prepared': True, 'changed_paths': len(changes), 'shop_enabled_in_launch_arguments': True}))

if __name__ == '__main__':
    main()
