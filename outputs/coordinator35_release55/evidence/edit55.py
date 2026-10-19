from pathlib import Path
import sys
R=Path('C:/Users/Слава/Desktop/Мафиози');O=Path(__file__).parent;G=O/'game'
sys.path.insert(0,str(R/'tools/godot'));from test_scheduler import Lease
p=G/'scripts/city/castle_site.gd';text=p.read_text(encoding='utf-8')
def swap(old,new):
    global text
    assert old in text,old[:100]
    text=text.replace(old,new,1)
swap('var _ground: StaticBody3D','''# Exact surviving masonry replaces coarse collision only around actual damage.
var _masonry_shapes55: Dictionary = {}
var _masonry_bodies55: Dictionary = {}
var _masonry_changed55: Dictionary = {}
var _ground: StaticBody3D''')
swap('\t_flush_buckets()','\t_flush_buckets()\n\t_build_masonry_hits55()')
# Previously permanent dressing now belongs to the same destructible cells.
start=text.index('\t\t\t\tvar sill_x := MeshInstance3D.new()');end=text.index('\n\t\t\t\tvar at_z :=',start)
text=text[:start]+'''\t\t\t\t_add_brick(at_x + Vector3(side * 0.12, -1.3, 0.0),
\t\t\t\t\tVector3(0.5, 0.18, 1.5), "stone", Vector3.ZERO, "keep_sill55")'''+text[end:]
start=text.index('\t\t\t\tvar sill_z := MeshInstance3D.new()');end=text.index('\n\t# Buttresses',start)
text=text[:start]+'''\t\t\t\t_add_brick(at_z + Vector3(0.0, -1.3, side * 0.12),
\t\t\t\t\tVector3(1.5, 0.18, 0.5), "stone", Vector3.ZERO, "keep_sill55")'''+text[end:]
start=text.index('\t\tfor i: int in 4:\n\t\t\tvar corbel :=');end=text.index('\n\tvar arch_rows',start)
text=text[:start]+'''\t\tfor i: int in 4:
\t\t\t_add_brick(tower_centre + Vector3(-tower_per_course * BRICK.x * 0.36
\t\t\t\t+ float(i) * tower_per_course * BRICK.x * 0.24, 19.4, 0.0),
\t\t\t\tVector3(0.36, 0.5, WALL_THICK * 2.4), "cold", Vector3.ZERO, "gate_corbel55")
\t# The arch over the gate.'''+text[end:]
# Keep the existing round silhouettes while making platforms and roofs damage-owned.
swap('\t_furniture_meshes = {"turned": turned, "cup": cup, "disk": disk, "soft": soft}', '''\t_furniture_meshes = {"turned": turned, "cup": cup, "disk": disk, "soft": soft}
\tvar tower_floor := CylinderMesh.new()
\ttower_floor.top_radius = 0.5
\ttower_floor.bottom_radius = 0.5
\ttower_floor.height = 1.0
\ttower_floor.radial_segments = 20
\t_furniture_meshes["tower_floor55"] = tower_floor
\tvar tower_roof := CylinderMesh.new()
\ttower_roof.top_radius = 0.8 / ((TOWER_RADIUS + 0.4) * 2.0)
\ttower_roof.bottom_radius = 0.5
\ttower_roof.height = 1.0
\ttower_roof.radial_segments = 20
\t_furniture_meshes["tower_roof55"] = tower_roof''')
start=text.index('func _build_tower_platforms()');end=text.index('\n## A HANGING BRIDGE',start)
text=text[:start]+'''func _build_tower_platforms() -> void:
\tfor corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
\t\tvar centre := Vector3(corner.x * WALL_HALF, 0.0, corner.y * WALL_HALF)
\t\t_add_brick(centre + Vector3.UP * (WALL_HEIGHT - 0.1),
\t\t\tVector3((TOWER_RADIUS - 0.35) * 2.0, 0.24, (TOWER_RADIUS - 0.35) * 2.0),
\t\t\t"warm", Vector3.ZERO, "tower_floor55", 0, 0, "tower_floor55")
\t\t_add_brick(centre + Vector3.UP * (TOWER_HEIGHT + 1.2),
\t\t\tVector3((TOWER_RADIUS + 0.4) * 2.0, 2.4, (TOWER_RADIUS + 0.4) * 2.0),
\t\t\t"cold", Vector3.ZERO, "tower_roof55", 0, 0, "tower_roof55")
'''+text[end:]
# Include the whole extent, not just a tall column's central 8m bucket.
start=text.index('\t\tvar spatial_key :=',text.index('func _flush_buckets'))
end=text.index('\n\t\tvar key :=',start)
text=text[:start]+'''\t\tvar bounds := _cell_bounds55(cell)
\t\tcell["bounds55"] = bounds
\t\tfor gx: int in range(int(floor(bounds.position.x / SPATIAL_STEP)), int(floor(bounds.end.x / SPATIAL_STEP)) + 1):
\t\t\tfor gy: int in range(int(floor(bounds.position.y / SPATIAL_STEP)), int(floor(bounds.end.y / SPATIAL_STEP)) + 1):
\t\t\t\tfor gz: int in range(int(floor(bounds.position.z / SPATIAL_STEP)), int(floor(bounds.end.z / SPATIAL_STEP)) + 1):
\t\t\t\t\tvar spatial_key := "%d|%d|%d" % [gx, gy, gz]
\t\t\t\t\tif not _spatial.has(spatial_key): _spatial[spatial_key] = []
\t\t\t\t\t(_spatial[spatial_key] as Array).append(index)'''+text[end:]
swap('\tcell["alive"] = false','''\tcell["alive"] = false
\t_masonry_changed55[index] = true
\tvar masonry_shape: CollisionShape3D = _masonry_shapes55.get(index)
\tif is_instance_valid(masonry_shape): masonry_shape.set_deferred("disabled", true)''')
swap('func _indices_box(low: Vector3, high: Vector3) -> Array[int]:\n\tvar out: Array[int] = []','func _indices_box(low: Vector3, high: Vector3) -> Array[int]:\n\tvar out: Array[int] = []\n\tvar seen := {}')
swap('\t\t\t\t\tfor index: int in bucket:\n\t\t\t\t\t\tout.append(index)','''\t\t\t\t\tfor index: int in bucket:
\t\t\t\t\t\tif seen.has(index): continue
\t\t\t\t\t\tseen[index] = true
\t\t\t\t\t\tout.append(index)''')
swap('\t\tif brick_at.distance_to(at) > radius: continue','''\t\tvar distance := _cell_distance55(cell, at) if _wall_masonry55(cell) else brick_at.distance_to(at)
\t\tif distance > radius: continue''')
swap('\tif killed > 0:\n\t\t_break_collision_near(at, radius)','\tif killed > 0:\n\t\t_sync_masonry_collision55()\n\t\t_break_collision_near(at, radius)')
# Remaining legacy cleanup is limited to furnishings and separate floor tiles.
swap('\t\tvar size: Vector3 = section["size"]\n\t\t# DSH_OPT:', '''\t\tif not body.get_meta("castle_furnishing", false) and not body.get_meta("castle_keep_floor", false):
\t\t\tcontinue # Wall sections were refined to their surviving cells above.
\t\tvar size: Vector3 = section["size"]
\t\t# DSH_OPT:''')
swap('\t# Falling bricks settle, and very old ones', '\t_sync_masonry_collision55()\n\t# Falling bricks settle, and very old ones')
# A foot hit on a tall pier must also release the cap immediately above its top.
swap('\t\tif brick_at.distance_to(at) > radius + 0.5: continue\n\t\tholes.append', '''\t\tif (_cell_distance55(cell, at) if _wall_masonry55(cell) else brick_at.distance_to(at)) > radius + 0.5: continue
\t\tif _wall_masonry55(cell) and (cell["size"] as Vector3).y > 3.0:
\t\t\tvar top: float = (cell["bounds55"] as AABB).end.y
\t\t\tholes.append({"x": brick_at.x, "y": top - BRICK.y * 0.5, "z": brick_at.z})
\t\tholes.append''')
swap('\tvar support_high := at + Vector3(radius + 1.2, radius * 3.2, radius + 1.2)','''\tvar support_high := at + Vector3(radius + 1.2, radius * 3.2, radius + 1.2)
\tfor hole: Dictionary in holes:
\t\tsupport_high.y = maxf(support_high.y, float(hole.y) + radius * 2.2)''')
text+='\n'+(O/'masonry55.gd.txt').read_text(encoding='utf-8')
with Lease('headless',G,access='write',wait_seconds=120):p.write_text(text,encoding='utf-8',newline='\r\n')
print('castle_site.gd updated')
