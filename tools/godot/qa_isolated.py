"""Isolated Godot import/parse/smoke. Never runs against the supplied checkout.
Example: python qa_runner.py --source CHECKOUT --project-subdir game --sha SHA
  --godot GODOT_EXE --version 4.x.stable... --renderer gl_compatibility --out NEW_DIR
Headless success is NOT functional or GUI performance acceptance.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import runpy
import subprocess
import time


def command(args, cwd=None, timeout=30):
    return subprocess.run(args, cwd=cwd, timeout=timeout, capture_output=True,
                          text=True, encoding='utf-8', errors='replace',
                          creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)


def entry_scene(project, config):
    application = re.search(r'^\[application\]\s*\n(.*?)(?=^\[|\Z)', config, re.M | re.S)
    values = re.findall(r'^run/main_scene\s*=\s*"([^"\r\n]+)"\s*$',
                        application.group(1) if application else '', re.M)
    if len(values) != 1 or not values[0].startswith('res://'):
        raise RuntimeError('One explicit res:// application main scene required; UID scenes unsupported')
    scene = (project / values[0][6:]).resolve()
    if project not in scene.parents or not scene.is_file():
        raise RuntimeError('Entry scene must resolve inside the pinned project')
    return values[0], hashlib.sha256(scene.read_bytes()).hexdigest()


def stop_owned_child(process, wait_seconds=5):
    """Bounded cleanup using this Popen handle only, never a process-name kill."""
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=wait_seconds)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=wait_seconds)
    return process.poll() is not None


def run_stage(api, project, cmd, access, timeout, out):
    """Own the engine directly so a wrapper timeout cannot orphan it."""
    out.mkdir(parents=True, exist_ok=False)
    record = dict(mode='headless', performance_accepted=False, command=cmd, passed=False,
                  timed_out=False, cleanup_verified=False, errors=[], stderr_bytes=0,
                  perf_environment_clean=False,
                  scope='Child execution only; owner fixture assertions/source pins and performance comparison remain required')
    process = None
    started = None
    try:
        with api['Lease']('headless', project, access, 15) as lease:
            record['lease'] = lease.request
            with (out / 'stdout.log').open('wb') as stdout, (out / 'stderr.log').open('wb') as stderr:
                started = time.monotonic()
                try:
                    process = subprocess.Popen(cmd, cwd=project, stdout=stdout, stderr=stderr,
                                               creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
                    record['child'] = lease.register_child(process)
                    while True:
                        # Registration time is part of the original child deadline.
                        if time.monotonic() - started >= timeout:
                            record['timed_out'] = True
                            raise TimeoutError('Owned child watchdog timeout')
                        if process.poll() is not None:
                            break
                        time.sleep(min(.1, max(0, timeout - (time.monotonic() - started))))
                finally:
                    if process is not None:
                        record['cleanup_verified'] = stop_owned_child(process)
                        record['exit_code'] = process.returncode
                    record['elapsed_seconds'] = time.monotonic() - started
            logs = [(out / name).read_text(encoding='utf-8-sig', errors='replace')
                    for name in ('stdout.log', 'stderr.log')]
            record['errors'] = [line for log in logs for line in log.splitlines() if api['ERRORS'].search(line)]
            record['stderr_bytes'] = (out / 'stderr.log').stat().st_size
        # Lease release must also succeed before granting PASS.
        record['passed'] = (record.get('exit_code') == 0 and record['cleanup_verified']
                            and not record['errors'] and not record['stderr_bytes'])
    except Exception as exc:
        record.update(passed=False, error=str(exc))
    finally:
        logs = [(out / name).read_text(encoding='utf-8-sig', errors='replace')
                if (out / name).is_file() else '' for name in ('stdout.log', 'stderr.log')]
        record['errors'] = [line for log in logs for line in log.splitlines() if api['ERRORS'].search(line)]
        record['stderr_bytes'] = (out / 'stderr.log').stat().st_size if (out / 'stderr.log').is_file() else 0
        (out / 'SCHEDULER_RUN.json').write_text(json.dumps(record, indent=2, ensure_ascii=False), encoding='utf-8')
    return record


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    for key in ('source', 'sha', 'godot', 'version', 'renderer', 'out'):
        ap.add_argument('--' + key, required=True)
    ap.add_argument('--project-subdir', default='.')
    ap.add_argument('--smoke-frames', type=int, default=120)
    ap.add_argument('--timeout', type=int, default=240)
    ap.add_argument('--run', action='store_true', help='Execute through the pinned repository scheduler')
    a = ap.parse_args()
    if not 1 <= a.smoke_frames <= 36000 or not 1 <= a.timeout <= 600:
        ap.error('Require smoke-frames 1..36000 and timeout 1..600 seconds')
    if not a.run:
        print(json.dumps({'status': 'PLAN_ONLY', 'stages': ['import_parse', 'main_smoke'],
                          'sha': a.sha, 'version': a.version, 'renderer': a.renderer,
                          'scheduler': 'tools/godot/test_scheduler.py; pinned Lease and registered direct child'}))
        return 0
    source, out, engine = map(lambda x: Path(x).resolve(), (a.source, a.out, a.godot))
    if out == source or source in out.parents:
        raise SystemExit('Output must be outside source checkout')
    head = command(['git', '-C', str(source), 'rev-parse', 'HEAD'])
    if head.returncode or head.stdout.strip() != a.sha or not re.fullmatch('[0-9a-f]{40}', a.sha):
        raise SystemExit('Exact 40-character checkout SHA required')
    dirty = command(['git', '-C', str(source), 'status', '--porcelain'])
    if dirty.returncode or dirty.stdout.strip():
        raise SystemExit('Source dirty: require integrator-pinned clean candidate')
    scheduler = source / 'tools/godot/test_scheduler.py'
    scheduler_sha = hashlib.sha256(scheduler.read_bytes()).hexdigest()
    if scheduler_sha != 'adcb834390e476edd118f62d8e3e5b391c6ebc97925391e66beeb80430ba8373':
        raise SystemExit('Scheduler revision requires review')
    api = runpy.run_path(str(scheduler), run_name='qa_scheduler')
    out.mkdir(parents=True, exist_ok=False)
    report = dict(status='STARTED', source=str(source), sha=a.sha,
                  engine=str(engine), engine_sha256=hashlib.sha256(engine.read_bytes()).hexdigest(),
                  version=a.version, renderer=a.renderer, mode='headless',
                  rendering_qualification='Requested method only; headless does not validate GPU rendering',
                  functional_status='NOT_RUN', gui_performance_status='NOT_RUN', stages=[])
    try:
        project = (out / 'game' / a.project_subdir).resolve()
        if out / 'game' != project and out / 'game' not in project.parents:
            raise RuntimeError('Project must stay inside clone')
        with api['Lease']('headless', project, 'write', 15):
            cloned = command(['git', 'clone', '--no-hardlinks', '--no-checkout', str(source), str(out / 'game')], timeout=a.timeout)
            if cloned.returncode:
                raise RuntimeError(cloned.stderr)
            checked = command(['git', '-C', str(out / 'game'), 'checkout', '--detach', a.sha], timeout=a.timeout)
            if checked.returncode:
                raise RuntimeError(checked.stderr)
        scheduler = out / 'game/tools/godot/test_scheduler.py'
        if hashlib.sha256(scheduler.read_bytes()).hexdigest() != scheduler_sha:
            raise RuntimeError('Cloned scheduler differs from reviewed source pin')
        report['scheduler_sha256'] = scheduler_sha
        cfg = project / 'project.godot'
        if not cfg.is_file():
            raise RuntimeError('project.godot absent')
        report['project'] = str(project)
        report['project_sha256'] = hashlib.sha256(cfg.read_bytes()).hexdigest()
        report['project_config'] = cfg.read_text(encoding='utf-8-sig')
        report['entry_scene'], report['entry_scene_sha256'] = entry_scene(project, report['project_config'])
        lock = json.loads((out / 'game/docs/godot/ENGINE_LOCK.json').read_text(encoding='utf-8-sig'))
        if report['engine_sha256'] != lock['editor']['gui']['sha256']:
            raise RuntimeError('Use the locked GUI Godot binary directly')
        version = command([str(engine), '--version'])
        if version.returncode or version.stdout.strip() != a.version:
            raise RuntimeError('Exact Godot --version mismatch')
        base = [str(engine), '--headless', '--path', str(project), '--rendering-method', a.renderer]
        for name, args in [('import_parse', ['--editor', '--import']),
                           ('main_smoke', ['--quit-after', str(a.smoke_frames)])]:
            started = time.monotonic()
            cmd = base + args
            receipt = run_stage(api, project, cmd, 'write' if name == 'import_parse' else 'read', a.timeout, out / name)
            receipt_path = out / name / 'SCHEDULER_RUN.json'
            stage = dict(name=name, command=cmd, exit_code=receipt.get('exit_code'),
                         child_exit_code=receipt.get('exit_code'),
                         receipt_sha256=hashlib.sha256(receipt_path.read_bytes()).hexdigest(),
                         seconds=time.monotonic()-started,
                         status='TIMEOUT' if receipt['timed_out'] else ('PASS' if receipt['passed'] else 'FAIL'))
            (out / (name + '.log')).write_text(json.dumps(receipt, indent=2, ensure_ascii=False), encoding='utf-8')
            report['stages'].append(stage)
            if stage['status'] != 'PASS':
                raise RuntimeError(name + ': ' + stage['status'])
        report['status'] = 'HEADLESS_SMOKE_PASS_ONLY'
    except Exception as exc:
        report.update(status='FAILED', error=str(exc))
    finally:
        (out / 'RESULT.json').write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding='utf-8')
    print(json.dumps({'status': report['status'], 'report': str(out / 'RESULT.json')}))
    return 0 if report['status'] == 'HEADLESS_SMOKE_PASS_ONLY' else 1


if __name__ == '__main__':
    raise SystemExit(main())
