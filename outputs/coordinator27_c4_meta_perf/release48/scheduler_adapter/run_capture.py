"""Default read-only. Exact user-editor allowance for the fixed C4 eight-charge diagnostic only."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import runpy
import shutil
import subprocess
import sys
import time
from types import SimpleNamespace

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
PACKAGE = HERE.parent
ROOT = HERE.parents[3]
BUILDER = PACKAGE / "prepare_capture.py"
BUILDER_SHA = "106d18c19ad740ee78de8986b732834c48a4578eac7233b1002e87c29a2b2690"
RUNNER = ROOT / "outputs/coordinator26_frames45/run45.py"
RUNNER_SHA = "adb9b313b553083684479a5a14ecfedeba1733f79ddfa02125dc2a416a4ac256"
GUARD = ROOT / "outputs/coordinator26_marks37_qa/run37.py"
GUARD_SHA = "1687441c667d09ce66e4b0a305e9e69171469f1b5cef265596208a5bdbf07cbf"
ENGINE = Path(os.environ["LOCALAPPDATA"]) / "MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe"
ENGINE_SHA = "ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424"
EDITOR_COMMAND = f'"{ENGINE}" --editor --path "{ROOT / "godot/mafiozi_walk"}"'
EDITOR_TITLE = "main.tscn - Мафиози — перенос в Godot - Godot Engine"
MANAGER_EXE = Path(r"C:\Users\Слава\AppData\Local\Temp\Rar$EXa31120.24411\Godot_v4.6.3-stable_win64.exe")
MANAGER_COMMAND = f'"{MANAGER_EXE}"'
MANAGER_TITLE = "Godot Engine - Менеджер проектов"
SCHEDULER = ROOT / "tools/godot/test_scheduler.py"
SCHEDULER_SHA = "6f86204fdb510a9f3d850792891fc9902301ad68b5a67688080d0ac888c3cad9"
SCHEDULE = None
ACTIVE_MODE = "headless"


def need(value, message):
    if not value:
        raise RuntimeError(message)


def sha(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def load(path, expected, name):
    need(sha(path) == expected, "Reviewed dependency changed: " + str(path))
    return runpy.run_path(str(path), run_name=name)


def inventory(timeout=15):
    pwsh = shutil.which("pwsh")
    need(pwsh, "PowerShell 7 required; inventory unavailable")
    script = "[Console]::OutputEncoding=[Text.UTF8Encoding]::new(); $diagRows=@(Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'Godot|Mafiozi' } | ForEach-Object { $diagWindow=Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue; [pscustomobject]@{ProcessId=$_.ProcessId;Name=$_.Name;ExecutablePath=$_.ExecutablePath;CommandLine=$_.CommandLine;MainWindowTitle=$diagWindow.MainWindowTitle} }); ConvertTo-Json -InputObject $diagRows -Depth 3 -Compress"
    result = subprocess.run([pwsh, "-NoProfile", "-Command", script], capture_output=True,
                            timeout=timeout, creationflags=subprocess.CREATE_NO_WINDOW)
    need(result.returncode == 0 and result.stdout.strip(), "Fresh inventory failed; preserve external processes")
    rows = json.loads(result.stdout.decode("utf-8-sig"))
    need(isinstance(rows, list), "Malformed inventory")
    return rows


def classify(rows, owned=None, retry=True):
    """An owned child requires its PID AND exact executable/command, never PID alone."""
    counts = {"editor": 0, "manager": 0, "owned": 0}
    with SCHEDULE["state_lock"](SCHEDULE["STORE"]) as state:
        registered = [dict(c) for lease in state["active"] for c in lease["children"]
                      if lease["mode"] in ("headless", "graphical") and ACTIVE_MODE != "perf"]
    rejected = []
    for row in rows:
        if SCHEDULE["identity"](row["ProcessId"]) is None:
            continue  # Inventory can finish just as a short registered child exits.
        name, exe, command, title = (row.get(k) for k in ("Name", "ExecutablePath", "CommandLine", "MainWindowTitle"))
        command = command.strip() if isinstance(command, str) else None
        if name == ENGINE.name and exe == str(ENGINE) and command == EDITOR_COMMAND and title == EDITOR_TITLE:
            counts["editor"] += 1
        elif name == MANAGER_EXE.name and exe == str(MANAGER_EXE) and command == MANAGER_COMMAND and title == MANAGER_TITLE:
            counts["manager"] += 1
        elif owned and row.get("ProcessId") == owned[0] and name == ENGINE.name and exe == str(ENGINE) and command == owned[1]:
            counts["owned"] += 1
        elif any(row.get("ProcessId") == child["pid"] and command == child["command_line"]
                 and exe and SCHEDULE["canonical"](exe) == child["executable"]
                 and SCHEDULE["alive"](child) for child in registered):
            pass  # Exact live scheduler-owned functional child; never PID-only.
        else:
            rejected.append(row)
    if rejected and retry and ACTIVE_MODE != "perf":
        time.sleep(.5)  # Popen -> register_child performs a fresh bounded CIM query.
        return classify(inventory(timeout=2), owned, retry=False)
    need(not rejected and all(count <= 1 for count in counts.values()),
         "DIAGNOSTIC_WINDOW_BLOCKED: unrecognized/duplicate editor, manager or any other game/engine; preserve them: " + repr(rejected or counts))
    return counts


def exclusive(authorization):
    need(authorization.startswith("root26-exclusive-") and len(authorization) > 20, "Missing root diagnostic authorization")
    rows = inventory()
    classify(rows)
    return rows


def source_plan(variant="candidate"):
    global SCHEDULE
    SCHEDULE = load(SCHEDULER, SCHEDULER_SHA, "diag8_settle_scheduler")
    builder = load(BUILDER, BUILDER_SHA, "diag8_editor_builder")
    guard = load(GUARD, GUARD_SHA, "diag8_editor_shared_guard")
    need(sha(RUNNER) == RUNNER_SHA and sha(ENGINE) == ENGINE_SHA, "Runner/engine identity changed")
    plans = builder["prepare"]()
    plan = next(p for p in plans if p["manifest"]["variant"] == variant)
    expected_count = 481 if variant=="baseline" else 493
    label = "baseline45" if variant=="baseline" else "candidate48"
    m = plan["manifest"]
    need(m["diagnostic_only"] is True and m["performance_accepted"] is False
         and m["source_count"] == expected_count and m["variant"] == variant and m["charge_cases"] == [1,8]
         and Path(plan["assembly"]).resolve() == (PACKAGE / label / "ASSEMBLY_CAPTURE.json").resolve(),
         "Adapter is restricted to the exact settled diagnostic eight-charge pair")
    return builder, guard, plan


def stage(builder):
    # Private loaded namespace only. The pinned stage algorithm, mutex, copy
    # bounds and before/after source checks remain byte-for-byte unchanged.
    def stage_guard(path, run_name):
        need(Path(path).resolve() == GUARD.resolve(), "Unexpected stage dependency")
        module = load(GUARD, GUARD_SHA, run_name)
        module["exclusive"] = exclusive
        return module
    namespace = builder["stage"].__globals__
    previous = namespace["runpy"]
    namespace["runpy"] = SimpleNamespace(run_path=stage_guard)
    try:
        builder["stage"]()
    finally:
        namespace["runpy"] = previous


def engine_mode(mode, name, builder, guard, plan, charges=8, entry="fast"):
    global ACTIVE_MODE
    ACTIVE_MODE = "headless" if mode == "import" else ("graphical" if entry=="fast" else "perf")
    need(re.fullmatch(r"c4_release48_[a-z0-9_]{1,48}", name or ""), "Use a fresh c4_release48_ run name")
    assembly, manifest = Path(plan["assembly"]), plan["manifest"]
    need(guard["read"](assembly) == manifest, "Staged assembly differs from exact diagnostic plan")
    game = Path(manifest["game"])
    entry_rel = builder["ENTRY_REL"] if entry=="fast" else builder["SETTLED_REL"]
    entry_sha = builder["ENTRY_SHA"] if entry=="fast" else builder["SETTLED_SHA"]
    script = game / entry_rel
    out = RUNNER.parent / "runs" / name
    need(not out.exists(), "Preserve old run evidence; choose a new name")
    import_receipt = assembly.parent / "CAPTURE_DIAGNOSTIC_IMPORTED.json"
    assembly_sha = sha(assembly)
    if mode == "fixture":
        imported = guard["read"](import_receipt)
        need(imported.get("valid_import") is True and imported.get("assembly_sha256") == assembly_sha
             and imported.get("engine_sha256") == ENGINE_SHA, "Successful exact diagnostic import required")
    else:
        need(not import_receipt.exists(), "Preserve existing successful import receipt")
    runner = load(RUNNER, RUNNER_SHA, "diag8_editor_memory_helper")
    timeout = 180 if mode == "import" else 60
    command = [str(ENGINE), "--path", str(game)]
    if mode == "import":
        command += ["--headless", "--editor", "--import", "--quit"]
    else:
        command += ["--script", str(script), "--", "--qa45-out=" + str(out), "--qa43-out=" + str(out),
                    "--charges="+str(charges), "--variant=" + manifest["variant"], "--qa-manifest=" + str(assembly), "--out=" + str(out / "RESULT.json")]
    with SCHEDULE["Lease"](ACTIVE_MODE, game, "write" if mode == "import" else "read", wait_seconds=120) as lease:
        before = exclusive("root26-exclusive-coordinator27-diag8-editor")
        guard["full_pins"](game, manifest["source_pins"])
        out.mkdir(parents=True)
        receipt = {"mode": mode, "command": command, "assembly_sha256": assembly_sha, "revision": manifest["revision"],
            "engine_sha256": ENGINE_SHA, "fixture_sha256": sha(script), "inventory_before": before,
            "gpu": mode == "fixture", "diagnostic_only": True, "performance_accepted": False,
            "adapter_sha256": sha(Path(__file__)), "runner_helper_sha256": RUNNER_SHA,
            "editor_allowance": {"executable": str(ENGINE), "command": EDITOR_COMMAND, "title": EDITOR_TITLE},
            "timeout_seconds": timeout, "valid_run": False,
            "scheduler_sha256": SCHEDULER_SHA, "scheduler_mode": ACTIVE_MODE, "lease": lease.request,
            "charges": charges, "entry_kind": entry}
        guard["write"](out / "RUN.json", receipt)
        process, samples, observation_count = None, [], 0
        started = time.monotonic()
        try:
            with (out / "stdout.log").open("xb") as stdout, (out / "stderr.log").open("xb") as stderr:
                process = subprocess.Popen(command, cwd=game, stdout=stdout, stderr=stderr)
                receipt["registered_child"] = lease.register_child(process)
                receipt["pid"] = process.pid
                guard["write"](out / "RUN.json", receipt)
                next_inventory = time.monotonic()
                while process.poll() is None:
                    now = time.monotonic()
                    if now - started >= timeout:
                        receipt["watchdog_terminated_own_child"] = True
                        break
                    if now >= next_inventory:
                        rows = inventory(timeout=min(2.0, max(.1, timeout - (now - started))))
                        observation_count += 1
                        try:
                            classify(rows, (process.pid, subprocess.list2cmdline(command)))
                        except RuntimeError as exc:
                            receipt["concurrent_inventory_violation"] = {"error": str(exc), "rows": rows}
                            break
                        next_inventory = time.monotonic() + 1.0
                    sample = runner["memory"](process)
                    if sample:
                        samples.append({"elapsed_s": round(time.monotonic() - started, 3), **sample})
                    time.sleep(.1)
        except Exception as exc:
            receipt["adapter_error"] = str(exc)
        finally:
            if process is not None and process.poll() is None:
                process.terminate()  # Only this Popen-owned child, never an inventory PID.
                process.wait(timeout=10)
                receipt["stopped_owned_child"] = True
        receipt.update(exit_code=process.returncode if process else None,
                       elapsed_s=round(time.monotonic() - started, 3), inventory_checks_during_run=observation_count,
                       memory_sample_count=len(samples))
        try:
            receipt["inventory_after"] = inventory()
            classify(receipt["inventory_after"])
            guard["full_pins"](game, manifest["source_pins"])
            receipt["source_pins_unchanged"] = True
        except Exception as exc:
            receipt["post_run_error"] = str(exc)
        if samples:
            receipt["memory_peak"] = {key: max(row[key] for row in samples) for key in samples[0] if key != "elapsed_s"}
        stdout = (out / "stdout.log").read_text(encoding="utf-8-sig", errors="replace")
        stderr = (out / "stderr.log").read_text(encoding="utf-8-sig", errors="replace")
        receipt["stderr_bytes"] = (out / "stderr.log").stat().st_size
        receipt["native_errors"] = [line for line in (stdout + "\n" + stderr).splitlines()
                                    if re.search(r"(?:SCRIPT |SHADER )?ERROR:", line)]
        failed = any(receipt.get(key) for key in ("watchdog_terminated_own_child", "concurrent_inventory_violation",
                     "adapter_error", "post_run_error", "stderr_bytes", "native_errors"))
        valid = not failed and receipt["exit_code"] == 0 and receipt.get("source_pins_unchanged") is True
        if mode == "fixture":
            try:
                report = guard["read"](out / "RESULT.json")
                e = report["evidence"]
                focus = e.get("focus_diagnostic47", {})
                receipt["focus_diagnostic"] = focus
                receipt["diagnostic_interrupted"] = focus.get("interrupted") is True
                p = e["provenance"]
                need(focus.get("schema") == "native_focus_diagnostic47/v1" and focus.get("request_count") == 1,
                     "Missing native focus diagnostic")
                need(e["charges"] == charges and e["variant"] == manifest["variant"] and e["hold_diagnostic47"]["diagnostic_only"] is True
                     and p["manifest_sha256"] == assembly_sha and p["fixture_sha256"] == entry_sha
                     and p["checked_sources"] == manifest["source_count"] and not p["mismatches"], "Missing/wrong diagnostic report provenance")
                receipt["native_report_status"] = report["status"]
                if report["status"] == "PASS":
                    settle = e.get("settle_after_q47", [])
                    if entry=="settled":
                        need(len(settle) == charges and all(row["stable_frames"] >= 3 and row["actor_drift_m"] < .001
                             and 3 <= len(row["samples"]) <= 30 for row in settle), "Missing complete bounded post-Q settles")
                    else:
                        need(not settle, "Immediate Q regression must not contain post-Q settle")
                    need(len(e["hold_diagnostic47"]["holds"])==charges and all(row["accepted"] and row["dropped_events"]==0 for row in e["hold_diagnostic47"]["holds"]), "Missing complete native holds")
                valid = valid and report["status"] == "PASS" and not report["failures"] and "C4_NATIVE PASS" in stdout
                valid = valid and focus.get("interrupted") is False and all(
                    focus.get(label, {}).get("has_focus") is True
                    and focus[label].get("unfocusable") is False and focus[label].get("mouse_passthrough") is False
                    for label in ("after_request", "final"))
            except Exception as exc:
                receipt["native_report_error"] = str(exc)
                valid = False
        receipt["valid_run"] = valid
        receipt["perf_environment_clean"] = lease.audit_perf() if ACTIVE_MODE == "perf" else False
        if ACTIVE_MODE == "perf" and not receipt["perf_environment_clean"]:
            valid = False
            receipt["valid_run"] = False
        receipt["status"] = "DIAGNOSTIC_COMPLETE_REVIEW_REQUIRED" if valid else "DIAGNOSTIC_FAILED_OR_INCOMPLETE"
        if receipt.get("diagnostic_interrupted"): receipt["status"] = "DIAGNOSTIC_INTERRUPTED_FOCUS"
        guard["write"](out / "MEMORY.json", samples)
        guard["write"](out / "RUN.json", receipt)
        if mode == "import" and valid:
            builder["write_new"](import_receipt, builder["encoded"]({"valid_import": True, "assembly_sha256": assembly_sha,
                "engine_sha256": ENGINE_SHA, "run": str(out), "run_sha256": sha(out / "RUN.json"), "diagnostic_only": True}))
        print(json.dumps(receipt, ensure_ascii=True, indent=2))
        return 0 if valid else 2


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", nargs="?", choices=["check", "import", "fixture"], default="check")
    parser.add_argument("--name")
    parser.add_argument("--variant", choices=["baseline","candidate"], default="candidate")
    parser.add_argument("--charges", type=int, choices=[1,8], default=8)
    parser.add_argument("--entry", choices=["fast","settled"], default="fast")
    args = parser.parse_args()
    builder, guard, plan = source_plan(args.variant)
    if args.mode == "check":
        rows = inventory()
        allowed = classify(rows)
        print(json.dumps({"status": "SOURCE_AND_INVENTORY_OK_READ_ONLY", "engine_started": False,
                          "source_count": plan["manifest"]["source_count"], "variant": args.variant, "inventory": rows, "allowed": allowed,
                          "diagnostic_only": True, "performance_accepted": False}, ensure_ascii=True, indent=2))
        return 0
    if args.mode == "stage":
        stage(builder)
        return 0
    return engine_mode(args.mode, args.name, builder, guard, plan, args.charges, args.entry)


if __name__ == "__main__":
    raise SystemExit(main())
