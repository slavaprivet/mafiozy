extends SceneTree
var checks: Array = []
var output := ""

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--medical-output="): output=argument.trim_prefix("--medical-output=")
	var pack := get_script().resource_path.get_base_dir().path_join("overlay58.zip")
	if not ProjectSettings.load_resource_pack(pack, true): quit(2); return
	run.call_deferred()

func check(value: bool, name: String) -> void:
	checks.append({"name":name,"ok":value})

func run() -> void:
	var daily_script: Script=load("res://scripts/npc_daily_life.gd")
	var catalog: Script=load("res://scripts/npc_needs_catalog.gd")
	var life: RefCounted=daily_script.new()
	for sample: Dictionary in [
		{"hp":30.0,"max_hp":60.0,"wanted":true},
		{"hp":31.0,"max_hp":60.0,"wanted":false},
		{"hp":29.0,"max_hp":60.0,"wanted":true},
		{"hp":50.0,"max_hp":100.0,"wanted":true},
		{"hp":51.0,"max_hp":100.0,"wanted":false},
		{"hp":60.0,"max_hp":60.0,"wanted":false},
		{"hp":0.0,"max_hp":60.0,"wanted":false},
		{"hp":-1.0,"max_hp":60.0,"wanted":false},
		{"hp":30.0,"max_hp":0.0,"wanted":false},
		{"hp":30.0,"max_hp":60.0,"dead":true,"wanted":false},
		{"hp":30.0,"max_hp":60.0,"_medicalDowned":true,"wanted":false},
		{"hp":30.0,"max_hp":60.0,"_forcedCrawl":true,"wanted":false}
	]:
		var before: Dictionary=sample.duplicate(true)
		check(life._needs_hospital(sample)==sample.wanted, "daily "+str(before))
		check(life._hospital51_below_threshold(sample)==sample.wanted,"hit/home/restaurant priority "+str(before))
		check(catalog._matches(catalog.find("hospital").condition,sample,10.0,true)==sample.wanted,"catalog "+str(before))
		check(sample==before,"policy preserves current health row "+str(before))
	check(catalog.ids(catalog.order({"hp":30.0,"max_hp":60.0},10.0,true))==["hospital","restaurant"],"half-health precedes hunger")
	life._next_medical=1000.0
	check(not life._needs_hospital({"hp":30.0,"max_hp":60.0}),"existing medical retry cooldown retained")
	check(life._hospital51_below_threshold({"hp":30.0,"max_hp":60.0}),"cooldown cannot yield urgent priority to food")
	check(not catalog.health_at_or_below({"max_hp":60.0},NAN,.5),"non-finite health rejected")
	var passed: bool=checks.all(func(row: Dictionary)->bool:return row.ok)
	var result: Dictionary={"passed":passed,"checks":checks,"scope":"native decision boundary and priority; physical shot/hospital cycle still pending"}
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	life=null
	quit(0 if passed else 1)
