"""Bounded registration wait for the release48 functional inventory guard.

No engine starts on import. No process is accepted while registration is pending.
The caller retains source pins, engine pin, watchdog and final-result checks.
"""
import ctypes
import json
from pathlib import Path
import shutil
import subprocess
import time

MAX_WAIT = 16.0


def need(value, message):
    if not value:
        raise RuntimeError('REGISTRATION_GUARD: ' + message)


def argv(command):
    shell = ctypes.WinDLL('shell32', use_last_error=True)
    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    shell.CommandLineToArgvW.argtypes = [ctypes.c_wchar_p, ctypes.POINTER(ctypes.c_int)]
    shell.CommandLineToArgvW.restype = ctypes.POINTER(ctypes.c_wchar_p)
    kernel.LocalFree.argtypes = [ctypes.c_void_p]
    kernel.LocalFree.restype = ctypes.c_void_p
    count = ctypes.c_int()
    values = shell.CommandLineToArgvW(command, ctypes.byref(count))
    need(values, 'cannot parse exact Windows command')
    try:
        return [values[i] for i in range(count.value)]
    finally:
        kernel.LocalFree(values)


class RegistrationGuard:
    def __init__(self, namespace, deadline, *, wait_seconds=MAX_WAIT):
        need(callable(deadline) and 0 < wait_seconds <= MAX_WAIT, 'bounded caller deadline required')
        self.ns, self.deadline, self.wait_seconds = namespace, deadline, wait_seconds
        self.events = []

    @property
    def schedule(self):
        return self.ns['SCHEDULE']

    def snapshot(self):
        # Scheduler publishes this JSON by atomic replace. A read avoids holding
        # its mutex while the launching owner is trying to publish its child.
        state = json.loads((Path(self.schedule['STORE']) / 'state.json').read_text(encoding='utf-8'))
        need(state.get('version') == 1, 'unknown registry version')
        return state['active']

    def inventory(self, timeout=2):
        need(timeout > 0, 'inventory deadline expired')
        shell = shutil.which('pwsh'); need(shell, 'PowerShell 7 required')
        code = "[Console]::OutputEncoding=[Text.UTF8Encoding]::new(); $rows=@(Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'Godot|Mafiozi' } | ForEach-Object { $p=Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue; [pscustomobject]@{ProcessId=$_.ProcessId;ParentProcessId=$_.ParentProcessId;CreationFiletime=if($p){[string]$p.StartTime.ToFileTimeUtc()}else{$null};Name=$_.Name;ExecutablePath=$_.ExecutablePath;CommandLine=$_.CommandLine;MainWindowTitle=$p.MainWindowTitle} }); ConvertTo-Json -InputObject $rows -Compress -Depth 3"
        result = subprocess.run([shell, '-NoProfile', '-NonInteractive', '-Command', code],
                                capture_output=True, timeout=min(2, timeout), creationflags=subprocess.CREATE_NO_WINDOW)
        need(result.returncode == 0, 'fresh inventory failed')
        rows = json.loads(result.stdout.decode('utf-8-sig'))
        need(isinstance(rows, list), 'inventory must be an array')
        return rows

    def identity(self, row):
        current = self.schedule['identity'](row['ProcessId'])
        if current is not None and row.get('CreationFiletime') is not None:
            need(str(row['CreationFiletime']) == current['creation_filetime'], 'process creation identity changed')
        return current

    def registered(self, row, identity, active):
        return next(((lease, child) for lease in active for child in lease['children']
                     if child['pid'] == identity['pid'] and child['creation_filetime'] == identity['creation_filetime']
                     and child['command_line'] == row.get('CommandLine')
                     and row.get('ExecutablePath') and child['executable'] == self.schedule['canonical'](row['ExecutablePath'])
                     and self.schedule['alive'](child)), None)

    def awaiting(self, row, identity, active):
        need(row.get('Name') == self.ns['ENGINE'].name and row.get('ExecutablePath') == str(self.ns['ENGINE']), 'unknown executable')
        args = argv(row.get('CommandLine') or '')
        options = args[1:args.index('--')] if '--' in args else args[1:]
        need(args and self.schedule['canonical'](args[0]) == self.schedule['canonical'](self.ns['ENGINE']), 'command executable mismatch')
        need(options.count('--headless') == 1 and options.count('--path') == 1
             and not any(x in options for x in ('--display-driver', '--embedded')), 'not an unambiguous headless launch')
        index = options.index('--path'); need(index+1 < len(options), 'missing project')
        project = self.schedule['canonical'](options[index+1])
        matches = [lease for lease in active if lease['mode'] == 'headless' and not lease['children']
                   and lease['owner']['pid'] == row.get('ParentProcessId') and lease['project'] == project
                   and self.schedule['alive'](lease['owner'])]
        need(len(matches) == 1, 'no exact issued live-parent empty headless lease')
        lease = matches[0]
        need(int(identity['creation_filetime']) >= int(lease['owner']['creation_filetime']), 'child predates parent')
        if any(x in options for x in ('--editor', '-e', '--import', '--export-release', '--export-debug', '--export-pack', '--build-solutions')):
            need(lease['access'] == 'write', 'import/export requires write lease')
        return {'lease_id': lease['id'], 'owner': dict(lease['owner']), 'identity': identity,
                'command_line': row['CommandLine'], 'executable': row['ExecutablePath']}

    def classify(self, rows, owned=None, retry=True):
        end = min(time.monotonic()+self.wait_seconds, self.deadline())
        tracked = {}; event = None
        while True:
            need(time.monotonic() < end, 'registration/watchdog deadline expired')
            active = self.snapshot(); counts = {'editor': 0, 'manager': 0, 'owned': 0}; waiting = []
            observed = {r['ProcessId']: r for r in rows}
            for pid, saved in tracked.items():
                need(pid in observed and self.identity(observed[pid]) == saved['identity'], 'awaited child exited or identity changed before registration')
                need(self.schedule['alive'](saved['owner']), 'awaited parent identity changed')
                need(observed[pid].get('CommandLine') == saved['command_line']
                     and observed[pid].get('ExecutablePath') == saved['executable'], 'awaited command/path changed')
            for row in rows:
                identity = self.identity(row)
                if identity is None:
                    continue  # A previously observed normal/registered process exited.
                name, exe, command, title = (row.get(k) for k in ('Name','ExecutablePath','CommandLine','MainWindowTitle'))
                known = self.registered(row, identity, active)
                if name == self.ns['ENGINE'].name and exe == str(self.ns['ENGINE']) and command == self.ns['EDITOR_COMMAND'] and title == self.ns['EDITOR_TITLE']:
                    counts['editor'] += 1
                elif name == self.ns['MANAGER_EXE'].name and exe == str(self.ns['MANAGER_EXE']) and command == self.ns['MANAGER_COMMAND'] and title == self.ns['MANAGER_TITLE']:
                    counts['manager'] += 1
                elif known and owned and identity['pid'] == owned[0] and command == owned[1] and name == self.ns['ENGINE'].name and exe == str(self.ns['ENGINE']):
                    counts['owned'] += 1
                elif known and self.ns['ACTIVE_MODE'] != 'perf' and known[0]['mode'] in ('headless','graphical'):
                    pass
                else:
                    need(retry and self.ns['ACTIVE_MODE'] != 'perf', 'unrecognized process; no functional grace')
                    saved = self.awaiting(row, identity, active)
                    if identity['pid'] in tracked:
                        need(saved == tracked[identity['pid']], 'pending lease identity changed')
                    tracked[identity['pid']] = saved; waiting.append(identity['pid'])
            need(all(n <= 1 for n in counts.values()), 'duplicate editor, manager or owned child')
            need(time.monotonic() < end, 'registration/watchdog deadline expired')
            if not waiting:
                if event is not None:
                    event.update(status='REGISTERED', elapsed_seconds=time.monotonic()-event['started_monotonic'], final_rows=rows)
                return counts
            if event is None:
                event = {'status':'WAITING_FOR_REGISTRATION', 'started_monotonic':time.monotonic(), 'deadline_monotonic':end, 'initial_rows':rows}
                self.events.append(event)
            event['awaited'] = list(tracked.values())
            remaining = end-time.monotonic()
            need(remaining > .05, 'registration/watchdog deadline expired')
            time.sleep(min(.1, remaining/2))
            rows = self.inventory(timeout=end-time.monotonic())


def install(namespace, deadline):
    """Install only in a privately loaded runner namespace; record events in RUN.

    deadline() must return the ORIGINAL engine start+timeout, never a renewed
    budget. Before child start it may return monotonic()+16 for a preflight.
    """
    ns = namespace['classify'].__globals__
    guard = RegistrationGuard(ns, deadline)
    ns['classify'], ns['inventory'] = guard.classify, guard.inventory
    return guard
