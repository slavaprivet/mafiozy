import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import assert from 'node:assert/strict';
import {loadPinned,makeIndex} from './source_index.mjs';

const here=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(here,'../../..');
const eager=fs.readFileSync(path.join(root,'tools/godot/map_editor_procedural_native_v3/scripts/procedural_factory.gd'),'utf8');
const incremental=fs.readFileSync(path.join(here,'incremental_factory.gd'),'utf8');
const fixture=fs.readFileSync(path.join(here,'test_incremental_factory.gd'),'utf8');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
let checks=0;
function check(value,label){assert.ok(value,label);checks++;}
const formulas=[
 'material.albedo_color = _color(descriptor.colorLinear).linear_to_srgb()',
 'material.roughness = float(descriptor.get("roughness", 1.0))',
 'material.metallic = float(descriptor.get("metalness", 0.0))',
 'material.emission_enabled = descriptor.emissiveLinear != [0, 0, 0]',
 'material.emission = _color(descriptor.emissiveLinear).linear_to_srgb()',
 'material.emission_energy_multiplier = float(descriptor.get("emissiveIntensity", 0.0))',
 'material.vertex_color_use_as_albedo = true',
 'material.vertex_color_is_srgb = false',
 'material.cull_mode = BaseMaterial3D.CULL_DISABLED if int(descriptor.side) == 2 else (BaseMaterial3D.CULL_FRONT if int(descriptor.side) == 1 else BaseMaterial3D.CULL_BACK)',
 'material.albedo_color.a = float(descriptor.opacity)',
 'material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if descriptor.transparent else BaseMaterial3D.TRANSPARENCY_DISABLED',
 'material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if descriptor.type == "MeshBasicMaterial" else BaseMaterial3D.SHADING_MODE_PER_PIXEL',
 'material.set_meta("source_material", descriptor.duplicate(true))',
 'material.set_meta("native_gpu_parity", "native-importer-color/emission-transfer-proved-render/depth-bias-pending")',
 'mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)',
 'mesh.set_meta("source_geometry", geometry.duplicate(true))',
 'mm.transform_format = MultiMesh.TRANSFORM_3D',
 'mm.use_colors = true',
 'mm.mesh = _meshes[batch.geometry]',
 'mm.instance_count = int(batch.count)',
 'var matrices := _float_data(batch.instanceMatrices)',
 'var colors := _float_data(batch.instanceColors)',
 'native_buffer.resize(int(batch.count) * 16)',
 'var transform := _transform(matrices, index * 16)',
 'var tint := Color(colors[index * 3], colors[index * 3 + 1], colors[index * 3 + 2], 1.0)',
 'native_buffer[base + row * 4 + column] = matrices[base + column * 4 + row]',
 'native_buffer[base + 12] = tint.r',
 'native_buffer[base + 13] = tint.g',
 'native_buffer[base + 14] = tint.b',
 'native_buffer[base + 15] = 1.0',
 'mm.buffer = native_buffer',
 'node.material_override = _materials[batch.material]',
 'node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if batch.castShadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF',
 'node.set_meta("source_batch", batch.duplicate(true))',
 '_chunks[chunk_key].batches.append(batch.key)',
 '_batches[batch.key] = {"node": node, "mesh": mm, "source": batch, "chunk": chunk_key, "transforms": instance_transforms, "colors": instance_colors, "initial_native_buffer": native_buffer}'
 ,
 'paint.mesh = _meshes[source.geometry]',
 'paint.material_override = _materials[source.material]',
 'paint.transform = _transform_array(source.sourceWorldMatrix)',
 '_paint_batches[source.key] = {"node": paint, "source": source, "arrays": arrays, "base": arrays[Mesh.ARRAY_VERTEX], "current": arrays[Mesh.ARRAY_VERTEX]}',
 '_paint_ids[str(source.objectIds[index])] = {"batch": source.key, "first": index * 6, "count": 6}',
 'var has_colors: bool = source.has("instanceColors")',
 'mm.use_colors = has_colors',
 'mm.mesh = _meshes[source.geometry]',
 'var values := _float_data(source.instanceMatrices)',
 'var colors := _float_data(source.instanceColors) if has_colors else PackedFloat32Array()',
 'var stride := 16 if has_colors else 12',
 'buffer.resize(int(source.count) * stride)',
 'var transform := _transform(values, index * 16)',
 'var tint := Color(colors[index * 3], colors[index * 3 + 1], colors[index * 3 + 2], 1.0) if has_colors else Color.WHITE',
 'buffer[index * stride + row * 4 + col] = values[index * 16 + col * 4 + row]',
 'buffer[index * stride + 12] = tint.r',
 'buffer[index * stride + 13] = tint.g',
 'buffer[index * stride + 14] = tint.b',
 'buffer[index * stride + 15] = 1.0',
 '_parts[id].append({"batch": source.key, "index": index, "original": transform, "color": tint})',
 'mm.buffer = buffer',
 'node.material_override = _materials[source.material]',
 'node.transform = _transform_array(source.sourceWorldMatrix)',
 '_batches[source.key] = {"node": node, "mesh": mm, "source": source, "chunk": "", "transforms": transforms, "colors": tints, "initial_native_buffer": buffer, "stride": stride}',
 '_recompute_road_bounds(source.key)'
];
for(const formula of formulas){check(eager.includes(formula),`frozen source formula: ${formula}`);check(incremental.includes(formula),`incremental formula: ${formula}`);}
for(const method of ['begin_configure','configure_step','begin_exploration','build_batch_step','finish_exploration','begin_roads','build_road_batch_step','finish_all','source_stage_complete'])check(incremental.includes(`func ${method}(`),`executable ${method}`);
check(incremental.includes('return {"ok":false,"status":"use-incremental-road-batches"}'),'eager road bypass fails closed');
check(incremental.includes('return {"ok":false,"status":"use-incremental-exploration"}'),'eager bypass fails closed');
check(incremental.includes('if _incremental_phase == "COMPLETE" else false'),'partial mutation gate');
check(incremental.includes('_incremental_cursor != 464')&&incremental.includes('_parts.size() != 2440'),'publication requires exact exploration closure');
check(incremental.includes('_road_cursor != 67')&&incremental.includes('_completed_batch_counts.size() != 9394'),'full closure requires exact roads and ID spans');
check(incremental.includes('for id in source_batch.objectIds: unique[str(id)] = true')&&incremental.includes('int(_completed_batch_counts.get(id, 0)) == int(_expected_batch_counts[id])'),'per-ID completion uses unique source batches');
check(incremental.includes('"renderedIds":0')&&incremental.includes('"geometryReadyIds":9394'),'geometry closure is not rendered-world admission');
check(!incremental.includes('renderedIds":9394'),'no false full-world claim');
for(const label of ['partial publication refused','original batch CPU submission identical','native material properties identical','LOD policy parity','eager road bypass refused','source traffic phase and range policy parity','all mapped source batches complete per ID'])check(fixture.includes(label),`opt-in fixture: ${label}`);
const {manifest,catalog,bufferHashes}=loadPinned();
const index=makeIndex(manifest,catalog,bufferHashes);
check(index.batches.slice(0,464).every(x=>x.family==='exploration')&&index.batches.slice(464).every(x=>x.family==='roads'),'source order preserved');
console.log(JSON.stringify({suite:'incremental-procedural-static-source-parity',checks,failures:[],sourceFactorySha256:sha(Buffer.from(eager)),candidateSha256:sha(Buffer.from(incremental)),sourceIndexSha256:index.digest,nativeExecuted:false,renderedIds:0}));
