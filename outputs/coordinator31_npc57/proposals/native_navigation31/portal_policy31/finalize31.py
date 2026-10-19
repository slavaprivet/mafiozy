from pathlib import Path
import hashlib
import json

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[4]
BASE=ROOT/"outputs/coordinator31_release57/game"
def read(path):return json.loads(path.read_text(encoding="utf-8-sig"))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    paths={name:HERE/"runs"/(name+"02") for name in ["candidate","baseline"]}
    runs={name:read(path/"RUN.json") for name,path in paths.items()}
    native={name:read(path/"NATIVE.json") for name,path in paths.items()}
    assert all(row["execution_clean"] for row in runs.values())
    assert runs["candidate"]["passed"] and not runs["baseline"]["passed"]
    assert read(paths["candidate"]/"HARNESS.json")==read(paths["baseline"]/"HARNESS.json")
    assert read(paths["candidate"]/"SOURCE.json")==read(paths["baseline"]/"SOURCE.json")
    pins=read(HERE/"PATCH.json")
    for rel,item in pins.items():
        assert sha(BASE/rel)==item["base_sha256"]
        assert sha(HERE/"patch"/rel)==item["candidate_sha256"]
    report={"status":"SCOPED_NATIVE_PASS_NOT_INTEGRATED","patch":pins,"matched_source":True,"matched_harness":True,
      "candidate":{"checks":len(native["candidate"]["checks"]),"passed":True,"elapsed_s":native["candidate"]["elapsed_s"],"wall_s":native["candidate"]["wall_s"],"portal_owners":native["candidate"]["max_owners"],"actual_opposed_separation_m":native["candidate"]["min_opposed_separation_m"],"max_native_step_m":native["candidate"]["max_native_step_m"]},
      "baseline":{"expected_failure":True,"elapsed_s":native["baseline"]["elapsed_s"],"portal_owners":native["baseline"]["max_owners"],"completed":native["baseline"]["done"],"failed_checks":[k for k,v in native["baseline"]["checks"].items() if not v]},
      "receipts":{name:{"path":str(path),"run_sha256":sha(path/"RUN.json"),"native_sha256":sha(path/"NATIVE.json"),"harness_zip_sha256":sha(path/"HARNESS.zip")} for name,path in paths.items()},
      "unchanged_authorities":["room capacity and lease identity","staff FIFO and service owner","payment/HP transactions","native floor/capsule/debris checks","world/player/door collisions","physical-exit claim release","restaurant visit source"],
      "limitations":["Whole-city integration/long soak and FPS not run","Does not fix roaming NPC blocking actual door leaf arc; separate QA owner","Existing passage boundary and32-member overflow limitations retained","RVO prototype is separately rejected after crossing10 failure"]}
    (HERE/"ACCEPTANCE.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(report["candidate"]))
if __name__=="__main__":main()
