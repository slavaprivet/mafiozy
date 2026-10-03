"""Reuse exact historical step33 player on byte-identical accepted45 baseline.

Default is read-only. --prepare writes only this directory's one-file runtime
patch, review diff and manifest. No staging, engine, Git, runtime or pointer API.
"""
from pathlib import Path
import argparse
import difflib
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / 'outputs/coordinator26_frames45/ASSEMBLY.json'
BASE_SHA = 'f797214092875a9e91cd47aa30cf751b99909f089d9b3b6bb8f4be34c6336b21'
PLAYER = 'scripts/preview_player.gd'
BEFORE = '64707b7c6d72d863651c3ce2d277af3ed2b14facbca6bb8801f41c95a2904e70'
AFTER = 'b33505b2bbadcadb5754e474f1a9cbb7b218f0abcbfa7ea7b70db8facff19d6c'
OLD = ROOT / 'outputs/coordinator25_step33'
ORIGINAL = OLD / 'files' / PLAYER
ACCEPTANCE = OLD / 'newfixture/ACCEPTANCE33.json'
ASTRA = ROOT / 'outputs/astra_dispatch_20261003/a3'
PROVENANCE = {
    ACCEPTANCE: '76d308dd85a7f0bbf39c803163a6c9f55c2963e73ea085319604f8cc7dea2812',
    OLD / 'newfixture/PROVENANCE.json': '8766a9a91d2281e9e7f8272bca6c35a2fad46527c1e8f4d772413ae8cac3374b',
    ORIGINAL: AFTER,
    OLD / 'baseline_player.gd': BEFORE,
    OLD / 'step_fragment.gd': 'd5db4768288b4ee3fc9ca8bfe147bfd9af64093a6d8a5cd533998b11db3078e5',
    ASTRA / 'step33_r3.patch': '71744e790694540ce3341408d873bd99f33f23f24004b2cca54adfbf5a034b6a',
    ASTRA / 'response04.md': '834d415c75f51d95d85ca86bf4146d2cb7b3a7b19569c4098d3fe6b41d3e1893',
}
CALLER = '''\tvar small_step_rise := 0.0
\tif is_on_floor() and not typing and not _source_falling and direction.length_squared() > 0.001 and velocity.y <= 0.001:
\t\tsmall_step_rise = _small_static_step_rise(Vector3(velocity.x, 0.0, velocity.z) * _body_motion_delta())
\t\tif small_step_rise > 0.0:
\t\t\tvelocity.y = small_step_rise / _body_motion_delta()
'''
CLEAR_RISE = '\tif small_step_rise > 0.0:\n\t\tvelocity.y = minf(velocity.y, 0.0)\n'


def need(ok, reason):
    if not ok:
        raise RuntimeError(reason)


def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def digest(data):
    return hashlib.sha256(data).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def functions(text):
    matches = list(re.finditer(r'^func ([A-Za-z_][A-Za-z_0-9]*)\(', text, re.M))
    result = {}
    for index, match in enumerate(matches):
        lines = text[match.start():matches[index + 1].start() if index + 1 < len(matches) else len(text)].splitlines()
        # Comments introducing the next function do not belong to this body.
        while lines and (not lines[-1].strip() or lines[-1].lstrip().startswith('#')):
            lines.pop()
        need(match.group(1) not in result, 'Duplicate function declaration')
        result[match.group(1)] = '\n'.join(lines)
    return result


