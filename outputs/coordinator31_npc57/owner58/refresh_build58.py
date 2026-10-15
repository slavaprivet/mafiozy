"""Refresh the common-build pointer after the NPC simplification pass.

Writes, in one transaction:
  * the new behaviour flag in ASSEMBLY.json launch_arguments;
  * fresh source_pins for every game file that the assembly actually loads;
  * godot/current_version.json pointing at the refreshed assembly and its hashes.

Nothing is guessed: pins and hashes are computed from the files on disk, and the
previous pointer/assembly are kept next to the new ones with a `.before_onepass`
suffix so the owner can compare or roll back.
"""
from pathlib import Path
import hashlib
import json
import shutil

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
GAME = ROOT / 'outputs/coordinator31_npc57/game'
ASSEMBLY = ROOT / 'outputs/coordinator31_unified58/ASSEMBLY.json'
BOOTSTRAP = ROOT / 'outputs/coordinator31_unified58/bootstrap_play58.gd'
POINTER = ROOT / 'godot/current_version.json'

FLAG = '--city-passthrough58=1'
TITLE = '16.10 · Один владелец действий · версия58'
REVISION = 's01-20261016-residents58-onepass'
SCOPE = ('Single unified scene: one action owner, one goal, one prepared walking route per '
         'resident; seat reserved at goal choice and held to the action; residents pass through '
         'each other so no mutual detour is produced; an unreachable goal is replaced by another '
         'available place instead of a long dead search. Player weapon shop, needs, medical care '
         'at 50% health, threat reactions, four destructible homes and ten personal beds kept. '
         'Performance acceptance pending.')


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def pins(project):
    return {p.relative_to(project).as_posix(): sha(p) for p in project.rglob('*')
            if p.is_file() and '.godot' not in p.relative_to(project).parts}


def main():
    assembly = json.loads(ASSEMBLY.read_text(encoding='utf-8-sig'))
    before_assembly = ASSEMBLY.read_bytes()
    before_pointer = POINTER.read_bytes()
    # Keep the FIRST pre-pass bytes only. A second refresh would otherwise overwrite the
    # true "before" state with an intermediate one and destroy the comparison.
    backup_assembly = ROOT / 'outputs/coordinator31_unified58/ASSEMBLY.json.before_onepass'
    backup_pointer = ROOT / 'godot/current_version.json.before_onepass'
    if not backup_assembly.exists(): backup_assembly.write_bytes(before_assembly)
    if not backup_pointer.exists(): backup_pointer.write_bytes(before_pointer)

    flags = [flag for flag in assembly['launch_arguments'] if not flag.startswith('--city-passthrough58=')]
    flags.append(FLAG)
    old_pins = assembly['source_pins']
    new_pins = pins(GAME)

    assembly['launch_arguments'] = flags
    assembly['title'] = TITLE
    assembly['revision'] = REVISION
    assembly['note'] = SCOPE
    assembly['source_pins'] = new_pins
    assembly['source_count'] = len(new_pins)
    assembly['performance_accepted'] = False
    ASSEMBLY.write_text(json.dumps(assembly, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

    assembly_sha = sha(ASSEMBLY)
    bootstrap_sha = sha(BOOTSTRAP)
    pointer = json.loads(before_pointer.decode('utf-8-sig'))
    pointer.update({
        'title': TITLE,
        'revision': REVISION,
        'assembly': 'outputs/coordinator31_unified58/ASSEMBLY.json',
        'assembly_sha256': assembly_sha,
        'bootstrap': 'outputs/coordinator31_unified58/bootstrap_play58.gd',
        'bootstrap_sha256': bootstrap_sha,
        'scope': SCOPE,
    })
    if not (ROOT / 'outputs/coordinator31_unified58/ASSEMBLY.json.before_onepass').exists():
        (ROOT / 'outputs/coordinator31_unified58/ASSEMBLY.json.before_onepass').write_bytes(before_assembly)
    POINTER.write_text(json.dumps(pointer, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    changed = sorted(k for k in set(old_pins) | set(new_pins) if old_pins.get(k) != new_pins.get(k))
    added = sorted(k for k in new_pins if k not in old_pins)
    removed = sorted(k for k in old_pins if k not in new_pins)
    print(json.dumps({'pins': len(new_pins), 'changed': changed, 'added': added, 'removed': removed,
                      'assembly_sha256': assembly_sha, 'bootstrap_sha256': bootstrap_sha,
                      'flag': FLAG, 'revision': REVISION}, ensure_ascii=True, indent=2))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
