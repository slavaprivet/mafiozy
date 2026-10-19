# Native burn-material alias census — frozen handoff

Date: 2026-09-27. This is a read-only native evidence package. It adds one test and census documents; it does not change `vehicle_visual.gd`, any transport runtime, material, GLB, manifest, main scene, or authority path.

## Purpose and source pins

The future burned-material preparation seam needs to know whether repeated exported material IDs really share one native private resource and whether separate vehicles remain isolated. The test uses the actual current loader and all actual GLBs:

- `res://scripts/vehicle_visual/vehicle_visual.gd` SHA-256 `d586952de302b7ec0467b89b91ba117e3350e8a5c217f48c303f06ff88494e34`
- `res://assets/vehicle_visual/manifest.json` SHA-256 `38598f43beb77c095879206ea5820c7fe922b227a64f77f793353f89321fee03`
- exact 13-entry profile set, including the separate `city_taxi` export

`vehicle_visual.gd` `_bind()` duplicates each imported `ArrayMesh`, duplicates the first `StandardMaterial3D` for a new `source_material_id`, and reuses that owned material for later native surfaces with the same ID inside that visual. The census verifies this actual behavior rather than inferring it from loader code.

## Frozen files

- `godot/mafiozi_walk/scripts/tests/test_transport_burn_material_aliases.gd`
- `docs/godot/TRANSPORT_BURN_MATERIAL_ALIAS_CENSUS.json`
- this handoff
- `docs/godot/TRANSPORT_BURN_MATERIAL_ALIAS_MANIFEST.json`

Exact hashes and sizes are in the package manifest.

## Verified invariants

For every mesh surface of every profile, the test reads `MeshInstance3D.get_active_material(surface)` and the material's exported `source_material_id` and `source_metadata`:

- repeated IDs resolve to the same `StandardMaterial3D` object inside that visual;
- different IDs resolve to different resources;
- native `source_metadata` deep-equals the exact manifest `mesh_materials[node][0].source_metadata` row;
- the visual profile and the exact 13-profile manifest table agree;
- two simultaneous `compact_sedan` visuals expose the same 57 source IDs but share zero material Resource identities;
- a queued visual root is rejected by the census and frees cleanly.

The per-profile counts are frozen in `TRANSPORT_BURN_MATERIAL_ALIAS_CENSUS.json`:

| Profile | Raw slots/IDs | Native slots/IDs | Native aliases |
|---|---:|---:|---:|
| city_hatchback | 270/57 | 268/56 | 212 |
| compact_sedan | 267/57 | 267/57 | 210 |
| family_wagon | 267/57 | 265/56 | 209 |
| executive_sedan | 272/57 | 272/57 | 215 |
| sport_coupe | 221/58 | 221/58 | 163 |
| city_suv | 273/57 | 271/56 | 215 |
| delivery_van | 227/57 | 226/57 | 169 |
| utility_pickup | 221/58 | 221/58 | 163 |
| city_bus | 233/59 | 233/59 | 174 |
| police_interceptor | 272/60 | 272/60 | 212 |
| city_ambulance | 234/60 | 234/60 | 174 |
| fire_engine | 250/61 | 250/61 | 189 |
| city_taxi | 276/59 | 276/59 | 217 |

The native census is intentionally partial relative to raw source descriptors in four profiles. Seven manifest slots import as visible, childless `Node3D` placeholders with no native mesh surface:

- `city_hatchback`: `v0008` / `LOD0_city_hatchback_Taillamp_L` and `v0009` / `..._Taillamp_R`, both source material `m0003`;
- `family_wagon`: `v0007` / `LOD0_family_wagon_Taillamp_L` and `v0008` / `..._Taillamp_R`, both `m0003`;
- `city_suv`: `v0009` / `LOD0_city_suv_Taillamp_L` and `v0010` / `..._Taillamp_R`, both `m0003`;
- `delivery_van`: `v0002` / `LOD0_delivery_van_CargoDoorSplit`, material `m0000` which is also present on other native surfaces.

The six absent taillamp slots make raw `m0003` unavailable as a native material in hatchback, wagon and SUV. A separate read-only parse with the actual Three r180 `GLTFLoader` proves these are not empty source placeholders. Each taillamp is a source `Mesh` with 216 `Float32` positions and 324 `Uint16` indices; `CargoDoorSplit` has 96 positions and 132 indices. All seven have one indexed triangle geometry, no groups, and the default draw range `{start: 0, count: Infinity}`. The exact loaded position/index byte hashes are frozen in the census JSON, against the four SHA-pinned source GLBs.

Therefore the seven slots are an export/import coverage loss. A future source burn binder must fail closed for these identities until the missing native geometry and its identity are restored by an explicitly reviewed visual export. It must not delete content or silently substitute another material. The executed-source identity fixture `source_burn_identities.json` independently confirms that all seven were real scalar material containers captured by source `materialRest`; it does not itself restore their native geometry.

## Verification and cost

```powershell
tools/godot/run_transport_test.ps1 -Resource res://scripts/tests/test_transport_burn_material_aliases.gd -TimeoutSeconds 60
```

Godot 4.7.2 results after raw/native coverage assertions: **author 89/89 PASS; parent fresh sequential rerun 89/89 PASS**. The executed-source identity exporter also replayed byte-identically to SHA-256 `38d370792b7e97445b56efb35b4360121157a659905216db79221f78f22c2d38` after the parent census process joined.

Each run instantiated and disposed every profile sequentially, then held two compact instances together for the cross-car check. The author run took 1,811,329 us total and may have shared CPU with another exporter. The fresh parent sequential rerun, started after the other jobs joined, took **1,836,398 us total**. This is an isolated headless load-only measurement. It is not a frame/load budget and makes no adoption, GPU, FPS, or full-scene performance claim. GLTF loader/cache state is process-local and unavoidable for this evidence run; every created visual is disposed.

## Exact limits for future preparation

- The native identity key is the exact exported `source_material_id` plus its manifest metadata, scoped to one visual instance. The same textual ID in another car does not grant shared Resource ownership.
- This census supports one private prepared variant per unique ID per car, subject to current-material stamps and the separately frozen burn planner. It does not approve a preset implementation.
- Current GLTF import presents one native material per surface. That does **not** prove whether the original Three mesh used a scalar material or a one-element material array. The source explosion eligibility oracle must resolve that distinction; this census must not infer it.
- The SHA-pinned executed-source identity receipt resolves the seven named missing nodes as scalar containers. The scalar/one-element-array limitation remains for native surfaces that are not covered by that source receipt.
- No material was mutated. No renderer, GPU, shader compile, LIVE scene, hit authority, HP, callback, alpha conversion, or explosion timing was exercised.
