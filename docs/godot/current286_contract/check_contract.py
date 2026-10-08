"""Check source anchors and manifest completeness; never certifies gameplay."""
import argparse
import hashlib
import json
import re
from pathlib import Path


def missing(value):
    return value is None or value == "" or value == "UNRESOLVED" or value == [] or value == {}


def check_runtime_receipt(run, manifest_path, fields, errors):
    sid = run["scenario_id"]
    receipt = run.get("runtime_receipt")
    if not isinstance(receipt, dict) or missing(receipt.get("path")) or missing(receipt.get("sha256")):
        errors.append(f"{sid}: PASS requires a nonempty runtime receipt path and SHA256")
        return
    root = manifest_path.parent.resolve()
    path = (root / receipt["path"]).resolve()
    if Path(receipt["path"]).is_absolute() or not path.is_relative_to(root) or not path.is_file():
        errors.append(f"{sid}: runtime receipt must exist inside the manifest directory")
        return
    content = path.read_bytes()
    if hashlib.sha256(content).hexdigest() != receipt["sha256"]:
        errors.append(f"{sid}: runtime receipt SHA256 mismatch")
        return
    try:
        actual = json.loads(content)
    except (ValueError, UnicodeError):
        errors.append(f"{sid}: runtime receipt is not JSON")
        return
    if not isinstance(actual, dict) or not actual:
        errors.append(f"{sid}: empty/non-object runtime receipt")
        return
    for field in fields:
        if field == "evidence":
            continue
        if missing(actual.get(field)) or actual.get(field) != run.get(field):
            errors.append(f"{sid}: runtime receipt metadata mismatch/missing {field}")
    if actual.get("evidence") != run.get("evidence"):
        errors.append(f"{sid}: runtime receipt evidence differs from manifest")
    for field in ("started_at", "completed_at"):
        if missing(actual.get(field)):
            errors.append(f"{sid}: runtime receipt missing {field}")
    if type(actual.get("exit_code")) is not int or actual["exit_code"] != 0:
        errors.append(f"{sid}: runtime receipt requires exit_code 0")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("contract", type=Path)
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--manifest", type=Path)
    args = parser.parse_args()
    contract = json.loads(args.contract.read_text(encoding="utf-8"))
    root = args.source_root.resolve()
    errors = []
    ids = set()
    pins = {}
    for scenario in contract["scenarios"]:
        sid = scenario["id"]
        if sid in ids:
            errors.append(f"Duplicate scenario: {sid}")
        ids.add(sid)
        for field in ("trigger", "expected", "source_refs", "evidence_fields", "state"):
            if not scenario.get(field):
                errors.append(f"{sid}: missing {field}")
        for ref in scenario["source_refs"]:
            path = (root / ref["path"]).resolve()
            if not path.is_relative_to(root) or not path.is_file():
                errors.append(f"{sid}: missing/unsafe source {ref['path']}")
                continue
            content = path.read_bytes()
            text = content.decode("utf-8-sig")
            if ref["anchor"] not in text:
                errors.append(f"{sid}: missing anchor {ref['path']} :: {ref['anchor']}")
            pins[ref["path"]] = hashlib.sha256(content).hexdigest()
            if ref.get("sha256") != pins[ref["path"]]:
                errors.append(f"{sid}: source hash mismatch {ref['path']}")
    manifests = []
    if args.manifest:
        manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
        runs = manifest.get("runs", [])
        by_id = {}
        for run in runs:
            sid = run.get("scenario_id")
            if sid not in ids or sid in by_id:
                errors.append(f"Unknown/duplicate manifest scenario: {sid}")
            by_id[sid] = run
        for scenario in contract["scenarios"]:
            sid = scenario["id"]
            run = by_id.get(sid)
            if run is None:
                errors.append(f"Missing manifest scenario: {sid}")
                continue
            for field in contract["required_run_fields"]:
                if field not in run or run[field] in (None, ""):
                    errors.append(f"{sid}: missing run field {field}")
            if run.get("status") not in ("PASS", "FAIL", "NOT_RUN", "BLOCKED"):
                errors.append(f"{sid}: invalid status")
            if run.get("status") == "PASS":
                if any(missing(run.get(field)) for field in contract["required_run_fields"]):
                    errors.append(f"{sid}: PASS has unresolved run metadata")
                for field, size in (("source_sha", 40), ("assembly_manifest_sha256", 64)):
                    if not re.fullmatch(r"[0-9a-f]{" + str(size) + r"}", str(run.get(field, ""))):
                        errors.append(f"{sid}: invalid {field}")
                if run.get("scene") != contract["target_scene"] or run.get("population") != contract["target_population"]:
                    errors.append(f"{sid}: PASS is not from target scene/population")
                evidence = run.get("evidence", {})
                if not isinstance(evidence, dict):
                    errors.append(f"{sid}: evidence must be an object")
                    evidence = {}
                for field in scenario["evidence_fields"]:
                    if field not in evidence or missing(evidence[field]):
                        errors.append(f"{sid}: missing evidence {field}")
                check_runtime_receipt(run, args.manifest, contract["required_run_fields"], errors)
            elif not run.get("reason"):
                errors.append(f"{sid}: non-PASS requires reason")
            manifests.append({"scenario_id": sid, "status": run.get("status")})
    print(json.dumps({"check": "manifest_completeness_and_source_anchors_only", "ok": not errors,
                      "gameplay_acceptance": "NOT_EVALUATED", "scenario_count": len(ids),
                      "source_pins": pins, "manifest_statuses": manifests, "errors": errors},
                     ensure_ascii=False, indent=2))
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
