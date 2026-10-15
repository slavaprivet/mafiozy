"""Exact scoped guards only; root holds target scheduler write lease."""
from pathlib import Path
import argparse, json

HERE = Path(__file__).resolve().parent
EDITS = [
    ('scripts/npc_visual/preview_resident_host.gd', 'target_current30'),
    ('scripts/npc_visual/npc_local_preview_hit_owner.gd', 'damage_probe30'),
]

def proposed_files(target):
    staged, states = {}, []
    for rel, name in EDITS:
        path = target / rel
        text = staged.get(rel, path.read_text(encoding='utf-8'))
        before = (HERE / (name + '.before.txt')).read_text(encoding='utf-8')
        after = (HERE / (name + '.after.txt')).read_text(encoding='utf-8')
        if text.count(after) == 1:
            state = 'already_applied'
        elif text.count(before) == 1 and text.count(after) == 0:
            text = text.replace(before, after, 1)
            state = 'apply'
        else:
            raise ValueError(f'Exact hunk conflict: {rel} {name}')
        staged[rel] = text
        states.append({'path': rel, 'hunk': name, 'state': state})
    return staged, states

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('project', type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
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
