# Exact source mesh subdivision — frozen transport component

Production scripts/transport/transport_mesh_subdivision.gd SHA f923e741f4899db8a65812d32ff34e0801642e38412af1ea186d74d3df02ac19.
Test scripts/tests/test_transport_mesh_subdivision.gd SHA e6d7a40faa690353feda613094ec6058fba4464b54e7468c9e53eee271d72826.
Fixture data/transport/mesh_subdivision_oracle.json SHA 4ec3bd3b28625bee0adada0c83ea251a23ba00c60e3bd11b6b4a5d7782c3c917.
Exporter tools/godot/export_transport_subdivision_oracle.mjs SHA 5e398b2ccefea5dbc7c725c6f4c9bfeebccc125360be68d19e35dcb6bc92f522.

API static subdivide(original:ArrayMesh,max_edge_m=.15,max_triangles=9000) returns Dictionary with ok, mesh and counts. Original stays unchanged. Source vehicle_crash.mjs subdivision executes global split budget, depth7, longest-edge tie order and source DFS exactly. Preserves positions, normals, tangents, colors, UV, UV2, surface names/materials. Unsupported custom attributes, skin, blend shapes, LOD or nontriangle layouts reject explicitly, without deleting content.

Actual source JS oracle: four cases exercise global9triangle budget,20triangle tie/material case,2triangle unchanged case and256triangle depth cap. Author15586 and independent parent15586 checks PASS. Engine normal/tangent storage tolerance5e-5, colors UNORM8 tolerance1/255, position/UV/topology2e-6. Fixture regeneration byte-identical twice.

Synthetic four-case preparation5.371ms author/5.585ms parent; perform during preparation, never inside crash event. Actual fleet preparation and loaded-scene frame time remain unmeasured. This helper alone does not implement collision, HP, detachment or deformation. Consumer adapter remains in progress. Root owns main integration/Git/LIVE.
