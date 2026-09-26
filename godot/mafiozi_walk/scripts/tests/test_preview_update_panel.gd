extends SceneTree
const NotesPanel = preload("res://scripts/preview_update_panel.gd")
var checks := 0
var failures: Array[String] = []
var path := ""
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("FAIL ", label)
func write(text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
func note(title: String, revision: String = "run-a") -> String:
	return JSON.stringify({"title":title,"items":["Проверенная возможность"],"runtime_revision":revision,"updated_at":"2026-09-27"})
func run() -> void:
	path = "user://update_panel_test_%s.json" % str(OS.get_process_id())
	var panel := NotesPanel.new()
	root.add_child(panel)
	write(note("Первая версия"))
	panel.setup(path,"run-a")
	check(panel.get_status().notes.title=="Первая версия" and panel.visible,"initial valid notes shown")
	check(panel.size.x==350 and panel.offset_right==-24 and panel.offset_top==24,"350px top-right layout")
	check(panel._items[0].text=="1. Проверенная возможность" and panel.mouse_filter==Control.MOUSE_FILTER_IGNORE,"numbered plain text with input passthrough")
	check(not panel.is_processing() and panel._timer.wait_time==2.0 and panel._timer.ignore_time_scale and panel._timer.process_mode==Node.PROCESS_MODE_ALWAYS,"timer only, unscaled every2s while paused")
	var reads:int=panel.get_status().read_count
	for i in range(20):panel._poll_file()
	check(panel.get_status().read_count==reads,"unchanged file uses stats without content reads")
	write(note("Обновление текста той же игры"))
	panel._poll_file()
	check(panel.get_status().notes.title=="Обновление текста той же игры","same revision content hot refresh")
	var valid:Dictionary=panel.get_status().notes
	write('{"title":')
	panel._poll_file()
	check(panel.get_status().notes==valid,"partial JSON keeps last valid silently")
	reads=panel.get_status().read_count
	panel._poll_file()
	check(panel.get_status().read_count==reads,"unchanged malformed file is not reparsed")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	panel._poll_file()
	check(panel.get_status().notes==valid,"missing file keeps last valid")
	write(note("Восстановленный файл"))
	panel._poll_file()
	check(panel.get_status().notes.title=="Восстановленный файл","restore after missing is read")
	valid=panel.get_status().notes
	write(note("Ещё не загруженная новая механика","run-b"))
	panel._poll_file()
	check(panel.get_status().notes==valid and panel.get_status().restart_required and panel._notice.visible,"mismatched revision keeps old notes and requests restart")
	var fresh := NotesPanel.new()
	root.add_child(fresh)
	fresh.setup(path,"run-a")
	check(fresh.get_status().notes.is_empty() and fresh._notice.visible and not fresh._title.visible and not fresh._items[0].visible,"initial mismatch advertises no unloaded features")
	fresh.free()
	write(note("Версия снова совпадает"))
	panel._poll_file()
	check(panel.get_status().notes.title=="Версия снова совпадает" and not panel.get_status().restart_required,"current revision clears restart notice")
	valid=panel.get_status().notes
	write(JSON.stringify({"title":"Bad schema","items":[123]}))
	panel._poll_file()
	check(panel.get_status().notes==valid,"invalid schema cannot replace valid notes")
	reads=panel.get_status().read_count
	write("x".repeat(NotesPanel.MAX_BYTES+1))
	panel._poll_file()
	check(panel.get_status().read_count==reads and panel.get_status().notes==valid,"oversize is rejected before any content read")
	write(JSON.stringify({"title":"T".repeat(120),"items":["A".repeat(300),"2","3","4","5","6"]}))
	panel._poll_file()
	check(panel.get_status().notes.title.length()==80 and panel.get_status().notes.items.size()==5 and panel.get_status().notes.items[0].length()==240,"bounded title/items and optional revision supported")
	# Real timer, not a manually emitted timeout, with both pause and timescale.
	write(note("Обновилось во время паузы"))
	paused=true
	Engine.time_scale=.01
	await create_timer(2.15,true,false,true).timeout
	Engine.time_scale=1.0
	paused=false
	check(panel.get_status().notes.title=="Обновилось во время паузы","actual unscaled timer refreshes while scene tree paused")
	# Real mtime-only change: use equal-length JSON across a timestamp boundary.
	write(note("AA"))
	panel._poll_file()
	var first_size:=FileAccess.get_size(path)
	await create_timer(1.1,true,false,true).timeout
	write(note("BB"))
	panel._poll_file()
	check(FileAccess.get_size(path)==first_size and panel.get_status().notes.title=="BB","mtime change refreshes even with identical byte length")
	# PCK is a tiny local test fixture, not an exported game or renderer launch.
	var pack_path:=path.trim_suffix(".json")+".pck"
	var packed_path:="res://__preview_notes_pack_%s.json" % str(OS.get_process_id())
	var pack:=PCKPacker.new()
	check(pack.pck_start(ProjectSettings.globalize_path(pack_path))==OK and pack.add_file(packed_path,path)==OK and pack.flush()==OK,"create bounded packed-resource fixture")
	check(ProjectSettings.load_resource_pack(pack_path),"load test pack in editor binary")
	var packed_panel:=NotesPanel.new()
	root.add_child(packed_panel)
	packed_panel.setup(packed_path,"run-a")
	check(packed_panel.get_status().notes.title=="BB" and not packed_panel.get_status().polling and packed_panel._timer.is_stopped(),"actual packed res loads once then disables poll in editor binary")
	packed_panel.free()
	panel.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(pack_path))
	print("PREVIEW_UPDATE_PANEL ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"features":{"editor":OS.has_feature("editor"),"template":OS.has_feature("template"),"standalone":OS.has_feature("standalone")},"live":false}))
	quit(0 if failures.is_empty() else 1)
