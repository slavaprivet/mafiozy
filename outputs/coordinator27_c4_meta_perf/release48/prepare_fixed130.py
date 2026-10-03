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
PARENT = HERE / "prepare_fixed18.py"
PARENT_SHA = "788cd48ab6b91754b897e7ddfc74e8506bfa0cbc42bbbe724f82a8af0edbcdb0"
def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
assert sha(PARENT) == PARENT_SHA
parent = runpy.run_path(str(PARENT))
need, read, encoded, write_new = (parent[n] for n in ("need", "read", "encoded", "write_new"))
GUARD, GUARD_SHA = parent["GUARD"], parent["GUARD_SHA"]
ENTRY_REL, ENTRY_SHA = parent["ENTRY_REL"], parent["ENTRY_SHA"]
SETTLED_REL = "scripts/destruction/palazzo/test_release48_fixed18_130.gd"
SETTLED_SHA = "d404e82543013b8c9a148a94baab3b92c849b7e9cac1b135c091a39f38c9d6e4"
BASE_ASMS = {"baseline": "1413c294e4acefdde74fbc150a8988c6561eb3b33a469c5ce84dc023679d5619", "candidate": "1cbf9f20aad03f93ba9f2e5d85b7d07e7cb7031af2a1496de9ed102e88655f18"}

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
        m["qa_manifest_argument"] = "--qa-manifest=" + str(asm.with_name("ASSEMBLY_FIXED130.json"))
        m["fixed130_parent_assembly_sha256"] = sha(asm)
        m["fixed130_prepare_sha256"] = sha(Path(__file__))
        m["declared_qa_changes"].append("Identical fixed 18 physics frames after actual Q in both variants; last three must be stable. First hold at native scene/NPC ready +130 physics frames, with late setup rejected. No early exit, runtime change, NPC relocation or freeze.")
        plan["sources"][SETTLED_REL] = source
        plan["manifest"], plan["assembly"] = m, asm.with_name("ASSEMBLY_FIXED130.json")
    return plans

def stage(variant):
    plan = next(p for p in prepare() if p["manifest"]["variant"] == variant)
    game = Path(plan["manifest"]["game"])
    base = parent["parent"]["parent"]
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
