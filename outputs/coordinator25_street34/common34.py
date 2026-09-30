"""Local, explicit Root25 staging helpers. Importing this file performs no work."""
from pathlib import Path, PurePosixPath
import hashlib
import json
import os
import subprocess

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
BASE_MANIFEST = REPO / 'outputs/coordinator24_rear_lights31/ASSEMBLY31.json'
BASE_SHA = '3309bf75e46aab302793fab686373e4e8597ed714efb01f631117fdea0f93945'
BASE_PACK_SHA = '0bd000e02db726dd9e7eccff565982222ce8dc0ef5b950209edf0c0f600d945e'
OLD_REVISION = 's01-20260930-quality24f'
REVISION = 's01-20260930-quality25a'
ASSEMBLY = HERE / 'ASSEMBLY34.json'
OWNER_MANIFEST_SHA = '74221573f899f395322b023909c6f86cbfd4cd64d7d8854a4fe99aa6bff0d5c9'
DASHBOARD_MANIFEST_SHA = '310c3636c52c60a864538ea3ad1d4b762ca0667548dcfda1aec6874b14a9ff47'
LAMP_SCRIPTS = tuple('scripts/quick_controls/' + n + '.gd' for n in
                    ('street_lamps', 'street_lamp_visual', 'street_glass_sound'))
NEW_SCRIPTS = LAMP_SCRIPTS + ('scripts/quick_controls/car_dashboard.gd',)
NEW_AUDIO = tuple('audio/street_glass_break_%02d.bytes' % n for n in range(1, 4))
OWNER_REPLACEMENTS = ('scripts/quick_controls/quick_controls.gd', 'scripts/quick_controls/scene_hook.gd')
REFERENCES = tuple('scripts/quick_controls/' + n + '.gd' for n in
                   ('car_headlights', 'car_horn', 'car_rear_lights', 'day_night', 'day_night_clock'))


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def write(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def safe_child(root, relative):
    p = PurePosixPath(relative)
    require(relative and '\\' not in relative and not p.is_absolute() and
            ':' not in relative and '..' not in p.parts, 'Unsafe relative path: ' + relative)
    result = (Path(root) / Path(*p.parts)).resolve()
    require(result.is_relative_to(Path(root).resolve()), 'Path escaped its root')
    return result


def verify_pins(game, pins):
    changed = [n for n, pin in pins.items() if not safe_child(game, n).is_file() or sha(safe_child(game, n)) != pin]
    require(not changed, 'Pinned source changed: ' + str(changed))


def load_assembly():
    m = read(ASSEMBLY)
    require(m['revision'] == REVISION and m['base_manifest_sha256'] == BASE_SHA, 'Wrong assembly')
    require(sha(BASE_MANIFEST) == BASE_SHA, 'Base manifest changed')
    base = read(BASE_MANIFEST)
    verify_pins(Path(base['game']), base['source_pins'])
    verify_pins(Path(m['game']), m['source_pins'])
    require(len(base['source_pins']) == 272 and len(m['source_pins']) == 279 and
            set(m['source_pins']) == set(base['source_pins']) | set(NEW_SCRIPTS + NEW_AUDIO), 'Closure changed')
    require(m['owner_manifest_sha256'] == OWNER_MANIFEST_SHA and
            sha(HERE / 'owner_snapshot/MANIFEST.json') == OWNER_MANIFEST_SHA, 'Frozen owner manifest changed')
    verify_pins(HERE / 'owner_snapshot', m['owner_snapshot_pins'])
    require(m['dashboard_manifest_sha256'] == DASHBOARD_MANIFEST_SHA and
            sha(HERE / 'dashboard_snapshot/MANIFEST.json') == DASHBOARD_MANIFEST_SHA, 'Frozen dashboard manifest changed')
    verify_pins(HERE / 'dashboard_snapshot', m['dashboard_snapshot_pins'])
    return m


def engine_path():
    engine = Path(os.environ['LOCALAPPDATA']) / 'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
    require(sha(engine) == 'ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424', 'Wrong engine')
    return engine


def inventory():
    command = '[Console]::OutputEncoding=[Text.UTF8Encoding]::new(); $taskRows=@(Get-CimInstance Win32_Process | Where-Object { $_.Name -match "Godot|MafioziPreview" } | Select-Object ProcessId,Name,CommandLine); ConvertTo-Json -InputObject $taskRows -Compress'
    result = subprocess.run(['powershell', '-NoProfile', '-Command', command], capture_output=True,
                            encoding='utf-8-sig', timeout=20, creationflags=subprocess.CREATE_NO_WINDOW)
    require(result.returncode == 0, 'Cannot inspect running games: ' + result.stderr)
    return json.loads(result.stdout)


def require_gpu_free(rows):
    # A plain Godot project-manager process is allowed. Any engine with task
    # arguments, including headless work, makes a comparable GPU run invalid.
    import shlex
    active = [r for r in rows if not (r['Name'].lower().startswith('godot') and
              len(shlex.split(r.get('CommandLine') or '', posix=False)) == 1)]
    require(not active, 'Existing game/work is preserved; Root must release the single GPU window: ' + str(active))
