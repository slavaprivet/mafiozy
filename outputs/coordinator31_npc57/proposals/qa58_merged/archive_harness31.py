"""Archive exact pinned harness bytes without relying on mutable source folders."""
from pathlib import Path
import argparse
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parent.parents[3]


def archive(run):
    run = Path(run).resolve()
    pins = json.loads((run / 'HARNESS.json').read_text(encoding='utf-8-sig'))
    payloads = {}
    for name, wanted in pins.items():
        source = (ROOT / name).resolve()
        if not source.is_relative_to(ROOT):
            raise RuntimeError('Harness entry escapes repository: ' + name)
        data = source.read_bytes()
        if hashlib.sha256(data).hexdigest() != wanted:
            raise RuntimeError('Harness changed before archive: ' + name)
        payloads[name] = data
    target = run / 'HARNESS.zip'
    with zipfile.ZipFile(target, 'x', compression=zipfile.ZIP_DEFLATED) as zipped:
        for name, data in payloads.items():
            zipped.writestr(name, data)
    with zipfile.ZipFile(target) as zipped:
        if sorted(zipped.namelist()) != sorted(pins):
            raise RuntimeError('Archive inventory mismatch')
        for name, wanted in pins.items():
            if hashlib.sha256(zipped.read(name)).hexdigest() != wanted:
                raise RuntimeError('Archive entry SHA mismatch: ' + name)
    result = {'schema': 'mafiozi.soak31.harness-archive/v1', 'file': target.name,
              'sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
              'files': pins, 'verified': True, 'engine_binary_included': False}
    (run / 'HARNESS_ARCHIVE.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    return result


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('run', type=Path)
    args = p.parse_args()
    result = archive(args.run)
    print(json.dumps({'verified': result['verified'], 'sha256': result['sha256'], 'files': len(result['files'])}))
