"""Small cooperative Windows Godot test queue. No engine starts on import.

Two CPU-bounded headless children, one graphical/input lane, exclusive perf.
Owners retain source pins and hard child timeouts. Always register Popen children
immediately. Same-project writers (staging/import/export) exclude all readers.
"""
from __future__ import annotations
import argparse
from contextlib import contextmanager
import ctypes
from ctypes import wintypes as W
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
STORE = Path(os.environ.get("LOCALAPPDATA", str(ROOT / "outputs"))) / "MafioziTools/test_scheduler"
SCHEMA = "mafiozi.test-scheduler.status/v1"
MODES = ("headless", "graphical", "perf")
ERRORS = re.compile(r"SCRIPT ERROR|SHADER ERROR|PARSE ERROR|Parse Error|(?:^|\s)ERROR:", re.I)


def need(ok, message):
    if not ok:
        raise RuntimeError(message)


def canonical(path):
    return os.path.normcase(str(Path(path).resolve()))


def api():
    need(os.name == "nt", "Windows scheduler only")
    k = ctypes.WinDLL("kernel32", use_last_error=True)
    signatures = {
        "OpenProcess": ([W.DWORD, W.BOOL, W.DWORD], W.HANDLE),
        "CloseHandle": ([W.HANDLE], W.BOOL),
        "GetProcessTimes": ([W.HANDLE] + [ctypes.POINTER(W.FILETIME)] * 4, W.BOOL),
        "CreateMutexW": ([ctypes.c_void_p, W.BOOL, W.LPCWSTR], W.HANDLE),
        "WaitForSingleObject": ([W.HANDLE, W.DWORD], W.DWORD),
        "ReleaseMutex": ([W.HANDLE], W.BOOL),
        "GetProcessAffinityMask": ([W.HANDLE, ctypes.POINTER(ctypes.c_size_t), ctypes.POINTER(ctypes.c_size_t)], W.BOOL),
        "SetProcessAffinityMask": ([W.HANDLE, ctypes.c_size_t], W.BOOL),
    }
    for name, (args, result) in signatures.items():
        getattr(k, name).argtypes, getattr(k, name).restype = args, result
    return k


def identity(pid):
    k = api()
    handle = k.OpenProcess(0x1000 | 0x100000, False, int(pid))
    if not handle:
        need(ctypes.get_last_error() in (87, 1168), "Cannot inspect process identity; fail closed")
        return None
    try:
        if k.WaitForSingleObject(handle, 0) == 0:
            return None
        values = [W.FILETIME() for _ in range(4)]
        need(k.GetProcessTimes(handle, *[ctypes.byref(x) for x in values]), "Cannot read process creation time")
        return {"pid": int(pid), "creation_filetime": str((values[0].dwHighDateTime << 32) | values[0].dwLowDateTime)}
    finally:
        k.CloseHandle(handle)


def alive(value):
    return bool(value) and identity(value["pid"]) == {k: value[k] for k in ("pid", "creation_filetime")}


def inventory(pid=None):
    pwsh = shutil.which("pwsh")
    need(pwsh, "PowerShell7 inventory unavailable")
    select = f"Get-CimInstance Win32_Process -Filter 'ProcessId={int(pid)}'" if pid else "Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'Godot|Mafiozi' }"
    code = "$ErrorActionPreference='Stop'; [Console]::OutputEncoding=[Text.UTF8Encoding]::new(); $rows=@(" + select + " | ForEach-Object { $p=Get-Process -Id $_.ProcessId -ErrorAction Stop; [pscustomobject]@{pid=[int]$_.ProcessId; parent_pid=[int]$_.ParentProcessId; creation_filetime=[string]$p.StartTime.ToFileTimeUtc(); name=$_.Name; command_line=$_.CommandLine; executable=$_.ExecutablePath; title=$p.MainWindowTitle} }); ConvertTo-Json -InputObject $rows -Compress -Depth 4"
    result = subprocess.run([pwsh, "-NoProfile", "-NonInteractive", "-Command", code], capture_output=True, timeout=15, creationflags=subprocess.CREATE_NO_WINDOW)
    need(result.returncode == 0, "Fresh process inventory failed")
    rows = json.loads(result.stdout.decode("utf-8-sig"))
    need(isinstance(rows, list), "Malformed inventory")
    return rows


@contextmanager
def mutex(name, milliseconds=3000):
    k = api(); handle = k.CreateMutexW(None, False, name)
    need(handle, "Cannot create queue mutex")
    held = False
    try:
        held = k.WaitForSingleObject(handle, milliseconds) in (0, 0x80)
        yield held
    finally:
        if held:
            k.ReleaseMutex(handle)
        k.CloseHandle(handle)


