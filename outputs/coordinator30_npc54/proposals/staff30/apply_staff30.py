"""Strict staff29 integration onto release53a or a derived new game54.

Never mutates frozen29. Caller owns destination write lease. All edits are
computed and checked before writing; only the five narrow hunks and four new
runtime files are applied. A navigation integration may change unrelated lines.
"""
import argparse
import hashlib
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]
BASE = ROOT / 'outputs/coordinator29_release53a/game'
STAFF = ROOT / 'outputs/coordinator29_npc53/proposals/venues29_staff'

def sha(raw):
    return hashlib.sha256(raw).hexdigest()

def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

def apply_hunks(text, patch):
    lines = patch.splitlines(True)
    at = 0
    while at < len(lines):
        if not lines[at].startswith('@@ '):
            at += 1
            continue
        at += 1
        old = new = ''
        while at < len(lines) and not lines[at].startswith('@@ '):
            row = lines[at]
            at += 1
            if row.startswith(' '): old += row[1:]; new += row[1:]
            elif row.startswith('-'): old += row[1:]
            elif row.startswith('+'): new += row[1:]
        if text.count(new) == 1:
            continue
        assert text.count(old) == 1, 'staff patch context drift: ' + old[:140]
        text = text.replace(old, new, 1)
    return text

def verified_changes(game):
    frozen = json.loads((STAFF / 'MANIFEST_STAFF29.json').read_text(encoding='utf-8'))
    for relative, digest in frozen['files'].items():
        assert sha((STAFF / relative).read_bytes()) == digest, 'frozen staff source drift: ' + relative
    changes = {}
    for patch in sorted(STAFF.glob('*.patch')):
        delta = patch.read_text(encoding='utf-8')
        relative = next(line[6:] for line in delta.splitlines() if line.startswith('+++ b/'))
        raw = (game / relative).read_bytes()
        updated = apply_hunks(raw.decode('utf-8').replace('\r\n', '\n'), delta).encode()
        changes[relative] = updated
    for source in sorted((STAFF / 'scripts').rglob('*.gd')):
        changes[source.relative_to(STAFF).as_posix()] = source.read_bytes()
    changes['data/venue_staff29.json'] = (STAFF / 'data/venue_staff29.json').read_bytes()
    return changes

def apply(game, report=None):
    game = Path(game).resolve()
    allowed = ROOT / 'outputs/coordinator30_npc54'
    assert game.is_relative_to(allowed.resolve()), 'destination must be inside coordinator30_npc54'
    changes = verified_changes(game)
    rows = []
    for relative, raw in changes.items():
        path = game / relative
        rows.append({'path': relative, 'before': sha(path.read_bytes()) if path.exists() else None, 'after': sha(raw)})
    for relative, raw in changes.items():
        path = game / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(raw)
    result = {'base': str(BASE), 'destination': str(game), 'changes': rows, 'staff_manifest_sha256': sha((STAFF / 'MANIFEST_STAFF29.json').read_bytes()), 'enable_flag': '--city-venue-staff29=1', 'user_game_modified': False, 'performance_accepted': False}
    if report: save(Path(report), result)
    return result

if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('game', type=Path)
    p.add_argument('--report', type=Path)
    args = p.parse_args()
    import sys
    sys.path.insert(0, str(ROOT))
    from tools.godot.test_scheduler import Lease
    with Lease(mode='headless', project=args.game, access='write', wait_seconds=60):
        result = apply(args.game, args.report)
    print(json.dumps(result, ensure_ascii=True))
