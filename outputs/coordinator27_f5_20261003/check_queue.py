"""Exercise the real launcher queue and late pointer read without any game launch."""
from pathlib import Path
import ctypes
from ctypes import wintypes
import hashlib
import json
import os
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent / "queue01"
OUT.mkdir(exist_ok=False)
repo = OUT / "isolated_repo"
script = repo / "tools/godot/launch_current_game.ps1"
script.parent.mkdir(parents=True)
shutil.copy2(ROOT / "tools/godot/launch_current_game.ps1", script)
pointer = repo / "godot/current_version.json"
pointer.parent.mkdir()
pointer.write_text(json.dumps({"schema": "before_wait_invalid"}), encoding="utf-8")
shell = Path(os.environ["USERPROFILE"]) / ".cache/codex-runtimes/codex-primary-runtime/dependencies/native/powershell/pwsh.exe"
kernel = ctypes.WinDLL("kernel32", use_last_error=True)
kernel.CreateMutexW.argtypes = [ctypes.c_void_p, wintypes.BOOL, wintypes.LPCWSTR]
kernel.CreateMutexW.restype = wintypes.HANDLE
kernel.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
kernel.WaitForSingleObject.restype = wintypes.DWORD
kernel.ReleaseMutex.argtypes = [wintypes.HANDLE]
kernel.CloseHandle.argtypes = [wintypes.HANDLE]
handle = kernel.CreateMutexW(None, False, "Local\\MafioziUnifiedPreviewLaunch")
held = False
process = None
try:
    held = kernel.WaitForSingleObject(handle, 0) in (0, 0x80)
    if not held:
        raise RuntimeError("Another owner holds the launch slot; no test dispatched")
    started = time.monotonic()
    process = subprocess.Popen([str(shell), "-NoProfile", "-File", str(script),
                                "-FromGodotPid", "2147483647", "-Quiet"],
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                               creationflags=subprocess.CREATE_NO_WINDOW)
    time.sleep(2)
    if process.poll() is not None:
        raise RuntimeError("Launcher returned before the occupied slot was released")
    # Still no valid target: this test can never launch an engine. Changing the
    # error while the slot is held proves which pointer version gets read.
    pointer.write_text(json.dumps({"schema": "mafiozi.current-play/v1",
                                  "assembly": "deliberately_missing.json"}), encoding="utf-8")
    kernel.ReleaseMutex(handle)
    held = False
    stdout, stderr = process.communicate(timeout=15)
    elapsed = time.monotonic() - started
    text = stdout.decode("utf-8-sig", errors="replace")
    result = {"passed": process.returncode == 1 and elapsed >= 2 and
              "Release file missing: deliberately_missing.json" in text and
              "Unknown current release format" not in text and not stderr,
              "exit_code": process.returncode, "elapsed_seconds": elapsed,
              "launcher_sha256": hashlib.sha256(script.read_bytes()).hexdigest(),
              "queued_while_mutex_held": True, "engine_started": False,
              "stdout": text, "stderr": stderr.decode("utf-8-sig", errors="replace")}
    (OUT / "RESULT.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(result, ensure_ascii=True))
    if not result["passed"]:
        raise SystemExit(1)
finally:
    if held:
        kernel.ReleaseMutex(handle)
    if process is not None and process.poll() is None:
        process.kill()  # Only this deliberately invalid launcher's own child.
        process.wait()
    kernel.CloseHandle(handle)
