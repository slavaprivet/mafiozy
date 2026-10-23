extends SceneTree
var out:String
func _initialize():
 for a:String in OS.get_cmdline_user_args():
  if a.begins_with("--qa-out="):out=a.trim_prefix("--qa-out=")
 run.call_deferred()
func run():
 var cap:RefCounted=load("D:/MafioziCombat31/c33_coordination/agents/perf_review33/query_capture33.gd").new()
 cap.load_capture("D:/MafioziCombat31/c33_coordination/agents/perf_review33/query_snapshot03/CAPTURE.bin")
 var rows:Array=[];var mismatches:=0
 for repeat in 12:
  for mode:String in (["baseline","stack","inline","combined"] if repeat%2==0 else ["combined","inline","stack","baseline"]):
   for warm:bool in [false,true]:
    var trees:Array=[];var pose_usec:=0
    for snap:Dictionary in cap.snapshots:
     var script_path:String="res://scripts/combat/contact_mixed_bvh31.gd"
     if mode=="precomputed":script_path="res://scripts/combat/contact_mixed_worldbind33.gd"
     if mode in ["inline","combined"]:script_path="D:/MafioziCombat31/c33_coordination/agents/perf_review33/mixed_"+mode+"33.gd"
     if mode=="stack":script_path="D:/MafioziCombat31/c33_coordination/agents/perf_review33/mixed_stack33.gd"
     if mode=="profile":script_path="D:/MafioziCombat31/c33_coordination/agents/perf_review33/mixed_profile33.gd"
     var loaded:Script=load(script_path)
     if loaded==null or not loaded.can_instantiate():
      quit(2);return
     var tree:RefCounted=loaded.new()
     for field:String in cap.FIELDS:tree.set(field,snap.prototype.get(field))
     tree._allocate_pose()
     var begun:int=Time.get_ticks_usec();tree.set_pose(snap.binds,snap.frame);pose_usec+=Time.get_ticks_usec()-begun
     trees.append(tree)
    if warm:
     for q:Dictionary in cap.queries:trees[q.snapshot].intersections(q.from,q.to)
    if mode=="profile":
     for tree:RefCounted in trees:
      for field:String in ["qa_bounds_calls","qa_bounds_misses","qa_bounds_usec","qa_leaf_calls","qa_leaf_misses","qa_leaf_usec","qa_exact_usec"]:tree.set(field,0)
    var elapsed:=0;var hits_count:=0
    for q:Dictionary in cap.queries:
     var begun:int=Time.get_ticks_usec();var hits:Array=trees[q.snapshot].intersections(q.from,q.to);elapsed+=Time.get_ticks_usec()-begun
     hits_count+=hits.size()
     if hits!=q.expected:mismatches+=1
    var profile:Dictionary={}
    if mode=="profile":
     for field:String in ["qa_bounds_calls","qa_bounds_misses","qa_bounds_usec","qa_leaf_calls","qa_leaf_misses","qa_leaf_usec","qa_exact_usec"]:
      profile[field]=0
      for tree:RefCounted in trees:profile[field]+=int(tree.get(field))
    rows.append({"repeat":repeat,"mode":mode,"warm":warm,"query_usec":elapsed,"pose_usec":pose_usec,"hits":hits_count,"profile":profile})
 var checks:Dictionary={"nonempty_actual_capture":cap.queries.size()>0,"same_exact_results":mismatches==0}
 FileAccess.open(out+"/RESULT.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":mismatches==0,"checks":checks,"queries":cap.queries.size(),"snapshots":cap.snapshots.size(),"mismatches":mismatches,"rows":rows},"  "))
 quit(0 if mismatches==0 else 1)
