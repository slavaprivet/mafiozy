"""Add two new QA bridge files and a new manifest; retain the original QA copy and every old byte."""
from pathlib import Path
import argparse
import copy
import hashlib
import json
import runpy
import sys
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
PARENT=HERE/"prepare_qa.py"
PARENT_SHA="5f96bd69aac4a9691245638bc77c61b8d27fd5b1d7e522d566eda4cd67590a82"
def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
assert sha(PARENT)==PARENT_SHA
parent=runpy.run_path(str(PARENT))
need,read,encoded,write_new=(parent[n] for n in ("need","read","encoded","write_new"))
GUARD,GUARD_SHA=parent["GUARD"],parent["GUARD_SHA"]
ENTRY_REL=parent["PREFIX"]+"test_release48_focus.gd"
ENTRY_SHA="3989dc5fc89bf092621dbfecba742fc3f6b38ce132d7d941e3a1ce8fbfb6f2d4"
SETTLED_REL=parent["PREFIX"]+"test_release48_settled.gd"
SETTLED_SHA="a81d117f1907555ead8e4425be5f3eb6d004fc0ef43f40a2d0ff49d097baa315"
BRIDGES={ENTRY_REL:ENTRY_SHA,SETTLED_REL:SETTLED_SHA}
BASE_ASMS={"baseline":"7cf05381f026d3a1c6f9faefaa9e3c6282cedabc0505399c69f4e39d369700db","candidate":"63d5997e4328c832d037971aa02bef321cb35695e0841756f384fa6863a065fb"}

def prepare():
    need(sha(PARENT)==PARENT_SHA,"Parent changed")
    plans=parent["prepare"](); guard=runpy.run_path(str(GUARD))
    for plan in plans:
        old=plan["manifest"]; asm=Path(plan["assembly"]); variant=old["variant"]
        need(sha(asm)==BASE_ASMS[variant] and read(asm)==old,"Original staged QA changed")
        guard["full_pins"](Path(old["game"]),old["source_pins"])
        m=copy.deepcopy(old); m["source_pins"].update(BRIDGES); m["qa_pins"].update(BRIDGES)
        m["source_pins"]=dict(sorted(m["source_pins"].items())); m["source_count"]=len(m["source_pins"])
        m["entry"]="res://"+ENTRY_REL; m["entrypoints"]={"fast":ENTRY_REL,"settled":SETTLED_REL}
        m["qa_manifest_argument"]="--qa-manifest="+str(asm.with_name("ASSEMBLY_CAPTURE.json"))
        m["parent_qa_assembly_sha256"]=sha(asm); m["capture_prepare_sha256"]=sha(Path(__file__))
        m["declared_qa_changes"].append("exact ready hook additionally recognizes pinned palazzo_foundation12_site.gd")
        for rel,pin in BRIDGES.items():
            source=HERE/"qa"/Path(rel).name; need(sha(source)==pin,"Capture bridge changed")
            plan["sources"][rel]=source
        plan["manifest"],plan["assembly"]=m,asm.with_name("ASSEMBLY_CAPTURE.json")
    return plans

def stage(variant):
    plan=next(p for p in prepare() if p["manifest"]["variant"]==variant); game=Path(plan["manifest"]["game"])
    scheduler=runpy.run_path(str(parent["SCHEDULER"]))
    with scheduler["Lease"]("headless",game,"write",wait_seconds=120):
        need(not plan["assembly"].exists() and all(not (game/rel).exists() for rel in BRIDGES),"Preserve prior bridge/partial stage")
        for rel in BRIDGES: write_new(game/rel,plan["sources"][rel].read_bytes())
        need(next(p for p in prepare() if p["manifest"]["variant"]==variant)["manifest"]==plan["manifest"],"Source drift")
        runpy.run_path(str(GUARD))["full_pins"](game,plan["manifest"]["source_pins"])
        write_new(plan["assembly"],encoded(plan["manifest"]))
    print(json.dumps({"status":"QA_BRIDGES_STAGED","variant":variant,"sha256":sha(plan["assembly"]),"source_count":plan["manifest"]["source_count"]}))

if __name__=="__main__":
    p=argparse.ArgumentParser(); p.add_argument("--stage",action="store_true"); p.add_argument("--variant",choices=["baseline","candidate"],default="candidate"); a=p.parse_args()
    if a.stage: stage(a.variant)
    else: print(json.dumps({"status":"SOURCE_CHECK_OK_READ_ONLY","counts":[p["manifest"]["source_count"] for p in prepare()]}))
