"""Apply reviewed proposal manifests under the shared candidate write lease."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT))
from tools.godot.test_scheduler import Lease

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None

def pins(folder):
    return {p.relative_to(folder).as_posix(): sha(p) for p in folder.rglob('*')
            if p.is_file() and '.godot' not in p.relative_to(folder).parts}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('name')
    parser.add_argument('packages', nargs='+', type=Path)
    args = parser.parse_args()
    assert args.name.replace('_', '').isalnum()
    output = HERE / ('INTEGRATION_' + args.name + '.json')
    assert not output.exists()
    game = HERE / 'game'
    frozen = ROOT / 'outputs/coordinator30_release56/game'
    expected_frozen = json.loads((frozen.parent / 'ASSEMBLY.json').read_text(encoding='utf-8-sig'))['source_pins']
    changes = {}
    for package in args.packages:
        package = package.resolve()
        assert package.is_relative_to(HERE / 'proposals')
        manifest = json.loads((package / 'PATCH.json').read_text(encoding='utf-8-sig'))
        for relative, item in manifest.items():
            target = (game / relative).resolve()
            source = (package / 'patch' / relative).resolve()
            assert target.is_relative_to(game) and source.is_relative_to(package / 'patch')
            assert relative not in changes, 'Overlapping patches need explicit merge'
            assert sha(source) == item['candidate_sha256']
            changes[relative] = {**item, 'source': str(source)}
    with Lease('headless', game, 'write', 45):
        before = pins(game)
        assert pins(frozen) == expected_frozen
        for relative, item in changes.items():
            assert sha(game / relative) == item['base_sha256'], relative
        for relative, item in changes.items():
            target = game / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(item['source'], target)
            assert sha(target) == item['candidate_sha256']
        after = pins(game)
        drift = sorted(k for k in before.keys() | after.keys() if before.get(k) != after.get(k))
        assert drift == sorted(changes)
        assert pins(frozen) == expected_frozen
        record = {'applied': True, 'utc': datetime.now(timezone.utc).isoformat(),
                  'candidate': str(game), 'changes': changes, 'source_pins': after,
                  'frozen_unchanged': True, 'accepted_pointer_changed': False,
                  'gameplay_acceptance_pending': True}
        output.write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'applied': True, 'changes': drift, 'receipt': str(output)}))

if __name__ == '__main__':
    main()
