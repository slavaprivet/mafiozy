from pathlib import Path
import hashlib
import json
import shutil
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT))
from tools.godot.test_scheduler import Lease


def sha(path):
    with path.open('rb') as handle:
        return hashlib.file_digest(handle, 'sha256').hexdigest()


def pins(folder):
    return {f.relative_to(folder).as_posix(): sha(f) for f in folder.rglob('*')
            if f.is_file() and '.godot' not in f.relative_to(folder).parts}


if __name__ == '__main__':
    source = ROOT / 'outputs/coordinator30_release56/game'
    manifest = source.parent / 'ASSEMBLY.json'
    assert sha(manifest) == 'a16147bfcc8857bce47bad9a2ac44f7d5008ac3214c1a34a9bd291c55c28930a'
    expected = json.loads(manifest.read_text(encoding='utf-8-sig'))['source_pins']
    destination = HERE / 'game'
    assert not destination.exists(), 'Never overwrite an existing candidate'
    with Lease('headless', source, 'read', 30):
        with Lease('headless', destination, 'write', 30):
            assert pins(source) == expected
            destination.mkdir()
            for relative, digest in expected.items():
                target = destination / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source / relative, target)
                assert sha(target) == digest
            # Private cache copy avoids needless disk expansion and keeps the
            # frozen game's cache independent from later candidate imports.
            if (source / '.godot').exists():
                shutil.copytree(source / '.godot', destination / '.godot')
            assert pins(source) == expected == pins(destination)
            record = {'passed': True, 'source': str(source), 'candidate': str(destination),
                      'source_count': len(expected), 'source_pins': expected,
                      'frozen_unchanged': True, 'activation_changed': False,
                      'ordinary_game_preserved': True}
            (HERE / 'BASELINE31.json').write_text(json.dumps(record, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({k:v for k,v in record.items() if k != 'source_pins'}))
