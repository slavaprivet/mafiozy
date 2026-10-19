from pathlib import Path
import sys,shutil
O=Path(__file__).parent;G=O/'game'; R=Path('C:/Users/Слава/Desktop/Мафиози')
sys.path.insert(0,str(R/'tools/godot'));from test_scheduler import Lease
p=G/'scripts/city/castle_site.gd';shutil.copy2(p,O/'castle_candidate01.gd');t=p.read_text(encoding='utf-8')
def swap(a,b):
    global t
    assert a in t,a[:80]
    t=t.replace(a,b,1)
swap('or "merlon" in group else 1.0','or "merlon" in group or group in ["tower_floor55", "tower_roof55"] else 1.0')
swap('''\tvar body_shape: CollisionShape3D = body.get_node_or_null("Shape") as CollisionShape3D
\tif body_shape != null:
\t\tvar box := BoxShape3D.new()
\t\tbox.size = size
\t\tbody_shape.shape = box
\tvar mesh_instance''','''\tvar body_shape: CollisionShape3D = body.get_node_or_null("Shape") as CollisionShape3D
\tvar shape_key: String = cell.get("shape", "box")
\tif body_shape != null:
\t\tbody_shape.scale = Vector3.ONE
\t\tif shape_key == "tower_floor55":
\t\t\tvar cylinder := CylinderShape3D.new()
\t\t\tcylinder.radius = size.x * 0.5
\t\t\tcylinder.height = size.y
\t\t\tbody_shape.shape = cylinder
\t\telif shape_key == "tower_roof55":
\t\t\tbody_shape.shape = (_furniture_meshes[shape_key] as Mesh).create_convex_shape()
\t\t\tbody_shape.scale = size
\t\telse:
\t\t\tvar box := BoxShape3D.new()
\t\t\tbox.size = size
\t\t\tbody_shape.shape = box
\tvar mesh_instance''')
swap('\tif mesh_instance != null:\n\t\tmesh_instance.scale = size','''\tif mesh_instance != null:
\t\tmesh_instance.mesh = _furniture_meshes[shape_key] if shape_key in ["tower_floor55", "tower_roof55"] else _debris_mesh
\t\tmesh_instance.scale = size''')
swap('\treturn (local_hit - local_hit.clamp(-half, half)).length()', '''\tif cell.get("shape", "box") == "tower_floor55":
\t\treturn Vector2(maxf(Vector2(local_hit.x, local_hit.z).length() - half.x, 0.0),
\t\t\tmaxf(absf(local_hit.y) - half.y, 0.0)).length()
\tif cell.get("shape", "box") == "tower_roof55":
\t\tvar p := Vector2(Vector2(local_hit.x, local_hit.z).length(), local_hit.y)
\t\tvar top_radius := half.x * 0.8 / (TOWER_RADIUS + 0.4)
\t\tvar radius_at_y := lerpf(half.x, top_radius, clampf((p.y + half.y) / (half.y * 2.0), 0.0, 1.0))
\t\tif absf(p.y) <= half.y and p.x <= radius_at_y: return 0.0
\t\tvar profile: Array[Vector2] = [Vector2(0, -half.y), Vector2(half.x, -half.y),
\t\t\tVector2(top_radius, half.y), Vector2(0, half.y)]
\t\tvar distance := INF
\t\tfor i: int in 3:
\t\t\tvar segment := profile[i + 1] - profile[i]
\t\t\tvar closest := profile[i] + segment * clampf((p - profile[i]).dot(segment) / segment.length_squared(), 0.0, 1.0)
\t\t\tdistance = minf(distance, p.distance_to(closest))
\t\treturn distance
\treturn (local_hit - local_hit.clamp(-half, half)).length()''')
swap('\tvar dirty := AABB()\n\tvar first := true','\tvar dirty := AABB()\n\tvar regions: Array[AABB] = []\n\tvar first := true')
swap('\t\tvar bounds: AABB = _cells[index].bounds55\n\t\tdirty =','\t\tvar bounds: AABB = _cells[index].bounds55\n\t\tregions.append(bounds.grow(0.04))\n\t\tdirty =')
swap('\t\tif not bounds.intersects(dirty): continue\n\t\t# Keep every','''\t\tif not bounds.intersects(dirty): continue
\t\t# Simultaneous distant collapses must not refine every untouched wall in
\t\t# the large box between them. Only actual damaged volumes own this work.
\t\tvar touched := false
\t\tfor region: AABB in regions:
\t\t\tif bounds.intersects(region): touched = true; break
\t\tif not touched: continue
\t\t# Keep every''')
with Lease('headless',G,access='write',wait_seconds=120):p.write_text(t,encoding='utf-8',newline='\r\n')
print('Candidate02 ready')
