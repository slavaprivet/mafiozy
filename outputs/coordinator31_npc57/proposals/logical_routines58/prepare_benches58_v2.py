from pathlib import Path
HERE=Path(__file__).resolve().parent
source=(HERE/'observer_benches58.gd').read_text(encoding='utf-8')
source=source.replace('life._roam51.snapshot() if life._roam51_active else {}','{"phase":life._roam51.phase(),"target":life._roam51.target(),"distance":life._roam51.distance_m(),"attempts":life._roam51.attempts(),"reason":life._roam51.last_reason(),"watch":life._roam51.roam_watch_state29()} if life._roam51_active else {}')
source=source.replace('row.bench_pose=true','row.bench_pose=true;row["seated_bench_path"]=str(life._ambient29._seat.get("bench_path",""));row["pose_frames"]=ambient.pose_frames;row["bench_slot"]=ambient.bench_slot;row["seated_position"]=body.global_position')
source=source.replace('str(row.get("bench_path","")).ends_with("OriginalBenchHome58")','str(row.get("seated_bench_path","")).ends_with("OriginalBenchHome58")')
for filename,content in [('observer_benches58_v2.gd',source),('entry_benches58_v2.gd',(HERE/'entry_benches58.gd').read_text(encoding='utf-8').replace('observer_benches58.gd','observer_benches58_v2.gd').replace('NEW_BENCH_RESOURCES58.zip','NEW_BENCH_RESOURCES58_V2.zip'))]:
    target=HERE/filename;assert not target.exists();target.write_text(content,encoding='utf-8')
runner=(HERE/'run_benches58.py').read_text(encoding='utf-8').replace('prepare_benches58.py','prepare_benches58_v2.py').replace('entry_benches58.gd','entry_benches58_v2.gd').replace('observer_benches58.gd','observer_benches58_v2.gd').replace('NEW_BENCH_RESOURCES58.zip','NEW_BENCH_RESOURCES58_V2.zip')
runner=runner.replace("report={'passed':result.returncode==0", "stderr=(run/'stderr.log').read_text(encoding='utf-8-sig',errors='replace') if (run/'stderr.log').exists() else ''\nengine_clean=not any(marker in stderr for marker in ['SCRIPT ERROR:','ERROR:','Parse Error:'])\nreport={'passed':engine_clean and result.returncode==0")
runner=runner.replace("'checks':native.get('checks',{}),","'checks':native.get('checks',{}),'engine_clean':engine_clean,")
target=HERE/'run_benches58_v2.py';assert not target.exists();target.write_text(runner,encoding='utf-8')
