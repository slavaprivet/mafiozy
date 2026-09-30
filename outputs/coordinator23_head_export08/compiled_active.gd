extends "../coordinator23_head_merge07/active_head_followup.gd"
const EXPORT_PROOF_PATH="C:/Users/Слава/Desktop/Мафиози/outputs/coordinator23_head_export08/EXPORT_PROOF.json"

func run() -> void:
	var proof: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(EXPORT_PROOF_PATH))
	var ok: bool=FileAccess.get_sha256(proof.pck_path)==proof.pck_sha256
	var checks_done:=0
	for path: String in proof.compiled_subjects:
		var entry: Dictionary=proof.compiled_subjects[path]
		var script: Script=load(path)
		ok=ok and script!=null and not script.has_source_code()
		ok=ok and FileAccess.get_sha256(entry.compiled_path)==entry.compiled_sha256
		checks_done+=1
	var notes: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/preview_updates.json"))
	ok=ok and notes.get("runtime_revision")==proof.runtime_revision
	print("COMPILED_HEAD_BINDING ",JSON.stringify({"ok":ok,"compiled_subjects":checks_done,"pck_sha256":proof.pck_sha256,"revision":notes.get("runtime_revision"),"source_scripts_allowed":false}))
	if not ok:
		quit(2);return
	await super.run()