@contextmanager
def state_lock(directory):
    directory.mkdir(parents=True, exist_ok=True)
    name = "Local\\MafioziTestScheduler_" + hashlib.sha256(canonical(directory).encode()).hexdigest()[:20]
    with mutex(name) as held:
        need(held, "Queue mutex timeout")
        path = directory / "state.json"
        state = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {"version": 1, "next_ticket": 1, "pending": [], "active": []}
        need(state.get("version") == 1, "Unknown queue state; preserve it")
        state["pending"] = [x for x in state["pending"] if alive(x["owner"]) and x["deadline"] > time.monotonic()]
        # An orphan child retains its lease. Never reuse a slot solely on TTL.
        state["active"] = [x for x in state["active"] if alive(x["owner"]) or any(alive(c) for c in x["children"])]
        try:
            yield state
        finally:
            tmp = path.with_suffix(".tmp")
            tmp.write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            os.replace(tmp, path)


def conflicts(a, b):
    if "perf" in (a["mode"], b["mode"]):
        return True
    return a["project"] == b["project"] and "write" in (a["access"], b["access"])


def eligible(request, state, externally_blocked):
    active = state["active"]
    if externally_blocked(request) or any(conflicts(request, x) for x in active):
        return False
    limit = 2 if request["mode"] == "headless" else 1
    if sum(x["mode"] == request["mode"] for x in active) >= limit:
        return False
    # FIFO for competing lanes/resources; an externally blocked perf request
    # cannot stop functional work for the duration of the user's open game.
    return not any(x["ticket"] < request["ticket"] and not externally_blocked(x)
                   and (x["mode"] == request["mode"] or conflicts(request, x)) for x in state["pending"])


def same_child(row, child):
    return all(row.get(k) == child.get(k) for k in ("pid", "creation_filetime", "command_line")) and bool(row.get("executable")) and canonical(row["executable"]) == child["executable"]


def is_manager(row):
    command = row.get("command_line") or ""
    return bool(re.fullmatch(r'\s*("[^"]+"|[^\s]+)\s*(--project-manager)?\s*', command)) and row.get("title") in ("Godot Engine - Менеджер проектов", "Godot Engine - Project Manager") and bool(re.fullmatch(r"Godot_v4\.(6\.3|7\.2)-stable_win64(?:_console)?\.exe", row.get("name", "")))


def is_editor(row):
    command = row.get("command_line") or ""
    return row.get("name", "").startswith("Godot") and bool(re.search(r"(?:^|\s)(?:--editor|-e)(?:\s|$)", command)) and not re.search(r"(?:^|\s)(?:--headless|--import|--export[^\s]*|--script|-s)(?:\s|$)", command)


def stable_user_game(row):
    command = row.get("command_line") or ""
    if not command or re.search(r"(?:^|\s)--(?:headless|import|export[^\s]*)\b", command):
        return False
    # The stable user launcher runs an explicit bootstrap; other script jobs
    # are unregistered legacy diagnostics and block cooperative admission.
    pointer = ROOT / "godot/current_version.json"
    if not pointer.exists():
        return False
    value = json.loads(pointer.read_text(encoding="utf-8-sig"))
    bootstrap = (ROOT / value["bootstrap"]).resolve()
    return str(bootstrap).lower() in command.lower() and "--release-revision=" in command


def is_interactive(row):
    command = row.get("command_line") or ""
    return bool(command) and not re.search(r"(?:^|\s)--(?:headless|import|export[^\s]*)\b", command) and (not re.search(r"(?:^|\s)(?:--script|-s)\b", command) or stable_user_game(row))


def external_rows(rows, active):
    children = [c for lease in active for c in lease["children"]]
    return [r for r in rows if not any(same_child(r, c) for c in children)]


def blocked(request, external):
    for row in external:
        if is_manager(row) or is_editor(row):
            if request["access"] == "write" and request["project"].lower() in (row.get("command_line") or "").lower().replace("/", "\\"):
                return True
            continue
        if request["mode"] == "perf" or not is_interactive(row):
            return True
        # Never mutate/import the project being used by an external user/editor.
        if request["access"] == "write" and request["project"].lower() in (row.get("command_line") or "").lower().replace("/", "\\"):
            return True
    return False


def editors(rows):
    return sorted((r["pid"], r["creation_filetime"], r["command_line"], canonical(r["executable"])) for r in rows if is_editor(r))


