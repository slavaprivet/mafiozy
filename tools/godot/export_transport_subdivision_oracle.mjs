#!/usr/bin/env node
// Numerical oracle for vehicle_crash.mjs subdivideVehicleGeometry.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {registerHooks} from 'node:module';
import {fileURLToPath, pathToFileURL} from 'node:url';

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const vendor = process.env.MAFIOZI_THREE_VENDOR ?? 'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const sha = bytes => createHash('sha256').update(bytes).digest('hex');
registerHooks({resolve(specifier, context, next) {
  return next(specifier === 'three' ? pathToFileURL(path.join(vendor, 'build/three.module.js')).href : specifier, context);
}});
const T = await import('three');
assert.equal(T.REVISION, '180');
const crashPath = path.join(repo, 'assets/maps/city_rebuild_v1/vehicle_crash.mjs');
const {subdivideVehicleGeometry} = await import(pathToFileURL(crashPath));

const input = {
  position: {item_size: 3, values: [
    0, 0, 0,  2, 0, 0,  0, 2, 0,
    -1, .25, .5,  -.1, .25, .5,  -1, 1.15, .5,
  ]},
  normal: {item_size: 3, values: [
    0, 0, 1,  0, 0, 1,  0, 0, 1,
    0, 1, 0,  0, 1, 0,  0, 1, 0,
  ]},
  tangent: {item_size: 4, values: [
    1,0,0,1,  1,0,0,1,  1,0,0,1,
    0,0,1,-1,  0,0,1,-1,  0,0,1,-1,
  ]},
  color: {item_size: 4, values: [
    1,0,0,1,  0,1,0,.8,  0,0,1,.6,
    1,1,0,.4,  0,1,1,.2,  1,0,1,0,
  ]},
  uv: {item_size: 2, values: [0,0, 1,0, 0,1,  .1,.2, .9,.2, .1,.95]},
  uv2: {item_size: 2, values: [.2,.1, .8,.1, .2,.9,  0,0, 1,0, 0,1]},
};
const indices = [0, 1, 2, 3, 4, 5];
const groups = [{start: 0, count: 3, material_index: 0}, {start: 3, count: 3, material_index: 1}];

function geometry() {
  const value = new T.BufferGeometry();
  for (const [name, attribute] of Object.entries(input)) value.setAttribute(name, new T.Float32BufferAttribute(attribute.values, attribute.item_size));
  value.setIndex(indices);
  for (const group of groups) value.addGroup(group.start, group.count, group.material_index);
  return value;
}

function outputCase(id, maxEdge, maxTriangles) {
  const source = geometry();
  const result = subdivideVehicleGeometry(T, source, maxEdge, maxTriangles);
  const attributes = Object.fromEntries(Object.entries(result.attributes).map(([name, value]) => [name, {item_size: value.itemSize, values: Array.from(value.array)}]));
  const outGroups = result.groups.map(group => ({start: group.start, count: group.count, material_index: group.materialIndex}));
  const surfaces = outGroups.map(group => {
    const surface = {material_index: group.material_index, vertex_count: group.count, attributes: {}};
    for (const [name, attribute] of Object.entries(attributes)) {
      const from = group.start * attribute.item_size, to = (group.start + group.count) * attribute.item_size;
      surface.attributes[name] = {item_size: attribute.item_size, values: attribute.values.slice(from, to)};
    }
    return surface;
  });
  source.dispose(); result.dispose();
  return {id, max_edge_m: maxEdge, max_triangles: maxTriangles, output_triangle_count: surfaces.reduce((n, surface) => n + surface.vertex_count / 3, 0), groups: outGroups, surfaces};
}

const fixture = {
  schema: 'mafiozi.transport-mesh-subdivision-oracle.v1',
  source: {path: path.relative(repo, crashPath).replaceAll('\\', '/'), sha256: sha(fs.readFileSync(crashPath)), function: 'subdivideVehicleGeometry lines 6-27', three_revision: T.REVISION},
  native_storage: {normal_tangent: 'unit-direction attributes; Godot ArrayMesh normalizes and octahedrally encodes these slots', color: 'Godot ArrayMesh UNORM8 readback tolerance 1/255'},
  input: {indexed: true, indices, groups, attributes: input},
  cases: [
    outputCase('global_budget_dfs', .15, 9),
    outputCase('tie_and_materials', .75, 20),
    outputCase('no_split_budget', .01, 2),
    outputCase('depth_cap', .0001, 400),
  ],
};
const destination = path.join(repo, 'godot/mafiozi_walk/data/transport/mesh_subdivision_oracle.json');
fs.mkdirSync(path.dirname(destination), {recursive: true});
fs.writeFileSync(destination, JSON.stringify(fixture) + '\n');
console.log(JSON.stringify({output: path.relative(repo, destination).replaceAll('\\', '/'), sha256: sha(fs.readFileSync(destination)), cases: fixture.cases.map(row => ({id: row.id, triangles: row.output_triangle_count, surfaces: row.surfaces.length}))}));
