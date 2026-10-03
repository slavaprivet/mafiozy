extends "test_c4_input_diag8_settle.gd"
## Same ready-hook adaptation; inherited post-Q settle is unchanged for perf pairs.
func observe_site45(node: Node) -> void:
	var script: Script=node.get_script() as Script
	if script!=null and script.resource_path in ["res://scripts/destruction/palazzo/palazzo_structural_site.gd","res://scripts/destruction/palazzo/palazzo_foundation12_site.gd"]:
		node.ready.connect(capture_site45.bind(node),CONNECT_ONE_SHOT)
