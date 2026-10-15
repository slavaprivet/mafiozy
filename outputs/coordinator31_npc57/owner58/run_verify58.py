"""Bounded named run of the common build, for observing resident behaviour.

The cooperative scheduler (tools/godot/test_scheduler.py) cannot run in this
environment: its process inventory needs PowerShell 7, which is not installed.
This runner therefore never touches a foreign process. It only starts its own
engine child with an exact project path, a hard wall-clock deadline, its own
`--city-quit-after=`, and stdout/stderr in a fresh run directory. The exact
command, engine hash and the source pins of the run are written next to the log.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
# This runner lives at <root>/outputs/coordinator31_npc57/owner58, so the project
# root is three levels up from the resolved file, never from the invocation text.
ROOT = HERE.parents[2]
GAME = ROOT / 'outputs/coordinator31_npc57/game'
ASSEMBLY = ROOT / 'outputs/coordinator31_unified58/ASSEMBLY.json'
# Verified exactly what the owner opens: the shipped bootstrap named by the pointer.
BOOTSTRAP = ROOT / 'outputs/coordinator31_unified58/bootstrap_play58.gd'
RUNS = ROOT / 'outputs/coordinator31_npc57/owner58/runs'
ENGINE = Path(os.environ['LOCALAPPDATA']) / 'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def pins(project):
    return {p.relative_to(project).as_posix(): sha(p) for p in project.rglob('*')
            if p.is_file() and '.godot' not in p.relative_to(project).parts}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('name')
    parser.add_argument('--seconds', type=int, default=300)
    parser.add_argument('--extra', action='append', default=[])
    parser.add_argument('--residents', type=int, default=10)
    parser.add_argument('--window', action='store_true', help='render a visible window instead of --headless')
    parser.add_argument('--boot', type=Path, default=None,
                        help='boot script; defaults to the shipped bootstrap, or to the owner58 '
                             'verification boot (same scene plus the read-only watcher) with --window')
    args = parser.parse_args()

    if not (GAME / 'project.godot').is_file():
        raise SystemExit('project missing: ' + str(GAME))
    assembly = json.loads(ASSEMBLY.read_text(encoding='utf-8-sig'))
    run = RUNS / args.name
    if run.exists():
        raise SystemExit('run directory already exists: ' + str(run))
    run.mkdir(parents=True)

    flags = list(assembly['launch_arguments'])
    flags = [f for f in flags if not f.startswith('--city-quit-after=')]
    flags += ['--city-qa=' + str(args.residents)]
    flags += args.extra
    flags += ['--receipt-dir=' + str(run), '--city-quit-after=' + str(args.seconds)]
    bootstrap = args.boot
    if bootstrap is None:
        bootstrap = (GAME / 'scripts/owner58/boot_verify58.gd') if args.window else BOOTSTRAP
    bootstrap = Path(bootstrap).resolve()
    command = [str(ENGINE)] + ([] if args.window else ['--headless'])
    command += ['--path', str(GAME), '--script', str(bootstrap), '--', *flags]

    before = pins(GAME)
    record = {'schema': 'mafiozi.owner58.run/v1', 'name': args.name, 'command': command,
              'engine': str(ENGINE), 'engine_sha256': sha(ENGINE),
              'assembly': str(ASSEMBLY.relative_to(ROOT)).replace('\\', '/'),
              'assembly_sha256': sha(ASSEMBLY), 'bootstrap_sha256': sha(bootstrap),
              'game': str(GAME.relative_to(ROOT)).replace('\\', '/'),
              'residents': args.residents, 'requested_seconds': args.seconds,
              'extra_flags': args.extra, 'window': bool(args.window),
              'started': time.strftime('%Y-%m-%dT%H:%M:%S%z')}
    (run / 'RUN.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    (run / 'SOURCE.json').write_text(json.dumps(before, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

    started = time.monotonic()
    with (run / 'stdout.log').open('wb') as stdout, (run / 'stderr.log').open('wb') as stderr:
        process = subprocess.Popen(command, cwd=GAME, stdout=stdout, stderr=stderr,
                                   creationflags=subprocess.CREATE_NO_WINDOW)
        record['child_pid'] = process.pid
        deadline = started + args.seconds + 180
        while process.poll() is None:
            if time.monotonic() > deadline:
                process.terminate()
                try:
                    process.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    process.kill()
                record['killed_by_runner'] = True
                break
            time.sleep(.5)
        record['exit_code'] = process.returncode
        record['elapsed_seconds'] = round(time.monotonic() - started, 3)

    after = pins(GAME)
    record['source_drift'] = sorted(k for k in set(before) | set(after) if before.get(k) != after.get(k))
    record['stdout_bytes'] = (run / 'stdout.log').stat().st_size
    record['stderr_bytes'] = (run / 'stderr.log').stat().st_size
    (run / 'RUN_AFTER.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: v for k, v in record.items() if k not in ('command', 'engine')}, ensure_ascii=True))
    return 0


if __name__ == '__main__':
    sys.exit(main())
