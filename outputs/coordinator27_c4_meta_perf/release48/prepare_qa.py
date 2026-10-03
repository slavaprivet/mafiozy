"""Exact release48/accepted45 QA copies; default verifies read-only, --stage claims one new copy."""
from pathlib import Path
import argparse
import hashlib
import json
import runpy
import shutil
import sys
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
HELPER=ROOT/"outputs/coordinator27_c4_47/prepare_perf47.py"
HELPER_SHA="32f13d36a406c04e0d4161d54e069fa63b977d136d13358be1f122ebe2b0658c"
SCHEDULER=ROOT/"tools/godot/test_scheduler.py"
SCHEDULER_SHA="6f86204fdb510a9f3d850792891fc9902301ad68b5a67688080d0ac888c3cad9"
GUARD=ROOT/"outputs/coordinator26_marks37_qa/run37.py"
GUARD_SHA="1687441c667d09ce66e4b0a305e9e69171469f1b5cef265596208a5bdbf07cbf"
BASES={"baseline":("outputs/coordinator26_frames45/ASSEMBLY.json","f797214092875a9e91cd47aa30cf751b99909f089d9b3b6bb8f4be34c6336b21",473),
       "candidate":("outputs/coordinator27_release48/ASSEMBLY.json","513c9165b7f00be7e6cb8967470a5513e4d37e8fd8642f528d29ec36c08dd83c",486)}
PREFIX="scripts/destruction/palazzo/"
QA={
 "test_c4.gd":(ROOT/"outputs/coordinator26_c4_47/qa/perf_commonwall47/patch"/PREFIX/"test_c4.gd","12db538fe15d4419b72a62fc3868b8840dd2621a03159305c4ed244e60831b34"),
 "test_c4_input_perf45.gd":(HERE/"qa/test_c4_input_perf45.gd","1af003f7e14288f0a2ece0d3819987218c9fe2c991ad044060346893d41d1df3"),
 "c4_perf_observer45.gd":(HERE/"qa/c4_perf_observer45.gd","77722c376d5dc0e0aaf217039813fd0cad5cf7a57786e3f391e7e538f6716c01"),
 "test_c4_input_diag8_focus.gd":(HERE.parent/"input_diagnostic8_focus/qa/test_c4_input_diag8_focus.gd","291d50ece91b37c428379a1e0720ea31b9ba62435ef1e8c8467b9015e7de5166"),
 "test_c4_input_diag8_settle.gd":(HERE.parent/"input_diagnostic8_settle/qa/test_c4_input_diag8_settle.gd","8bb14ee4ffce75a6b128720bdd76053bf6df8980c77f942c046d3c65a73905f6")}
ENTRY_REL=PREFIX+"test_c4_input_diag8_focus.gd"
ENTRY_SHA=QA["test_c4_input_diag8_focus.gd"][1]
SETTLED_REL=PREFIX+"test_c4_input_diag8_settle.gd"
SETTLED_SHA=QA["test_c4_input_diag8_settle.gd"][1]

def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def need(ok,message):
    if not ok: raise RuntimeError(message)
def read(path): return json.loads(Path(path).read_text(encoding="utf-8-sig"))
def encoded(value): return (json.dumps(value,ensure_ascii=False,indent=2)+"\n").encode("utf-8")
def write_new(path,data):
    with Path(path).open("xb") as stream: stream.write(data)

