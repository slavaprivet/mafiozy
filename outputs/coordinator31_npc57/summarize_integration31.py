"""Verify the applied integration chain and record the complete delta from release56."""
from pathlib import Path
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


if __name__ == '__main__':
    first_path = HERE / 'INTEGRATION_merged01.json'
    second_path = HERE / 'INTEGRATION_merged02.json'
    first, second = read(first_path), read(second_path)
    assert first['applied'] and second['applied']
    changes = dict(first['changes'])
    for name, item in second['changes'].items():
        assert first['source_pins'].get(name) == item['base_sha256'], name
        changes[name] = {**item, 'base_sha256': changes.get(name, item)['base_sha256']}
    game = HERE / 'game'
    current = {p.relative_to(game).as_posix(): sha(p) for p in game.rglob('*')
               if p.is_file() and '.godot' not in p.relative_to(game).parts}
    assert current == second['source_pins']
    baseline = read(ROOT / 'outputs/coordinator30_release56/ASSEMBLY.json')['source_pins']
    delta = {name for name in baseline.keys() | current.keys() if baseline.get(name) != current.get(name)}
    assert delta == set(changes)
    for name, item in changes.items():
        assert item['base_sha256'] == baseline.get(name)
        assert item['candidate_sha256'] == current.get(name)
    output = HERE / 'INTEGRATION_final02.json'
    assert not output.exists()
    value = {**second, 'changes': changes,
             'integration_chain': {str(p.relative_to(ROOT)): sha(p) for p in (first_path, second_path)},
             'source_baseline': 'outputs/coordinator30_release56/ASSEMBLY.json',
             'gameplay_acceptance_pending': True}
    output.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'verified': True, 'source_count': len(current), 'changed_files': sorted(delta),
                      'receipt': str(output)}))
