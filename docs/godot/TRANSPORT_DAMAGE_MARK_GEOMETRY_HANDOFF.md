# Transport damage mark geometry — frozen handoff

Дата: 27 сентября 2026. Статус: **frozen prepared-resource component**.

Компонент извлекает фактический private 32-slot mark pool из
`assets/maps/city_rebuild_v1/vehicle_damage.mjs` SHA-256
`e029cb4a03dcd23bbdd0fb2f73b7780db92f24f761cf83b030991acb3c403f92`
через инструментированный in-memory модуль Three r180. Формулы геометрии и
материалов в exporter не переписаны.

## Frozen files

- `tools/godot/export_transport_damage_mark_geometry.mjs` —
  `f4dbbadf064cf4776750c1d9731af4cd461f2d04f3d34aca9e2bf8aa0927d986`
- `godot/mafiozi_walk/data/transport/damage_mark_geometry.json` —
  `d05b5114ef6ada70e8690f99752052ac00121aaf774ac6a1bae874c1edd46bf0`
- `godot/mafiozi_walk/scripts/transport/transport_damage_mark_geometry.gd` —
  `314c6d0483b67b600025f96d3194c8ec334532ab2ce73f9fbecd93f0ada72461`
- `godot/mafiozi_walk/scripts/tests/test_transport_damage_mark_geometry.gd` —
  `4d06344a1f9169dd7a557d88b0bd8c29b0f639058e189a64e7baf4db0c38cc80`

JSON fixture является обязательной runtime export dependency. Root должен явно
включить `res://data/transport/damage_mark_geometry.json` в Godot export.

## API

```gdscript
const MarkGeometry = preload("res://scripts/transport/transport_damage_mark_geometry.gd")
var prepared := MarkGeometry.prepare()
```

`prepare()` SHA-проверяет единственный canonical JSON и возвращает:

- `meshes.scratch`, `meshes.crater`: два новых приватных `ArrayMesh`;
- `materials.scratch`, `materials.crater`: два новых приватных
  `StandardMaterial3D`;
- `source_buffers`: точные исходные Float32 position/normal/color/UV и source
  indices;
- `slot_types`: точное отображение 32 физических слотов, scratch в
  `0, 3, …, 30` (11), crater в остальных 21;
- `limitations`, `source_sha`, `fixture_sha`.

Каждый вызов создаёт ровно два mesh и два material resource для одной машины.
На попадании эту фабрику вызывать нельзя. Компонент не создаёт Nodes, не ведёт
cursor, HP или authority и не применяет mark pose.

## Fidelity seams

- Three использует CCW front face, Godot `ArrayMesh` — clockwise. Native index
  buffer один раз меняет `b/c` каждого треугольника. Для исходно nonindexed
  crater создаётся `0,2,1`, затем `3,5,4` и так далее. Source buffers и source
  index order остаются неизменными.
- Геометрия сохраняет canonical XY orientation и +Z normals. Scratch содержит
  4 вершины, crater — 108, вместе 112 вершин на машину.
- Source linear material color переводится в sRGB-valued Godot albedo property;
  `vertex_color_is_srgb=false` сохраняет linear crater colors.
- Standard `ArrayMesh` хранит normals в octahedral representation и vertex
  colors в RGBA8. Тест проверяет native representation, включая alpha, а точные
  Float32 source buffers возвращаются отдельно.
- Three `polygonOffset=true`, factor `-2`, units `0` извлечены и строго
  проверяются, но у `StandardMaterial3D` нет точного эквивалента raster bias.
  Это остаётся GPU/LIVE integration limitation и требует отдельного визуального
  решения; пакет не подменяет его depth-disable или cull workaround.

## Verification

Команда:

```powershell
tools/godot/run_transport_test.ps1 -Resource res://scripts/tests/test_transport_damage_mark_geometry.gd -TimeoutSeconds 60
```

- author: **39/39 PASS**;
- parent: **39/39 PASS**;
- independent reviewer: **39/39 PASS**.

Exporter выполнен дважды и создал byte-identical JSON SHA
`d05b5114ef6ada70e8690f99752052ac00121aaf774ac6a1bae874c1edd46bf0`.

Квалифицированный последовательный parent cost после завершения независимого
прогона: **106,056 µs / 100 prepares = 1.06056 ms/car**. Предыдущий результат
0.96959 ms/car отброшен как потенциально пересекавшийся с чужим прогоном.
Это load/preparation CPU cost, не FPS и не full-scene/GPU acceptance.

