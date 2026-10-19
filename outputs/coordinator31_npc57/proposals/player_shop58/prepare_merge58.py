"""Prepare the user's e0958ff4 shop/player package against the exact NPC58 candidate."""
from pathlib import Path
import hashlib
import json
import re
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
GAME = ROOT / 'outputs/coordinator31_npc57/game'
DONOR = ROOT / 'outputs/coordinator31_player_shop57/game'
BASE = ROOT / 'outputs/coordinator31_release57/game'
COMMIT = 'e0958ff4e0e2fb350c24a126883ffd78abd64414'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None

def pins(folder):
    return {p.relative_to(folder).as_posix(): sha(p) for p in folder.rglob('*')
            if p.is_file() and '.godot' not in p.relative_to(folder).parts}

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)

def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

def main():
    assert not (HERE / 'PATCH.json').exists(), 'Never rewrite a sealed proposal'
    source = json.loads((DONOR.parent / 'INTEGRATION.json').read_text(encoding='utf-8-sig'))
    before = pins(GAME)
    donor_pins, base_pins = pins(DONOR), pins(BASE)
    declared = source['changed']
    actual_delta = {r for r in base_pins.keys() | donor_pins.keys() if base_pins.get(r) != donor_pins.get(r)}
    assert actual_delta == set(declared), sorted(actual_delta ^ set(declared))
    git('merge-base', '--is-ancestor', COMMIT, 'HEAD')
    changes, merges = {}, []
    for relative, entry in declared.items():
        donor, baseline, current = DONOR / relative, BASE / relative, GAME / relative
        assert sha(donor) == entry['candidate_sha256'], relative
        assert sha(baseline) == entry['baseline_sha256'], relative
        assert git('hash-object', str(donor)).strip() == git('rev-parse', COMMIT + ':' + donor.relative_to(ROOT).as_posix()).strip(), relative
        target = HERE / 'patch' / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        if sha(current) == entry['baseline_sha256']:
            target.write_bytes(donor.read_bytes())
        else:
            assert relative in ['scripts/main.gd', 'scripts/venues/npc_compact_glazing29.gd'], relative
            inputs = HERE / 'merge_inputs' / relative
            inputs.mkdir(parents=True, exist_ok=True)
            normalized = []
            for label, path in [('current', current), ('baseline', baseline), ('donor', donor)]:
                normalized_path = inputs / (label + '.txt')
                normalized_path.write_bytes(path.read_text(encoding='utf-8-sig').encode('utf-8'))
                normalized.append(str(normalized_path))
            merged = subprocess.run(['git', 'merge-file', '-p', *normalized], cwd=ROOT, capture_output=True)
            if merged.returncode != 0:
                (inputs / 'CONFLICT.txt').write_bytes(merged.stdout)
                assert relative == 'scripts/main.gd' and merged.returncode == 1
                text = merged.stdout.decode('utf-8')
                conflicts = list(re.finditer(r'^<<<<<<<[^\n]*\n(.*?)^=======\n(.*?)^>>>>>>>[^\n]*\n', text, re.M | re.S))
                assert len(conflicts) == 1
                conflict = conflicts[0]
                current_chunk, donor_chunk = conflict.group(1, 2)
                old_staff = '\tif OS.get_cmdline_user_args().has("--city-venue-staff29=1"):\n'
                new_staff = '\tif OS.get_cmdline_user_args().has("--city-venue-staff29=1") or player_shop_requested():\n'
                assert current_chunk.startswith('\tif city_block_mode and city_town_active():\n')
                assert current_chunk.endswith(old_staff) and donor_chunk == new_staff
                resolution = current_chunk[:-len(old_staff)] + new_staff
                text = text[:conflict.start()] + resolution + text[conflict.end():]
                assert not any(marker in text for marker in ['<<<<<<<', '=======', '>>>>>>>'])
                target.write_bytes(text.encode('utf-8'))
            else:
                target.write_bytes(merged.stdout)
            merges.append(relative)
        changes[relative] = {'base_sha256': before.get(relative), 'candidate_sha256': sha(target)}
    main_text = (HERE / 'patch/scripts/main.gd').read_text(encoding='utf-8')
    assert 'preview_homes58.bind_weapons()' in main_text
    assert 'preview_homes58.current_sites()' in main_text
    assert 'player_shop_requested()' in main_text and 'player_throwables' in main_text
    assert 'const MAX_HELPERS := 12' in (HERE / 'patch/scripts/venues/npc_compact_glazing29.gd').read_text(encoding='utf-8')
    assert pins(GAME) == before
    save(HERE / 'PATCH.json', changes)
    save(HERE / 'MERGE.json', {
        'source_commit': COMMIT, 'donor_manifest_sha256': sha(DONOR.parent / 'INTEGRATION.json'),
        'changed_paths': len(changes), 'explicit_three_way_merges': merges,
        'source_before': before, 'candidate_modified': False, 'native_validation_pending': True,
        'required_launch_argument': '--city-player-shop=1', 'f5_changed': False,
    })
    print(json.dumps({'prepared': True, 'paths': len(changes), 'three_way_merges': merges}))

if __name__ == '__main__':
    main()
