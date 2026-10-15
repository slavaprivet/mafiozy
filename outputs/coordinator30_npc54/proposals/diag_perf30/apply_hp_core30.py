"""Root invokes only while holding target project's scheduler write lease."""
from pathlib import Path
import argparse, hashlib, json

HERE = Path(__file__).resolve().parent

def proposed_files(target):
    edits = json.loads((HERE / 'HP_CORE_HUNKS30.json').read_text(encoding='utf-8'))['edits']
    staged, states = {}, []
    for edit in edits:
        rel = edit['path']
        path = (target / rel).resolve()
        if not path.is_relative_to(target.resolve()):
            raise ValueError('Path escapes target')
        text = staged.get(rel)
        if text is None:
            text = path.read_text(encoding='utf-8')
        before, after = edit['before'], edit['after']
        if text.count(after) == 1:
            state = 'already_applied'
        elif text.count(before) == 1 and text.count(after) == 0 and (not edit.get('before_at_eof') or text.endswith(before)):
            text = text.replace(before, after, 1)
            state = 'apply'
        else:
            raise ValueError(f'Exact hunk conflict: {rel} #{edit["hunk"]}')
        staged[rel] = text
        states.append({'path': rel, 'hunk': edit['hunk'], 'state': state})
    return staged, states

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('project', type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    staged, states = proposed_files(args.project)
    # Preflight every file and every exact hunk before the first write.
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
