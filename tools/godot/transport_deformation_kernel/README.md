# Transport deformation packed-array kernel candidate

Status: **SOURCE ONLY / COMPILE BLOCKED / DO NOT ADOPT**.

This is the bounded pure-data portion of the source `createVehicleCrash`
presentation pass. It interpolates the same eight cage offsets in z/y/x order,
transforms them through the mesh inverse basis, scatters them to nonindexed
vertices, and emits the same flat triangle normals as Three.js
`computeVertexNormals()` on nonindexed geometry. It has no Node, Resource,
physics, HP, authority, debris, clock, or registration access.

No compiler, Godot C++ headers, godot-cpp, CMake or Ninja is installed in the
current workspace. These bytes have therefore **not been compiled or executed**.
Nothing registers this source as a GDExtension and no project setting changed.

## Frozen evidence to use for a future build

- Actual source oracle exporter:
  `tools/godot/export_transport_deformation_oracle.mjs`
- Actual oracle data:
  `godot/mafiozi_walk/data/transport/vehicle_deformation_oracle.json`
  SHA-256 `ccd5b46084439ca3aaa12c7d23b94cfdc9b979bd81eed0edd80ac7a9fc7f69e7`
- Native parity test:
  `res://scripts/tests/test_transport_vehicle_deformation.gd`
- Source receipts: `vehicle_crash.mjs` SHA-256
  `cceffb5b6e65a1d180e8860d471351bf04340439ad605a66d6143daf53b20e44`;
  `vehicle_crash_mechanics.mjs` SHA-256
  `3faeed3b6bea790396c7676958100bd5520105d452a61a14c45977d38095a166`.

Reproduce the source fixture now:

```powershell
node tools/godot/export_transport_deformation_oracle.mjs
Get-FileHash godot/mafiozi_walk/data/transport/vehicle_deformation_oracle.json -Algorithm SHA256
```

After a future builder supplies a pinned Godot 4.7.2-compatible C++ toolchain
and a thin wrapper, replace only `SurfaceDeformationJob.run()` with the kernel.
The wrapper must expose typed packed arrays without touching Nodes on workers,
validate every pointer and backing-array length, reject `count * stride` size
overflow and every input/output alias, and write only to private staging
buffers. Any status other than `DeformationStatus::ok` invalidates the complete
staging set; no partial positions, displacements or normals may reach an
ArrayMesh. The wrapper must wait in the same impact frame and commit each unique
ArrayMesh on the main thread. Then run:

```powershell
& tools/godot/run_transport_test.ps1 -Resource res://scripts/tests/test_transport_vehicle_deformation.gd -TimeoutSeconds 60
```

Acceptance requires all 6,178 current checks, byte-stable oracle SHA, unchanged
positions/topology/material groups/UV/color/tangent, normal tolerance 5e-5,
color storage tolerance 2/255, no leaked headless process, and a repeated actual
`compact_sedan` apply below the project's frame-time threshold. A successful
compile alone is not acceptance.

## Standalone source fixture harness (no Godot headers required)

Run node tools/godot/transport_deformation_kernel/export_fixture.mjs to regenerate kernel_fixture_data.h directly from the pinned actual source oracle and source subdivision. Two generations are byte-identical. Executed JS buffer-contract reference:384vertices/81supports, maximum positionerror1.1920929e-7, normalerror1.4454126e-6. This is NOT execution of the C++ kernel.

Future existing compiler, from this directory: cl /std:c++17 /O2 /EHsc transport_deformation_kernel.cpp kernel_fixture_test.cpp /Fe:kernel_fixture_test.exe (MSVC), or c++ -std=c++17 -O2 transport_deformation_kernel.cpp kernel_fixture_test.cpp -o kernel_fixture_test.exe. Then run the executable; nonzero exit rejects source parity or malformed-buffer status. Compiler/toolchain installation has not been performed and the executable does not exist. Typed wrapper/Godot6178checks/loadedsceneperf remain separate mandatory gates.

