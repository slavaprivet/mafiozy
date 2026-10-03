"""Resolve only the root-approved frozen foundation hash-domain exception in saved fixed18 data."""
from pathlib import Path
import argparse
import hashlib
import json
import math
import runpy

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OWNER = ROOT / "outputs/buildings4_foundation_perf_contract_20261003/native_overlay_r3"
def read(p): return json.loads(p.read_text(encoding="utf-8-sig"))
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def near(a,b): return len(a)==len(b) and all(math.isfinite(x) and abs(x-y)<=1e-5 for x,y in zip(a,b))

parser=argparse.ArgumentParser(); parser.add_argument("--charges",type=int,choices=[1,8],required=True); args=parser.parse_args()
review=OWNER/"NATIVE_REVIEW.json"; comparison=OWNER/"runs/collector_native01/COMPARISON.json"
assert sha(review)=="e485a2e157efdc6632fc2520a1c3160f512efd3f5d011b7baf0d2029d14ec429"
assert sha(comparison)=="bf96fe16f7844ff3a13c937f8ef7c99b72b7df4a36f7e9b55c29d59dca420a0c"
proof=read(review); assert proof["status"]=="NATIVE_COLLECTOR_AND_STRICT_GEOMETRY_PASS" and proof["checks"]==16
native_asm=OWNER/"ASSEMBLY.json"; assert sha(native_asm)==proof["assembly_sha256"]
native=read(native_asm); native_game=Path(native["game"])
assert len(native["source_pins"])==502 and all(sha(native_game/rel)==pin for rel,pin in native["source_pins"].items())
source=HERE/("COMPARISON_FIXED18_"+str(args.charges)+"_RAW.json"); raw=read(source)
reports={}; local={}
for variant, binding in raw["source_bindings"].items():
    run=Path(binding["run"]); assert sha(run/"RESULT.json")==binding["result_sha256"] and sha(run/"RUN.json")==binding["run_sha256"]
    asm=Path(binding["assembly"]); assert sha(asm)==binding["assembly_sha256"]
    local[variant]=read(asm); reports[variant]=read(run/"RESULT.json")["evidence"]
a,b=reports["baseline"],reports["candidate"]
# Independently observed native proof uses exactly these geometry sources.
# The four differences in the Palazzo namespace are declared C4/FX resources,
# outside the cold structural collector's instantiation path.
changed={r for r,pin in native["source_pins"].items() if r.startswith("scripts/destruction/palazzo/") and r in local["candidate"]["source_pins"] and local["candidate"]["source_pins"][r]!=pin}
assert changed=={"scripts/destruction/palazzo/blast45_plume.gdshader","scripts/destruction/palazzo/blast45_wave.gdshader","scripts/destruction/palazzo/blast_fx45.gd","scripts/destruction/palazzo/c4_equipment.gd"}
exact={r:pin for r,pin in native["source_pins"].items() if r.startswith("scripts/destruction/palazzo/") and local["candidate"]["source_pins"].get(r)==pin}
assert len(exact)==44
for rel in ("palazzo_structural_site.gd","palazzo_finished_site.gd","palazzo_live_site.gd","palazzo_access.gd","palazzo_foundation12_site.gd"):
    assert "scripts/destruction/palazzo/"+rel in exact
