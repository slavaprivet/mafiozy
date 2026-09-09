"""Blender 3.4 offline render of exported runtime geometry; display scale only."""
import bpy, json, math, sys
from pathlib import Path
from mathutils import Vector
OUT = Path(__file__).resolve().parents[2] / 'outputs' / 'vehicle_fleet_continuation'
ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
STATES = ['closed', 'open'] if not ARGS else ARGS
SCALES = {}
def material(spec):
    key = json.dumps(spec, sort_keys=True)
    if key in materials: return materials[key]
    mat = bpy.data.materials.new('runtime_material'); mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*spec['color'], 1)
    bsdf.inputs['Roughness'].default_value = spec['roughness']
    bsdf.inputs['Metallic'].default_value = spec['metalness']
    bsdf.inputs['Alpha'].default_value = spec['alpha']
    bsdf.inputs['Emission'].default_value = (*spec['emissive'], 1)
    bsdf.inputs['Emission Strength'].default_value = spec['emissiveIntensity']
    if spec['alpha'] < 1:
        mat.blend_method = 'BLEND'; mat.show_transparent_back = False; mat.use_screen_refraction = True
    mat.use_backface_culling = not spec['doubleSide']
    materials[key] = mat
    return mat
for state in STATES:
    records = json.loads((OUT / ('runtime_' + state + '.json')).read_text(encoding='utf-8'))
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    for datablocks in [bpy.data.meshes, bpy.data.materials, bpy.data.curves]:
        for block in list(datablocks):
            if not block.users: datablocks.remove(block)
    roots = []; materials = {}
    for i, record in enumerate(records):
        offset = Vector(((i % 4 - 1.5) * 7.5, (1.5 - i // 4) * 8.5, 0))
        root = bpy.data.objects.new(record['id'], None); bpy.context.collection.objects.link(root); root.location = offset; roots.append(root)
        # Identical scale for closed/open; native geometry in JSON is never scaled.
        if state == 'closed' or record['id'] not in SCALES:
            points = [v for part in record['pieces'] for v in part['vertices']]
            length = max(v[1] for v in points) - min(v[1] for v in points)
            SCALES[record['id']] = min(1.08, 5.7 / length)
        scale = SCALES[record['id']]; root.scale = (scale,) * 3
        for part in record['pieces']:
            mesh = bpy.data.meshes.new(part['name']); mesh.from_pydata(part['vertices'], [], part['faces']); mesh.update()
            obj = bpy.data.objects.new(part['name'], mesh); bpy.context.collection.objects.link(obj); obj.parent = root
            for spec in part['materials']: mesh.materials.append(material(spec))
            for face, idx in zip(mesh.polygons, part['materialIndices']):
                face.material_index = min(idx, len(part['materials']) - 1); face.use_smooth = not part['materials'][face.material_index]['flatShading']
            if part['normals']:
                mesh.use_auto_smooth = True; mesh.normals_split_custom_set_from_vertices(part['normals'])
        bpy.ops.object.text_add(location=(offset.x - 3.25, offset.y - 3.65, .025))
        label = bpy.context.object; label.data.body = record['id'] + '\n' + record['label'] + ' | display x' + format(scale,'.2f'); label.data.size = .25
    ground = bpy.data.materials.new('ground'); ground.diffuse_color = (.16, .19, .20, 1)
    bpy.ops.mesh.primitive_plane_add(size=75, location=(0, 0, -.028)); bpy.context.object.data.materials.append(ground)
    bpy.ops.object.camera_add(location=(0, -40, 43)); cam = bpy.context.object
    cam.rotation_euler = (Vector((0, 0, .5)) - cam.location).to_track_quat('-Z','Y').to_euler(); cam.data.type='ORTHO'; cam.data.ortho_scale=35.8; bpy.context.scene.camera=cam
    bpy.ops.object.light_add(type='SUN'); bpy.context.object.rotation_euler=(.45,-.5,.6); bpy.context.object.data.energy=2.2
    bpy.ops.object.light_add(type='AREA',location=(-12,-12,20)); bpy.context.object.data.energy=1300; bpy.context.object.data.size=18
    scene=bpy.context.scene; scene.render.engine='BLENDER_EEVEE'; scene.eevee.use_gtao=True; scene.eevee.gtao_distance=1.5; scene.eevee.gtao_factor=1.15; scene.eevee.taa_render_samples=64; scene.world.color=(.35,.35,.35)
    scene.view_settings.view_transform='Standard'; scene.view_settings.look='Medium High Contrast'; scene.render.resolution_x=3200; scene.render.resolution_y=3000; scene.render.resolution_percentage=100; scene.render.image_settings.file_format='PNG'
    for view, angle in [('front',2.52),('rear',.62)]:
        for root in roots: root.rotation_euler.z=angle
        scene.render.filepath=str(OUT / ('fleet_' + state + '_' + view + '.png')); bpy.ops.render.render(write_still=True)
    print('FINISHED',state,flush=True)
(OUT / 'display_scales.json').write_text(json.dumps({'note':'Blender presentation only; runtime export remains native metres. Same scale in closed/open.', 'scales':SCALES},indent=2))
