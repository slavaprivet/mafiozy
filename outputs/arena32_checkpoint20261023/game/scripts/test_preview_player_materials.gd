extends SceneTree
## Actual imported material/geometry regression; no graphics window required.

const PlayerController = preload("res://scripts/preview_player.gd")
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://assets/hero.glb") as PackedScene
	var source: Node3D = scene.instantiate() as Node3D
	root.add_child(source)
	var source_meshes: Dictionary = {}
	var original_flags: Dictionary = {}
	for node: Node in source.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		source_meshes[str(mesh.name)] = mesh
		var material: BaseMaterial3D = mesh.get_active_material(0) as BaseMaterial3D
		original_flags[material.get_instance_id()] = material.vertex_color_use_as_albedo
	var player: PlayerController = PlayerController.new()
	root.add_child(player)
	var color_count: int = 0
	var material_copies: Dictionary = {}
	var mappings: Array[Dictionary] = []
	for node: Node in player.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = node as MeshInstance3D
		var original_instance: MeshInstance3D = source_meshes.get(str(instance.name)) as MeshInstance3D
		_check(original_instance != null, "authored mesh identity " + str(instance.name))
		if original_instance == null:
			continue
		_check(instance.mesh == original_instance.mesh, "source geometry/skin resource unchanged " + str(instance.name))
		for surface: int in range(instance.mesh.get_surface_count()):
			var material: BaseMaterial3D = instance.get_active_material(surface) as BaseMaterial3D
			var original: BaseMaterial3D = original_instance.get_active_material(surface) as BaseMaterial3D
			_check(material != original and material.resource_name == original.resource_name,
				"owned material copy retains semantic name " + original.resource_name)
			_check(material.vertex_color_use_as_albedo and not material.vertex_color_is_srgb,
				"linear COLOR_0 enabled " + original.resource_name)
			_check(material.albedo_color == original.albedo_color and material.roughness == original.roughness
				and material.metallic == original.metallic and material.cull_mode == original.cull_mode
				and material.transparency == original.transparency and material.albedo_texture == original.albedo_texture,
				"authored PBR/alpha/culling unchanged " + original.resource_name)
			_check(original.vertex_color_use_as_albedo == bool(original_flags[original.get_instance_id()]),
				"shared imported material unmodified " + original.resource_name)
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			_check(colors.size() == vertices.size() and colors.size() > 0, "authored color stream complete")
			color_count += colors.size()
			material_copies[material.get_instance_id()] = material.resource_name
			mappings.append({"mesh": str(instance.name), "material": material.resource_name,
				"linear_vertex_colors": colors.size(), "roughness": material.roughness, "metallic": material.metallic})
	var status: Dictionary = player.get_preview_status()
	_check(int(status.get("vertex_color_surfaces", 0)) == 7, "all seven source surfaces use COLOR_0")
	_check(material_copies.size() == 4, "four semantic materials share four owned copies")
	_check(color_count == 8338, "all 8338 imported authored colors retained")
	print(JSON.stringify({"passed": _failures.is_empty(), "mapping": mappings,
		"vertex_colors": color_count, "scope": "actual imported materials; animation/render acceptance is separate"}))
	for failure: String in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)


func _check(ok: bool, label: String) -> void:
	if not ok:
		_failures.append(label)