class Lease:
    def __init__(self, mode, project, access="read", wait_seconds=120, *, _store=None):
        need(mode in MODES and access in ("read", "write"), "Invalid lease mode/access")
        need(0 < wait_seconds <= 600, "Queue wait must be in (0,600] seconds")
        self.store = Path(_store) if _store else STORE
        self.request = {"id": uuid.uuid4().hex, "owner": identity(os.getpid()), "mode": mode,
                        "project": canonical(project), "access": access, "children": [],
                        "deadline": time.monotonic() + wait_seconds}
        self.processes = []; self.acquired = False; self.perf_contaminated = False
        self._legacy = None
        self._legacy_name = r"Local\MafioziUnifiedPreviewLaunch" if _store is None else "Local\\MafioziTestScheduler_TestLegacy_" + hashlib.sha256(canonical(self.store).encode()).hexdigest()[:16]

    def __enter__(self):
        with state_lock(self.store) as state:
            self.request["ticket"] = state["next_ticket"]; state["next_ticket"] += 1
            state["pending"].append(self.request)
        try:
            while time.monotonic() < self.request["deadline"]:
                rows = inventory()
                with state_lock(self.store) as state:
                    need(time.monotonic() < self.request["deadline"], "Bounded queue wait expired")
                    ext = external_rows(rows, state["active"])
                    if eligible(self.request, state, lambda r: blocked(r, ext)):
                        # Retain the old mutex as a prelaunch bridge when free.
                        # A live user launcher may own it for its whole lifetime;
                        # functional coexistence is explicitly allowed in that case.
                        bridge = mutex(self._legacy_name, 0)
                        legacy_free = bridge.__enter__()
                        user_present = any(stable_user_game(r) for r in ext)
                        if legacy_free or (self.request["mode"] != "perf" and user_present):
                            self._legacy = bridge
                            state["pending"] = [x for x in state["pending"] if x["id"] != self.request["id"]]
                            self.request["inventory_before"] = rows
                            self.request["editor_identities"] = editors(ext)
                            state["active"].append(self.request)
                            self.acquired = True
                            return self
                        bridge.__exit__(None, None, None)
                time.sleep(.25)
            raise TimeoutError("Bounded queue wait expired; no process was stopped")
        except BaseException:
            self.release()
            raise

    def register_child(self, process):
        need(self.acquired and process.poll() is None, "Live owned Popen child required")
        need(not self.processes, "One engine child per lease; use a new lease for the next")
        self.processes.append(process)  # Even failed admission cleans up this exact child.
        command = process.args
        need(isinstance(command, (list, tuple)), "Pass Popen an argument list, not a shell command")
        command = [str(x) for x in command]
        options = command[1:command.index("--")] if "--" in command else command[1:]
        need("--path" in options and options.count("--path") == 1, "Explicit unique --path required")
        need(canonical(options[options.index("--path") + 1]) == self.request["project"], "Child uses another project")
        if self.request["mode"] == "headless":
            need("--headless" in options and "--display-driver" not in options and "--embedded" not in options, "Headless lane requires unambiguous --headless")
        if any(x in options for x in ("--editor", "-e", "--import", "--export-release", "--export-debug", "--export-pack", "--build-solutions")):
            need(self.request["access"] == "write", "Editor/import/export requires same-project write lease")
        rows = inventory(process.pid)
        need(len(rows) == 1 and rows[0]["parent_pid"] == os.getpid(), "Not the caller's direct child")
        row = rows[0]
        need(row["command_line"] == subprocess.list2cmdline(command), "Child command differs from exact Popen arguments")
        need(canonical(row["executable"]) == canonical(command[0]) and alive(row), "Child identity drift")
        child = {k: row[k] for k in ("pid", "creation_filetime", "command_line")}
        child.update(command=command, executable=canonical(row["executable"]), executable_path=canonical(row["executable"]), mode=self.request["mode"], project=self.request["project"])
        with state_lock(self.store) as state:
            lease = next(x for x in state["active"] if x["id"] == self.request["id"])
            if self.request["mode"] == "headless":
                k = api(); mask = ctypes.c_size_t(); system = ctypes.c_size_t()
                need(k.GetProcessAffinityMask(int(process._handle), ctypes.byref(mask), ctypes.byref(system)), "Cannot read child CPU affinity")
                occupied = 0
                for active in state["active"]:
                    for registered in active["children"]:
                        occupied |= registered.get("affinity_mask", 0)
                available = [1 << i for i in range(ctypes.sizeof(mask) * 8) if mask.value & (1 << i)]
                free = [bit for bit in available if not occupied & bit]
                bits = (free if len(free) >= min(2, len(available)) else available)[:2]
                need(bits and k.SetProcessAffinityMask(int(process._handle), sum(bits)), "Cannot bound child CPU affinity")
                child["affinity_mask"] = sum(bits); child["logical_cpu_limit"] = len(bits)
            lease["children"].append(child)
        self.request["children"].append(child)
        if self.request["mode"] != "perf" and self._legacy:
            self._legacy.__exit__(None, None, None); self._legacy = None
        return child

    def audit_perf(self):
        if self.request["mode"] == "perf":
            external = external_rows(inventory(), [self.request])
            self.perf_contaminated |= blocked(self.request, external) or editors(external) != self.request["editor_identities"]
        return not self.perf_contaminated

    def release(self):
        try:
            for process in self.processes:
                if process.poll() is None:
                    process.terminate(); process.wait(timeout=10)  # Exact Popen handle only.
            with state_lock(self.store) as state:
                for key in ("pending", "active"):
                    state[key] = [x for x in state[key] if x["id"] != self.request["id"]]
            self.acquired = False
        finally:
            if self._legacy:
                self._legacy.__exit__(None, None, None); self._legacy = None

    def __exit__(self, kind, error, traceback):
        try:
            if self.acquired:
                self.audit_perf()
        finally:
            self.release()
        if error is None and self.perf_contaminated:
            raise RuntimeError("PERF_CONTAMINATED: game/diagnostic appeared or editor identity changed; no performance acceptance")