assert local["candidate"]["source_pins"]["data/palazzo_binding.json"]==native["source_pins"]["data/palazzo_binding.json"]
ar,br=a["authored_geometry"]["rows"],b["authored_geometry"]["rows"]
assert a["authored_geometry"]["site_frame"]==b["authored_geometry"]["site_frame"]
assert len(ar)==687 and len(br)==698 and ar[:657]==br[:657] and ar[657:658]+ar[659:]==br[669:]
assert a["authored_geometry"]["shape_count"]==2099 and b["authored_geometry"]["shape_count"]==2110
old=ar[658]; assert old["class"]=="StaticBody3D" and old["layer"]==old["mask"]==1 and len(old["shapes"])==1
assert near(old["frame"]["origin"],[0,.19,0]) and near(old["shapes"][0]["size"],[8.5,.22,6.5])
identity={"x":[1.,0.,0.],"y":[0.,1.,0.],"z":[0.,0.,1.]}
assert old["frozen"] is True and all(old["frame"][k]==v for k,v in identity.items())
assert old["shapes"][0]["type"]=="BoxShape3D" and old["shapes"][0]["disabled"] is False
assert old["shapes"][0]["frame"]=={"origin":[0.,0.,0.],**identity}
for i,row in enumerate(br[657:669]):
    assert row["class"]=="RigidBody3D" and row["frozen"] is True and row["layer"]==1 and row["mask"]==513
    assert near(row["frame"]["origin"],[-4.25+(i%4+.5)*2.125,.19,-3.25+(i//4+.5)*(6.5/3)])
    assert all(row["frame"][k]==v for k,v in identity.items()) and len(row["shapes"])==1
    shape=row["shapes"][0]; assert shape["type"]=="BoxShape3D" and not shape["disabled"] and near(shape["size"],[2.125,.22,6.5/3])
    assert shape["frame"]=={"origin":[0.,0.,0.],**identity}
statics=a["static_geometry"]["rows"]; assert [r for r in statics if r["path"]!="OriginalFoundation"]==b["static_geometry"]["rows"]
assert len([r for r in statics if r["path"]=="OriginalFoundation"])==1
static_old=next(r for r in statics if r["path"]=="OriginalFoundation")
assert static_old["frame"]==old["frame"] and static_old["layer"]==old["layer"] and static_old["mask"]==old["mask"]
assert static_old["shapes"]==[{"class":s["type"],"frame":s["frame"],"disabled":s["disabled"],"size":s["size"]} for s in old["shapes"]]
known={"baseline":"c9ed8a0177adf1ac4f743cb8fa68c11823e7e22d31b0a524dc75f40d942df91d","candidate":"181cc044c3c7057dbc93e867f3e1c03cb9e24f81d9b7f575d805b8f346243456"}
for variant,e in reports.items():
    for phase in ("pre_hold_physics","pre_blast_physics"):
        state=e[phase]; assert state["frozen_sha256"]==known[variant] and state["released_indices"]==[96] and state["dynamic"]==1 and state["awake"]==0
        assert state["support"]["generation"]==0 and not state["support"]["busy"]
        if variant=="candidate":
            f=state["native_stats"]["foundation"]; assert (f["chunks"],f["intact"],f["detached"],f["invalid"],f["generation"])==(12,12,0,0,0)
assert a["scene_ready_anchor48"]["population"]==b["scene_ready_anchor48"]["population"]
allowed={"authored_geometry mismatch","static_geometry mismatch","pre_hold_physics: frozen_sha256 mismatch","pre_blast_physics: frozen_sha256 mismatch"}
remaining=[x for x in raw["failures"] if x not in allowed]
out={"status":"COMPARABLE_WITH_DECLARED_FOUNDATION_DELTA" if not remaining else "NOT_COMPARABLE","failures":remaining,"resolved_exceptions":sorted(set(raw["failures"])&allowed),"raw_comparison":str(source),"raw_sha256":sha(source),"native_geometry_proof":str(review),"native_geometry_proof_sha256":sha(review),"exact_geometry_namespace_pins":exact,"source_differences_outside_cold_geometry":sorted(changed),"scoped_hash_exception":"Exact known baseline/candidate domains only; each unchanged from pre-hold through pre-blast, same released LobbyTable index96, and all original657 authored bodies plus remaining statics are identical. Native owner proof confirms689 nonfoundation physical/visual records and declared1static-to12rigid replacement. Raw frozen row arrays were not recorded; this is the explicitly approved source-linked exception, not a recomputed nonfoundation phase hash.","performance_accepted":False}
with (HERE/("COMPARISON_FIXED18_"+str(args.charges)+"_RESOLVED.json")).open("x",encoding="utf-8") as stream: json.dump(out,stream,ensure_ascii=False,indent=2);stream.write("\n")
print(json.dumps({"status":out["status"],"failures":remaining}))
