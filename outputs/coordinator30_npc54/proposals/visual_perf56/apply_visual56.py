"""Exact presentation-only hunks. Root holds the target scheduler write lease."""
from pathlib import Path
import argparse, json

HERE = Path(__file__).resolve().parent
FROZEN = HERE.parents[3] / 'outputs/coordinator30_release55/game'

def proposed_files(target):
    staged, states = {}, []
    for edit in json.loads((HERE / 'HUNKS56.json').read_text(encoding='utf-8'))['edits']:
        rel = edit['path']
        path = (target / rel).resolve()
        if not path.is_relative_to(target.resolve()):
            raise ValueError('Escaping target path')
        text = staged.get(rel, path.read_text(encoding='utf-8'))
        before, after = edit['before'], edit['after']
        if text.count(after) == 1:
            state = 'already_applied'
        elif text.count(before) == 1 and (edit['name'] != 'shadow_distance' or 'var shadow_near56:' not in text):
            text = text.replace(before, after, 1)
            state = 'apply'
        else:
            raise ValueError(f'Exact hunk conflict: {rel}: {edit["name"]}')
        staged[rel] = text
        states.append({'path': rel, 'hunk': edit['name'], 'state': state})
    return staged, states

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('project', type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if not args.check and args.project.resolve() == FROZEN.resolve():
        raise ValueError('Frozen release55 is read-only; apply only to a new candidate')
    staged, states = proposed_files(args.project)
    changed = []
    for rel, text in staged.items():
        path = args.project / rel
        if path.read_text(encoding='utf-8') != text:
            changed.append(rel)
            if not args.check:
                path.write_text(text, encoding='utf-8', newline='\n')
    print(json.dumps({'checked_only': args.check, 'changed': changed, 'hunks': states}, indent=2))

if __name__ == '__main__':
    main()