def prepare():
    need(sha(HELPER)==HELPER_SHA and sha(GUARD)==GUARD_SHA and sha(SCHEDULER)==SCHEDULER_SHA,"Helper/scheduler drift")
    need(sha(HERE/"METADATA.json")=="89a88fb6f857a275fa3ca716579f42d82a15595c0dda53ce17618241c3cc35cc","Metadata snapshot drift")
    helper=runpy.run_path(str(HELPER)); metadata=read(HERE/"METADATA.json"); plans=[]
    for variant,(relative,pin,count) in BASES.items():
        base_path=ROOT/relative; need(sha(base_path)==pin,"Frozen production assembly drift")
        base=read(base_path); source=Path(base["game"]); runtime=base["source_pins"]
        need(base["source_count"]==len(runtime)==count,"Wrong runtime count")
        if variant=="baseline": need(base["accepted"] is True,"Accepted45 baseline required")
        inputs=dict(runtime,**metadata[variant]); helper["verify"](source,inputs)
        sources={rel:helper["child"](source,rel) for rel in inputs}; qa_pins={}
        for name,(path,digest) in QA.items():
            need(sha(path)==digest and PREFIX+name not in inputs,"QA drift or runtime overwrite")
            sources[PREFIX+name]=path; qa_pins[PREFIX+name]=digest
        label="baseline45" if variant=="baseline" else "candidate48"
        assembly=HERE/label/"ASSEMBLY.json"; game=assembly.parent/"game"
        pins=dict(sorted(dict(inputs,**qa_pins).items()))
        m={"schema":"coordinator27_release48_fullscene_qa/v1","revision":base["revision"],"variant":variant,"game":str(game),
           "source_count":len(pins),"source_pins":pins,"runtime_source_count":count,"runtime_source_pins":runtime,
           "source_metadata_pins":metadata[variant],"qa_pins":qa_pins,"base_assembly":str(base_path),"base_assembly_sha256":pin,
           "entry":"res://"+ENTRY_REL,"entrypoints":{"fast":ENTRY_REL,"settled":SETTLED_REL},"qa_manifest_argument":"--qa-manifest="+str(assembly),
           "charge_cases":[1,8],"diagnostic_only":True,"accepted":False,"performance_accepted":False,"import_cache":"NOT_COPIED",
           "declared_qa_changes":["candidate expected damage1920/direct48; baseline480/direct12 unchanged","readonly authored rows alongside unchanged geometry hash"],
           "declared_geometry_delta":"Only foundation12 replacement:12 rigid instead of1 static; old bevel44 to boxes144 authored triangles. No other mismatch automatically accepted.",
           "prepare_script_sha256":sha(Path(__file__)),"scheduler_sha256":SCHEDULER_SHA}
        need(len(pins)==(479 if variant=="baseline" else 491),"Wrong full closure")
        plans.append({"source":source,"sources":sources,"manifest":m,"assembly":assembly})
    return plans

def stage(variant):
    plan=next(p for p in prepare() if p["manifest"]["variant"]==variant); game=Path(plan["manifest"]["game"])
    scheduler=runpy.run_path(str(SCHEDULER)); helper=runpy.run_path(str(HELPER))
    with scheduler["Lease"]("headless",game,"write",wait_seconds=120):
        need(not game.parent.exists() and game.resolve().is_relative_to(HERE.resolve()),"No overwrite; partial stage preserved")
        game.mkdir(parents=True)
        for rel,source in sorted(plan["sources"].items()):
            target=helper["child"](game,rel); target.parent.mkdir(parents=True,exist_ok=True)
            with source.open("rb") as origin,target.open("xb") as destination: shutil.copyfileobj(origin,destination)
        need(next(p for p in prepare() if p["manifest"]["variant"]==variant)["manifest"]==plan["manifest"],"Input drift during copy")
        helper["verify"](game,plan["manifest"]["source_pins"])
        need({p.relative_to(game).as_posix() for p in game.rglob("*") if p.is_file()}==set(plan["manifest"]["source_pins"]),"Unexpected stage files")
        write_new(plan["assembly"],encoded(plan["manifest"]))
    print(json.dumps({"status":"STAGED_NOT_IMPORTED","assembly":str(plan["assembly"]),"sha256":sha(plan["assembly"]),"source_count":plan["manifest"]["source_count"]}))

if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument("--stage",action="store_true"); parser.add_argument("--variant",choices=BASES,default="candidate"); args=parser.parse_args()
    if args.stage: stage(args.variant)
    else: print(json.dumps({"status":"SOURCE_CHECK_OK_READ_ONLY","plans":[{"variant":p["manifest"]["variant"],"source_count":p["manifest"]["source_count"]} for p in prepare()]}))
