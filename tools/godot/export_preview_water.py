"""Deterministic native Walk water/depth crop; never exports physics or guessed lakes.

Depths follow source Float32 terrain vertices before preview recentering. A separate
JS oracle executes the actual source terrain/waterAt to verify every vertex.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import math

ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / "godot/mafiozi_walk/data/preview_water.json"
ORDER = [[0, 0], [1, 1], [1, 0], [0, 0], [0, 1], [1, 1]]

def receipt(path: Path) -> dict:
    raw = path.read_bytes()
    return {"path": path.relative_to(ROOT).as_posix(), "bytes": len(raw),
            "sha256": hashlib.sha256(raw).hexdigest()}

def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))

def f32(value: float) -> float:
    return struct.unpack("<f", struct.pack("<f", value))[0]

def native_depth(topology: dict, cell: float, x: float, z: float) -> float:
    r, c = math.floor(z / cell), math.floor(x / cell)
    grid, protected = topology["grid"], topology["protectedMask"]
    def tile(rr: int, cc: int):
        return grid[rr][cc] if 0 <= rr < len(grid) and 0 <= cc < len(grid[rr]) else None
    if tile(r, c) != 16 or protected[r][c]:
        return 0.0
    shore = 3.5
    for rr in range(r - 1, r + 2):
        for cc in range(c - 1, c + 2):
            if tile(rr, cc) == 16:
                continue
            dx = max(cc * cell - x, 0, x - (cc + 1) * cell)
            dz = max(rr * cell - z, 0, z - (rr + 1) * cell)
            shore = min(shore, math.hypot(dx, dz))
    floor = -min(2.4, shore * .9)
    # Actual source prepareMesh stores Float32 depth, clamped0..50.
    return f32(max(0.0, min(50.0, -.18 - floor)))

def export() -> dict:
    block_path = ROOT / "godot/mafiozi_walk/data/block.json"
    topology_path = ROOT / "assets/maps/city_rebuild_v1/topology_for_placement.json"
    walk_path = ROOT / "assets/maps/city_rebuild_v1/walk_preview.mjs"
    landscape_path = ROOT / "assets/maps/city_rebuild_v1/landscape_plan.mjs"
    material_path = ROOT / "assets/maps/city_rebuild_v1/environment_surface_materials.mjs"
    block, topology = read_json(block_path), read_json(topology_path)
    topology_receipt = receipt(topology_path)
    if topology_receipt not in block["sources"]:
        raise ValueError("Block topology receipt stale; re-export block before water")
    walk = walk_path.read_text(encoding="utf-8-sig")
    compact = re.sub(r"\s+", "", walk)
    required = ["constfloor=-Math.min(2.4,shore*.9);return{level:-.18,depth:Math.max(0,-.18-floor),floor};",
                "letshore=3.5;for(letrr=r-1;rr<=r+1;rr++)for(letcc=c-1;cc<=c+1;cc++)",
                "arr.push(x,y,z,x+M,y,z+M,x+M,y,z,x,y,z,x,y,z+M,x+M,y,z+M)"]
    if any(fragment not in compact for fragment in required):
        raise ValueError("Actual Walk water/terrain formula changed; update exporter+oracle explicitly")
    plan = landscape_path.read_text(encoding="utf-8-sig")
    if "const insideCity=(x,z)=>x>=0&&x<738&&z>=0&&z<820;" not in plan:
        raise ValueError("Landscape precedence/city bounds changed; depth adapter needs review")
    surface, cell, origin = block["surface"], block["metresPerCell"], block["originM"]
    if cell != 4.1 or cell != topology["map"]["worldUnitsPerCell"]:
        raise ValueError("Source native metre scale changed")
    r0, c0 = surface["startRow"], surface["startCol"]
    r1, c1 = r0 + surface["rows"], c0 + surface["cols"]
    grid, protected = topology["grid"], topology["protectedMask"]
    if surface["grid"] != [row[c0:c1] for row in grid[r0:r1]]:
        raise ValueError("Block grid crop stale")
    if surface["masks"]["protectedMask"] != [row[c0:c1] for row in protected[r0:r1]]:
        raise ValueError("Block protected crop stale")
    cells = []
    for r in range(r0, r1):
        for c in range(c0, c1):
            if grid[r][c] != 16 or protected[r][c]:
                continue
            depths = []
            for dc, dr in ORDER:
                x, z = f32((c + dc) * cell), f32((r + dr) * cell)
                if not (0 <= x < 738 and 0 <= z < 820):
                    raise ValueError("Crop vertex hits landscape precedence; actual landscape depth exporter required")
                depths.append(native_depth(topology, cell, x, z))
            cells.append({"r": r, "c": c, "depths": depths})
    all_water = sum(v == 16 for row in grid for v in row)
    protected_water = sum(v == 16 and bool(protected[r][c])
                          for r, row in enumerate(grid) for c, v in enumerate(row))
    return {"schema": "mafiozi.godot.preview-water/v1", "originM": origin,
            "metresPerCell": cell, "scope": "exact native water crop; geometry/depth only, no physics or gameplay",
            "coordinateContract": "RH Y-up; source Float32 terrain vertex minus originM; original world coordinates feed shader",
            "native": {"surfaceYM": -.18, "vertexOrder": ORDER,
                       "winding": "unchanged Three source triangle order; Godot host must adapt front winding explicitly",
                       "depthSampling": "source Float32 terrain positions before origin recenter; actual prepareMesh Float32 depth",
                       "cells": cells},
            "previewBoundsRC": {"rMinInclusive": r0, "rMaxExclusive": r1,
                                "cMinInclusive": c0, "cMaxExclusive": c1},
            "previewSourceBoundsM": {"min": [c0 * cell, -.18, r0 * cell],
                                     "max": [c1 * cell, -.18, r1 * cell]},
            "previewBoundsLocalM": {"min": [c0 * cell - origin[0], -.18 - origin[1], r0 * cell - origin[2]],
                                    "max": [c1 * cell - origin[0], -.18 - origin[1], r1 * cell - origin[2]]},
            "coverage": {"mapWaterCells": all_water, "mapProtectedWaterCells": protected_water,
                         "mapUnprotectedWaterCells": all_water - protected_water,
                         "exportedNativeCells": len(cells), "exportedNativeVertices": len(cells) * 6,
                         "outsidePreviewNativeCells": all_water - protected_water - len(cells),
                         "outsidePreviewStatus": "NOT_EXPORTED_OPEN; no silent all-map claim",
                         "landscapeClippedWaterStatus": "NOT_EXPORTED_OPEN; original clipped lake geometry is distinct"},
            "sources": [receipt(p) for p in [block_path, topology_path, walk_path, landscape_path, material_path]],
            "sourceStatus": block.get("sourceStatus", {}), "exporterReceipt": receipt(Path(__file__).resolve())}

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    data = export()
    raw = (json.dumps(data, ensure_ascii=False, indent=2, allow_nan=False) + "\n").encode("utf-8")
    if args.check:
        if not TARGET.exists() or TARGET.read_bytes() != raw:
            raise SystemExit("Water export differs; review sources then regenerate")
    else:
        TARGET.write_bytes(raw)
    print(json.dumps({"status": "PASS", "check": args.check, "cells": len(data["native"]["cells"]),
                      "vertices": data["coverage"]["exportedNativeVertices"], "sha256": hashlib.sha256(raw).hexdigest()}))

if __name__ == "__main__":
    main()