def prepare():
    need(sha(BASE) == BASE_SHA, 'Accepted45 manifest changed; explicit rebase required')
    base = read(BASE)
    need(base.get('accepted') is True and base['source_count'] == 473 and
         base['revision'] == 's01-20261001-palazzo-frames45' and base['source_pins'][PLAYER] == BEFORE,
         'Wrong accepted baseline')
    game = Path(base['game'])
    for rel, pin in base['source_pins'].items():
        need(sha(game / rel) == pin, 'Accepted45 source drift: ' + rel)
    for path, pin in PROVENANCE.items():
        need(sha(path) == pin, 'Historical source/proposal drift: ' + str(path))
    acceptance = read(ACCEPTANCE)
    need(acceptance['player_change'] == {'before': BEFORE, 'after': AFTER} and
         acceptance['functional_accepted'] is True and acceptance['production_promoted'] is False,
         'Historical step33 acceptance provenance differs')
    before = (game / PLAYER).read_text(encoding='utf-8')
    after_bytes = ORIGINAL.read_bytes()
    after = after_bytes.decode('utf-8')
    # Prove exact three insertions; do not regenerate the historical runtime.
    capture = '\tif _final_dead_pressure_enabled: _capture_ground_pressure(direction, delta, not typing)'
    motion = '\tmove_and_slide()\n\t_ground_move_frame = Engine.get_physics_frames()'
    marker = 'func set_preview_jump_surface_guard(guard: Callable) -> void:'
    need(before.count(capture) == before.count(motion) == before.count(marker) == 1, 'Ordinary motion anchors differ')
    expected = before.replace(capture, CALLER + capture)
    expected = expected.replace(motion, '\tmove_and_slide()\n' + CLEAR_RISE + '\t_ground_move_frame = Engine.get_physics_frames()')
    expected = expected.replace(marker, (OLD / 'step_fragment.gd').read_text(encoding='utf-8') + marker)
    need(expected.encode('utf-8') == after_bytes, 'Historical runtime contains changes beyond exact step33 insertions')
    old_functions, new_functions = functions(before), functions(after)
    added = sorted(set(new_functions) - set(old_functions))
    changed = [name for name in old_functions if old_functions[name] != new_functions.get(name)]
    need(added == ['_small_static_step_rise', '_small_step_static_body'] and changed == ['_physics_process'] and
         set(old_functions) <= set(new_functions), 'Unexpected function changes')
    need(new_functions['_physics_process'].count('\tmove_and_slide()') == 1, 'Ordinary movement must remain one native move')
    need(before[:before.index('func ')] == after[:after.index('func ')], 'Fields/constants/authority state changed')
    proposal = (ASTRA / 'step33_r3.patch').read_text(encoding='utf-8')
    additions = '\n'.join(line[1:] for line in proposal.splitlines() if line.startswith('+') and not line.startswith('+++')) + '\n'
    proposed_functions = functions(additions)
    need(all(proposed_functions.get(name) == new_functions[name] for name in added), 'Astra helper differs from reviewed historical33')
    need(CALLER in additions and CLEAR_RISE in additions, 'Astra ordinary caller differs')
    diff = ''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
        fromfile='accepted45/scripts/preview_player.gd', tofile='step33_on45/scripts/preview_player.gd')).encode('utf-8')
    preserved = {name: digest(text.encode('utf-8')) for name, text in old_functions.items() if name != '_physics_process'}
    manifest = {
        'schema': 'mafiozi.root27.step33_source_rebase/v1',
        'status': 'SOURCE_READY_NOT_STAGED_NOT_PARSED_NOT_RUN',
        'base_assembly': str(BASE), 'base_assembly_sha256': BASE_SHA,
        'base_revision': base['revision'], 'base_game': str(game), 'base_source_count': 473,
        'expected_candidate_source_count': 473, 'runtime_patch_count': 1,
        'patch_files': {PLAYER: {'path': 'patch/' + PLAYER, 'before': BEFORE, 'after': AFTER,
            'origin': ORIGINAL.relative_to(ROOT).as_posix(), 'byte_exact_historical_runtime': True}},
        'diff_sha256': digest(diff), 'preparation_script_sha256': sha(Path(__file__)),
        'provenance': {path.relative_to(ROOT).as_posix(): pin for path, pin in PROVENANCE.items()},
        'source_check': {'accepted45_all_473_pins_unchanged': True, 'baseline_identical_to_historical33': True,
            'runtime_equals_exact_three_historical_insertions': True, 'changed_existing_functions': changed,
            'added_functions': added, 'preserved_existing_functions': preserved,
            'unchanged_function_count': len(preserved), 'astra3_caller_and_helper_match': True,
            'capsule_height_default_m': 1.9, 'capsule_radius_m': 0.30,
            'ordinary_native_moves_per_tick': 1, 'new_resource_dependencies': []},
        'historical_only': {'acceptance': ACCEPTANCE.relative_to(ROOT).as_posix(),
            'base_revision': acceptance['base_revision'], 'passage_checks': acceptance['runs']['passage']['checks'],
            'corpse_checks': acceptance['runs']['corpse']['checks'], 'current45_native_retested': False},
        'limits': {'static_step_max_m': 0.12, 'maximum_requested_horizontal_motion_m_per_tick': 0.12,
            'palazzo_foundation_step_m': 0.21, 'palazzo_210mm_admitted': False,
            'admitted_body': 'StaticBody3D, not AnimatableBody3D, exact collision_layer==1, zero constant velocities',
            'maximum_extra_test_move_per_attempt': 5, 'maximum_extra_rays_per_attempt': 2,
            'flat_walking_extra_test_move': 1, 'fullscene_movement_path_cost_measured': False,
            'native_120_121mm_precision_boundary': 'NOT_RUN',
            'new_palazzo_passage_qa_required': True, 'new_corpse_pressure_regression_required': True,
            'gpu': 'NOT_RUN', 'performance': 'NOT_RUN', 'godot_parser': 'NOT_RUN',
            'native': 'NOT_RUN', 'production_promoted': False, 'townhouse_restored': False,
            'dive39_or_return41_included': False, 'shared_modified': False, 'pointer_modified': False,
            'engine_started': False, 'game_staged': False},
    }
    return after_bytes, diff, manifest


def frozen_write(path, data):
    need(path.resolve().is_relative_to(HERE.resolve()), 'Output escaped isolated package')
    if path.exists():
        need(path.read_bytes() == data, 'Preserve existing differing artifact: ' + str(path))
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prepare', action='store_true', help='Write only isolated source patch/manifest; never stage or run')
    args = parser.parse_args()
    runtime, diff, manifest = prepare()
    if args.prepare:
        frozen_write(HERE / 'patch' / PLAYER, runtime)
        frozen_write(HERE / 'PLAYER_STEP33.patch', diff)
        frozen_write(HERE / 'MANIFEST.json', (json.dumps(manifest, ensure_ascii=False, indent=2) + '\n').encode('utf-8'))
    print(json.dumps({'status': manifest['status'], 'source_check_passed': True,
        'runtime_patch_count': 1, 'player_sha256': AFTER, 'unchanged_functions': 44,
        'reused_exact_historical33': True, 'engine_started': False, 'prepared': args.prepare}))