def status(*, _store=None):
    directory = Path(_store) if _store else STORE
    rows = inventory()
    with state_lock(directory) as state:
        snapshot = json.loads(json.dumps(state))
    children = [dict(c, lease_id=x["id"]) for x in snapshot["active"] for c in x["children"]
                if any(same_child(r, c) for r in rows)]
    return {"schema": SCHEMA, "registered_children": children,
            "coexist_pids": [c["pid"] for c in children if c["mode"] in ("headless", "graphical")],
            "perf_active": any(x["mode"] == "perf" for x in snapshot["active"]),
            "active": snapshot["active"], "pending": snapshot["pending"], "inventory": rows,
            "performance_accepted": False, "state_file": str(directory / "state.json")}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action", required=True)
    for name in ("status", "coexist"):
        sub.add_parser(name).add_argument("--json", action="store_true")
    run = sub.add_parser("run")
    run.add_argument("--mode", choices=MODES, required=True)
    run.add_argument("--project", type=Path, required=True)
    run.add_argument("--access", choices=("read", "write"), default="read")
    run.add_argument("--wait-seconds", type=float, default=120)
    run.add_argument("--timeout", type=float, default=120)
    run.add_argument("--out", type=Path, required=True)
    run.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.action != "run":
        print(json.dumps(status(), ensure_ascii=True)); return
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    need(command and 0 < args.timeout <= 600, "Explicit engine command and timeout<=600 required")
    lock = json.loads((ROOT / "docs/godot/ENGINE_LOCK.json").read_text(encoding="utf-8-sig"))
    need(Path(command[0]).is_file() and hashlib.sha256(Path(command[0]).read_bytes()).hexdigest() == lock["editor"]["gui"]["sha256"], "Use the locked GUI Godot binary directly, not a shell/console child")
    args.out.mkdir(parents=True, exist_ok=False)
    record = {"mode": args.mode, "performance_accepted": False, "command": command, "passed": False}
    process = None
    try:
        with Lease(args.mode, args.project, args.access, args.wait_seconds) as lease:
            record["lease"] = lease.request
            with (args.out / "stdout.log").open("wb") as out, (args.out / "stderr.log").open("wb") as err:
                process = subprocess.Popen(command, cwd=args.project, stdout=out, stderr=err, creationflags=subprocess.CREATE_NO_WINDOW)
                try:
                    record["child"] = lease.register_child(process)
                    started = time.monotonic(); next_audit = started
                    while process.poll() is None:
                        need(time.monotonic() - started < args.timeout, "Owned child watchdog timeout")
                        if time.monotonic() >= next_audit:
                            lease.audit_perf(); next_audit = time.monotonic() + 1
                        time.sleep(.1)
                finally:
                    if process.poll() is None:
                        process.terminate(); process.wait(timeout=10)
                record.update(exit_code=process.returncode, elapsed_seconds=time.monotonic() - started)
            logs = [(args.out / name).read_text(encoding="utf-8-sig", errors="replace") for name in ("stdout.log", "stderr.log")]
            record["errors"] = [line for text in logs for line in text.splitlines() if ERRORS.search(line)]
            record["stderr_bytes"] = (args.out / "stderr.log").stat().st_size
            record["perf_environment_clean"] = lease.audit_perf() if args.mode == "perf" else False
            record["passed"] = process.returncode == 0 and not record["errors"] and not record["stderr_bytes"] and (args.mode != "perf" or record["perf_environment_clean"])
            record["scope"] = "Child execution only; owner fixture assertions/source pins and performance comparison remain required"
        if args.mode == "perf":
            record["perf_environment_clean"] = not lease.perf_contaminated
            record["passed"] &= not lease.perf_contaminated
    except Exception as error:
        record.update(passed=False, error=str(error))
    finally:
        (args.out / "SCHEDULER_RUN.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(record, ensure_ascii=True))
    raise SystemExit(0 if record["passed"] else 2)


if __name__ == "__main__":
    main()
