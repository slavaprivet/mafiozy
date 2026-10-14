extends RefCounted
## Read-only receipt for the actual preview water generation.
## A disposed but still referenced WaterSurface is a fault, not absent water.
const Surface = preload("res://scripts/preview_water_surface.gd")
const MaterialFactory = preload("res://scripts/preview_water_material.gd")

static func snapshot(main: Node3D) -> Dictionary:
	if not is_instance_valid(main) or main.is_queued_for_deletion():
		return {"ok":false,"reason":"main_gone"}
	var host: Variant = main._water_host
	if host == null:
		if main.water_status == "detail_ready":
			return {"ok":false,"reason":"ready_host_missing"}
		return {"ok":true,"present":false,"status":main.water_status}
	if not is_instance_valid(host) or host.get_script() != Surface:
		return {"ok":false,"reason":"stale_or_foreign_host"}
	if main.water_status != "detail_ready" or not host._built:
		return {"ok":false,"reason":"host_not_built"}
	var factory: Variant = host._factory
	if not is_instance_valid(factory) or factory.get_script() != MaterialFactory or factory._disposed:
		return {"ok":false,"reason":"stale_or_disposed_factory"}
	var instance: Variant = host._instance
	if not is_instance_valid(instance) or instance.is_queued_for_deletion() or instance.get_parent() != main:
		return {"ok":false,"reason":"water_mesh_owner"}
	var mesh: Mesh = instance.mesh
	if not is_instance_valid(mesh) or mesh.get_surface_count() != 1:
		return {"ok":false,"reason":"water_mesh_missing"}
	var material: Material = mesh.surface_get_material(0)
	if not is_instance_valid(material) or not factory._live_materials.has(material):
		return {"ok":false,"reason":"water_material_owner"}
	return {"ok":true,"present":true,"status":main.water_status,"host_id":host.get_instance_id(),"factory_id":factory.get_instance_id(),"instance_id":instance.get_instance_id(),"mesh_id":mesh.get_instance_id(),"material_id":material.get_instance_id(),"time":factory._time}
