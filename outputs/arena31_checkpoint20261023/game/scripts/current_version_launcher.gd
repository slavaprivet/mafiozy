extends Node
## F5 and Project Manager Run resolve the same verified release as the shortcut.
func _ready() -> void:
	# Exported games are self-contained; forwarding is only for local editor runs.
	if not OS.has_feature("editor"):
		get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
		return
	var repo := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var launcher := repo.path_join("tools/godot/launch_current_game.ps1")
	var shell := OS.get_environment("USERPROFILE").path_join(".cache/codex-runtimes/codex-primary-runtime/dependencies/native/powershell/pwsh.exe")
	if not FileAccess.file_exists(launcher) or not FileAccess.file_exists(shell):
		OS.alert("Не найден запуск актуальной версии. Откройте ярлык «Мафиози — актуальная версия».", "Мафиози")
		get_tree().quit(1)
		return
	var pid := OS.create_process(shell, PackedStringArray(["-NoProfile", "-WindowStyle", "Hidden", "-File", launcher, "-FromGodotPid", str(OS.get_process_id())]), false)
	if pid < 0:
		OS.alert("Не удалось запустить актуальную версию.", "Мафиози")
	get_tree().quit(0 if pid >= 0 else 1)
