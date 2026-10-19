"""Exact scoped integration. Caller owns target staging and its scheduler write lease."""
from pathlib import Path
import argparse, hashlib, json, sys
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]

def apply_to(project):
    project = Path(project).resolve()
    spec = json.loads((HERE / 'INTEGRATION_HUNKS.json').read_text(encoding='utf-8'))
    pending = {}
    for change in spec['changes']:
        rel = change['file']
        text = pending.get(rel, (project / rel).read_text(encoding='utf-8-sig'))
        if change['after'] in text:
            continue
        if text.count(change['before']) != 1:
            raise RuntimeError(f'Non-unique integration anchor: {rel}: {change["before"][:100]}')
        pending[rel] = text.replace(change['before'], change['after'], 1)
    for helper in (HERE / 'patch/scripts/city/runtime').glob('npc_threat_*30.gd'):
        pending[helper.relative_to(HERE / 'patch').as_posix()] = helper.read_text(encoding='utf-8')
    # Validate all anchors before the first mutation. Peer full files are never copied.
    for rel, text in pending.items():
        dest = project / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(text, encoding='utf-8')
    return {rel: hashlib.sha256((project / rel).read_bytes()).hexdigest() for rel in pending}

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('project', type=Path)
    args = parser.parse_args()
    sys.path.insert(0, str(ROOT))
    from tools.godot.test_scheduler import Lease
    with Lease('headless', args.project, 'write', 30):
        result = apply_to(args.project)
    print(json.dumps(result, indent=2))
