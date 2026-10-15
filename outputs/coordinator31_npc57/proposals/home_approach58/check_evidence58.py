"""CPU-only verification of preserved home approach evidence. Never launches Godot."""
import hashlib
import json
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    checks = []

    def check(name, value, detail=None):
        checks.append({"name": name, "ok": bool(value), "detail": detail})

    patch = read(HERE / "PATCH.json")
    manifest_path = ROOT / "outputs/coordinator31_npc57/extended31/stage58_06/CANDIDATE58.json"
    manifest = read(manifest_path)
    expected_source = manifest["source_pins"]
    for relative, pin in patch.items():
        check("payload " + relative, sha(HERE / "patch" / relative) == pin["candidate_sha256"])
        check("base pin " + relative, expected_source.get(relative) == pin["base_sha256"])

    evidence = {}
    for name in ("native_guide01", "native_guide_candidate01", "native_cycle_candidate01"):
        run = HERE / "runs" / name
        receipt = read(run / "RUN.json")
        check(name + " clean native receipt", receipt["passed"] and receipt["exit_code"] == 0
              and receipt["stderr_bytes"] == 0 and not receipt["errors"]
              and not receipt["source_drift"] and not receipt["control_drift"])
        check(name + " source exact before/after", read(run / "SOURCE.json") == expected_source
              == read(run / "SOURCE_AFTER.json"))
        check(name + " manifest bound", receipt["source_manifest_sha256"] == sha(manifest_path))
        controls = read(run / "CONTROL_PINS.json")
        check(name + " controls stable", controls == read(run / "CONTROL_PINS_AFTER.json"))
        normalized = {Path(p).resolve().relative_to(ROOT).as_posix(): value for p, value in controls.items()}
        harness = read(run / "HARNESS.json")
        check(name + " exact declared controls archived", normalized == harness)
        with zipfile.ZipFile(run / "HARNESS.zip") as archive:
            check(name + " exact harness members", len(archive.namelist()) == len(harness)
                  and set(archive.namelist()) == set(harness))
            check(name + " archived bytes", all(hashlib.sha256(archive.read(p)).hexdigest() == v
                  for p, v in harness.items()))
        if name != "native_guide01":
            overlay = {p: v["candidate_sha256"] for p, v in patch.items()}
            check(name + " overlay declaration", read(run / "OVERLAY.json") == overlay)
            with zipfile.ZipFile(run / "OVERLAY.zip") as archive:
                check(name + " exact overlay bytes", set(archive.namelist()) == set(overlay)
                      and len(archive.namelist()) == len(overlay)
                      and all(hashlib.sha256(archive.read(p)).hexdigest() == v for p, v in overlay.items()))
        evidence[name] = {p.name: sha(p) for p in run.iterdir() if p.is_file()}

    baseline = read(HERE / "runs/native_guide01/GUIDE58.json")
    repaired = read(HERE / "runs/native_guide_candidate01/GUIDE58.json")
    check("exact original guide defect", len(baseline["interior_checkpoints"]) == 1
          and baseline["interior_checkpoints"][0]["index"] == 11
          and baseline["interior_checkpoints"][0]["inside_houses"] == ["HOME58-002"])
    check("candidate guide all checkpoints physically supported outside", not repaired["interior_checkpoints"]
          and all(p["standing"] for p in repaired["guide_points"]))
    check("exact final goal preserved", baseline["outer_target"] == repaired["outer_target"]
          == baseline["guide_points"][-1]["point"] == repaired["guide_points"][-1]["point"])
    check("existing bounded repair used", repaired["guide"]["checkpoint_repairs30"] == 1
          and repaired["guide"]["checkpoint_home_rejections58"] == 21
          and repaired["guide"]["checkpoint_probes30"] == 37)

    native = read(HERE / "runs/native_cycle_candidate01/HOME_CYCLE58.json")
    derived = read(HERE / "audits/native_cycle_candidate01/AUDIT58.json")
    check("all 55 native checks", native["passed"] and len(native["checks"]) == 55
          and all(c["ok"] for c in native["checks"]))
    check("all ten actual sleep and physical exit", len(native["final"]) == 10
          and all(r["ever_sleep"] and r["actual_exit"] for r in native["final"]))
    check("unchanged liveness gates", derived["passed"] and derived["spatial_passed"]
          and derived["motion_idle_limit_s"] == 10 and derived["queue_limit_s"] == 30)
    six = [(s["t"], next(r for r in s["actors"] if r["source_id"] == "resident_6"))
           for s in native["samples"]]
    cumulative = [r["planning_service_us"] for _, r in six]
    check("resident6 cumulative work never resets", all(b >= a for a, b in zip(cumulative, cumulative[1:])))
    check("resident6 retained approach endpoint", all(r["driver"]["target"] == repaired["outer_target"]
          for _, r in six if r["phase"] == "HOME_APPROACH" and "driver" in r))
    crossing = [r for _, r in six if r.get("driver", {}).get("guide", {}).get("waypoint") == 11]
    check("resident6 follows repaired actual checkpoint", bool(crossing)
          and all(r["driver"]["guide_point"] == repaired["guide_points"][11]["point"] for r in crossing))
    final6 = next(r for r in native["final"] if r["source_id"] == "resident_6")
    check("resident6 within existing cumulative work cap", final6["planning_service_us"] < 500000
          and not final6["exit_work_exhausted"] and final6["exit_retries"] == 0)
    check("native movement bounded", max(r["max_step_m"] for r in native["final"]) < .1)

    result = {
        "passed": all(c["ok"] for c in checks), "scope": "isolated native component acceptance; not release acceptance",
        "production_modified": False, "patch_sha256": sha(HERE / "PATCH.json"), "patch": patch,
        "checks": checks, "evidence": evidence,
        "derived_audit_sha256": sha(HERE / "audits/native_cycle_candidate01/AUDIT58.json"),
        "metrics": {"native_elapsed_s": native["elapsed_s"], "native_checks": len(native["checks"]),
                    "sleep_count": 10, "physical_exit_count": 10,
                    "max_required_motion_idle_s": max(derived["motion_idle_max_s"].values()),
                    "max_native_step_m": max(r["max_step_m"] for r in native["final"]),
                    "resident6_planning_service_us": final6["planning_service_us"],
                    "resident6_travel_m": final6["travel_m"],
                    "resident6_transitions": [{"t": t["at"], "phase": t["to"], "service_us": t["state"]["planning_service_us"]}
                                              for t in native["transitions"] if t["id"] == "resident_6"]},
        "limitations": [
            "Exact stage06 guide baseline/candidate use the same scene. Prior full-cycle failure is stage05; the successful full-cycle is stage06 plus the declared two-file overlay, not a strict whole-source performance pair.",
            "Physical component intentionally owns home intents; ordinary logical schedules are not accepted by this fixture.",
            "Headless native committed bone geometry is tested for all10. Existing graphical resident3 image and destruction proof belong to unchanged stage05 home helpers, not a new stage06 visual acceptance.",
            "Native merged-source cycle, current final ordinary behavior and matched performance remain root integration checks. No FPS claim."
        ]
    }
    (HERE / "ACCEPTANCE58.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"passed": result["passed"], "checks": len(checks), "failures": [c for c in checks if not c["ok"]], "metrics": result["metrics"]}))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
