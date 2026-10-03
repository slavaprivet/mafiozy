"""Append one fixed-duration QA entry and new manifests; never overwrite a prior byte."""
from pathlib import Path
import argparse
import copy
import hashlib
import json
import runpy
import sys
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
PARENT = HERE / "prepare_capture.py"
PARENT_SHA = "106d18c19ad740ee78de8986b732834c48a4578eac7233b1002e87c29a2b2690"
def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
assert sha(PARENT) == PARENT_SHA
parent = runpy.run_path(str(PARENT))
need, read, encoded, write_new = (parent[n] for n in ("need", "read", "encoded", "write_new"))
GUARD, GUARD_SHA = parent["GUARD"], parent["GUARD_SHA"]
ENTRY_REL, ENTRY_SHA = parent["ENTRY_REL"], parent["ENTRY_SHA"]
SETTLED_REL = "scripts/destruction/palazzo/test_release48_fixed18.gd"
SETTLED_SHA = "3e9a200cbcf9007a5ca75ca97722b65af5f3f8ab9e6500af450d9060bb610983"
BASE_ASMS = {"baseline": "9eaeb36839e5136b04e5f38de36e25ca8e198612613f3af96c5f277e96364e3f", "candidate": "1d9ba3a511dedd742ae5cc6d400c42c6d6e3272a4cfcc9cbded2a7ccdc6b47d7"}

def prepare():
    need(sha(PARENT) == PARENT_SHA and sha(GUARD) == GUARD_SHA, "Parent/guard drift")
    plans = parent["prepare"]()
    guard = runpy.run_path(str(GUARD))
    for plan in plans:
        asm = Path(plan["assembly"]); old = plan["manifest"]
        need(sha(asm) == BASE_ASMS[old["variant"]] and read(asm) == old, "Preserved QA assembly drift")
        guard["full_pins"](Path(old["game"]), old["source_pins"])
        source = HERE / "qa" / Path(SETTLED_REL).name
        need(sha(source) == SETTLED_SHA, "Fixed18 source drift")
        m = copy.deepcopy(old)
        m["source_pins"][SETTLED_REL] = SETTLED_SHA
        m["qa_pins"][SETTLED_REL] = SETTLED_SHA
        m["source_pins"] = dict(sorted(m["source_pins"].items()))
        m["source_count"] = len(m["source_pins"])
        m["entrypoints"]["settled"] = SETTLED_REL
        m["qa_manifest_argument"] = "--qa-manifest=" + str(asm.with_name("ASSEMBLY_FIXED18.json"))
        m["fixed18_parent_assembly_sha256"] = sha(asm)
        m["fixed18_prepare_sha256"] = sha(Path(__file__))
        m["declared_qa_changes"].append("Identical fixed 18 physics frames after actual Q in both variants; last three must be stable. First hold at native scene/NPC ready +110 physics frames, with late setup rejected. No early exit, runtime change, NPC relocation or freeze.")
        plan["sources"][SETTLED_REL] = source
        plan["manifest"], plan["assembly"] = m, asm.with_name("ASSEMBLY_FIXED18.json")
    return plans

def stage(variant):
    plan = next(p for p in prepare() if p["manifest"]["variant"] == variant)
    game = Path(plan["manifest"]["game"])
    base = parent["parent"]
    need(sha(base["SCHEDULER"]) == base["SCHEDULER_SHA"], "Scheduler drift")
    scheduler = runpy.run_path(str(base["SCHEDULER"]))
    with scheduler["Lease"]("headless", game, "write", wait_seconds=120):
        need(not plan["assembly"].exists() and not (game / SETTLED_REL).exists(), "Preserve previous or partial stage")
        write_new(game / SETTLED_REL, plan["sources"][SETTLED_REL].read_bytes())
        need(next(p for p in prepare() if p["manifest"]["variant"] == variant)["manifest"] == plan["manifest"], "Source drift during stage")
        runpy.run_path(str(GUARD))["full_pins"](game, plan["manifest"]["source_pins"])
        write_new(plan["assembly"], encoded(plan["manifest"]))
    print(json.dumps({"status": "FIXED18_STAGED", "variant": variant, "sha256": sha(plan["assembly"]), "source_count": plan["manifest"]["source_count"]}))

if __name__ == "__main__":
    p = argparse.ArgumentParser(); p.add_argument("--stage", action="store_true"); p.add_argument("--variant", choices=["baseline", "candidate"], default="candidate"); a = p.parse_args()
    if a.stage: stage(a.variant)
    else: print(json.dumps({"status": "SOURCE_CHECK_OK_READ_ONLY", "counts": [p["manifest"]["source_count"] for p in prepare()]}))
