@tool
extends EditorPlugin

const ReceiptExport = preload("res://addons/npc_source_receipts/export_plugin.gd")
var _exporter: EditorExportPlugin

func _enter_tree() -> void:
	_exporter = ReceiptExport.new()
	add_export_plugin(_exporter)

func _exit_tree() -> void:
	if _exporter != null:
		remove_export_plugin(_exporter)
		_exporter = null
