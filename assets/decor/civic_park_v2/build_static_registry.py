"""Build the immutable Civic / Park v2 static integration package.

This tool intentionally produces metadata only.  It does not edit the world,
install scene objects, suppress legacy decor, or authorize a live rollout.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import struct
from pathlib import Path


SCHEMA_REGISTRY = "mafiozi.civic-park-decor-registry/v1"
SCHEMA_PLACEMENT = "mafiozi.civic-park-decor-placement-candidate/v1"
WORLD_UNITS_PER_CELL = 4.1


PLACEMENTS = [
    # Three deliberately different fountains, each wholly inside a known park.
    {"id": "DEC-FNT-NORTH-01", "asset": "fountain_district", "r": 17.0, "c": 37.0, "yawDeg": 0, "district": "northside", "scene": "Northside neighbourhood green", "surface": "park"},
    {"id": "DEC-FNT-CENTRAL-01", "asset": "fountain_central", "r": 27.0, "c": 67.0, "yawDeg": 0, "district": "downtown", "scene": "Downtown civic garden", "surface": "park"},
    {"id": "DEC-FNT-RICH-01", "asset": "fountain_park", "r": 77.0, "c": 17.0, "yawDeg": 90, "district": "southside", "scene": "Rich-quarter sculpture garden", "surface": "park"},

    # Downtown civic garden: furniture stays on the edge, not in traffic lanes.
    {"id": "DEC-BEN-CENT-W", "asset": "bench_civic", "r": 27.0, "c": 64.6, "yawDeg": 90, "district": "downtown", "scene": "Downtown civic garden west edge", "surface": "sidewalk"},
    {"id": "DEC-BEN-CENT-E", "asset": "bench_civic", "r": 27.0, "c": 69.4, "yawDeg": 270, "district": "downtown", "scene": "Downtown civic garden east edge", "surface": "sidewalk"},
    {"id": "DEC-BIN-CENT", "asset": "bin_civic", "r": 28.7, "c": 64.6, "yawDeg": 0, "district": "downtown", "scene": "Downtown civic garden service edge", "surface": "sidewalk"},
    {"id": "DEC-BIKE-CENT", "asset": "bike_rack_5", "r": 29.4, "c": 65.4, "yawDeg": 0, "district": "downtown", "scene": "Downtown civic garden south edge", "surface": "park_or_sidewalk"},
    {"id": "DEC-PLANT-CENT", "asset": "planter_rect", "r": 29.4, "c": 68.2, "yawDeg": 0, "district": "downtown", "scene": "Downtown civic garden south edge", "surface": "sidewalk"},
    {"id": "DEC-LIGHT-CENT", "asset": "ped_light_double", "r": 24.65, "c": 69.35, "yawDeg": 90, "district": "downtown", "scene": "Downtown civic garden entrance", "surface": "sidewalk"},
    {"id": "DEC-WAY-CENT", "asset": "sign_wayfinding", "r": 29.4, "c": 69.35, "yawDeg": 90, "district": "downtown", "scene": "Downtown civic garden wayfinding", "surface": "sidewalk"},

    # Northside green: a small community scene, deliberately no extra lamps.
    {"id": "DEC-BEN-NORTH-W", "asset": "bench_civic", "r": 17.0, "c": 34.6, "yawDeg": 90, "district": "northside", "scene": "Northside green west edge", "surface": "sidewalk"},
    {"id": "DEC-BEN-NORTH-E", "asset": "bench_civic", "r": 17.0, "c": 39.4, "yawDeg": 270, "district": "northside", "scene": "Northside green east edge", "surface": "sidewalk"},
    {"id": "DEC-BIN-NORTH", "asset": "bin_civic", "r": 14.6, "c": 37.0, "yawDeg": 0, "district": "northside", "scene": "Northside green north edge", "surface": "sidewalk"},
    {"id": "DEC-PLANT-NORTH", "asset": "planter_round", "r": 19.4, "c": 37.8, "yawDeg": 0, "district": "northside", "scene": "Northside green south edge", "surface": "sidewalk"},
    {"id": "DEC-WAY-NORTH", "asset": "sign_wayfinding", "r": 14.6, "c": 39.35, "yawDeg": 90, "district": "northside", "scene": "Northside green wayfinding", "surface": "sidewalk"},

    # Rich-quarter garden: two low bollards only, not a continuous lamp row.
    {"id": "DEC-BEN-RICH-W", "asset": "bench_civic", "r": 77.0, "c": 14.6, "yawDeg": 90, "district": "southside", "scene": "Rich garden west edge", "surface": "sidewalk"},
    {"id": "DEC-BEN-RICH-E", "asset": "bench_civic", "r": 77.0, "c": 19.4, "yawDeg": 270, "district": "southside", "scene": "Rich garden east edge", "surface": "sidewalk"},
    {"id": "DEC-BIN-RICH", "asset": "bin_civic", "r": 79.4, "c": 15.5, "yawDeg": 0, "district": "southside", "scene": "Rich garden south edge", "surface": "sidewalk"},
    {"id": "DEC-LIGHT-RICH-N", "asset": "ped_light_bollard", "r": 74.6, "c": 16.2, "yawDeg": 0, "district": "southside", "scene": "Rich garden north entrance", "surface": "sidewalk"},
    {"id": "DEC-LIGHT-RICH-S", "asset": "ped_light_bollard", "r": 79.4, "c": 18.5, "yawDeg": 0, "district": "southside", "scene": "Rich garden south entrance", "surface": "sidewalk"},

    # One compact kiosk scene in a separate old-neighbourhood park.
    {"id": "DEC-KIOSK-OLD", "asset": "kiosk_civic", "r": 37.0, "c": 7.0, "yawDeg": 0, "district": "northside", "scene": "Old-neighbourhood pocket park", "surface": "park"},
    {"id": "DEC-BEN-OLD", "asset": "bench_civic", "r": 39.4, "c": 7.0, "yawDeg": 180, "district": "northside", "scene": "Old-neighbourhood pocket park", "surface": "sidewalk"},
    {"id": "DEC-BIN-OLD", "asset": "bin_civic", "r": 39.4, "c": 8.4, "yawDeg": 0, "district": "northside", "scene": "Old-neighbourhood pocket park", "surface": "sidewalk"},
    {"id": "DEC-BIKE-OLD", "asset": "bike_rack_5", "r": 37.0, "c": 4.6, "yawDeg": 90, "district": "northside", "scene": "Old-neighbourhood pocket park", "surface": "park_or_sidewalk"},

    # Shelters face nearby roads but their complete clearance stays off them.
    {"id": "DEC-SHELTER-DOWNTOWN", "asset": "shelter_transit", "r": 37.0, "c": 8.9, "yawDeg": 90, "district": "northside", "scene": "Old-neighbourhood park east transit stop", "surface": "park_or_sidewalk"},
    {"id": "DEC-SHELTER-INDUSTRIAL", "asset": "shelter_transit", "r": 35.0, "c": 6.5, "yawDeg": 0, "district": "northside", "scene": "Old-neighbourhood park north transit stop", "surface": "park_or_sidewalk"},

    # Four signs for the whole candidate slice; none occupies a drive cell.
    {"id": "DEC-SIGN-PED-DOWNTOWN", "asset": "sign_ped_crossing", "r": 34.6, "c": 74.6, "yawDeg": 0, "district": "downtown", "scene": "Downtown crossing approach", "surface": "sidewalk"},
    {"id": "DEC-SIGN-PED-COUNTRY", "asset": "sign_ped_crossing", "r": 84.6, "c": 44.6, "yawDeg": 0, "district": "industrial", "scene": "Country-industrial crossing approach", "surface": "sidewalk"},
    {"id": "DEC-SIGN-NOPARK-EAST", "asset": "sign_no_parking", "r": 44.6, "c": 104.6, "yawDeg": 0, "district": "eastside", "scene": "Eastside service-corner restriction", "surface": "sidewalk"},
    {"id": "DEC-SIGN-NOPARK-IND", "asset": "sign_no_parking", "r": 94.6, "c": 44.6, "yawDeg": 0, "district": "industrial", "scene": "Industrial service-corner restriction", "surface": "sidewalk"},
]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, value) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")


def parse_glb_json(path: Path):
    raw = path.read_bytes()
    if len(raw) < 20 or raw[:4] != b"glTF":
        raise ValueError(f"{path.name}: invalid GLB magic")
    version, declared = struct.unpack_from("<II", raw, 4)
    if version != 2 or declared != len(raw):
        raise ValueError(f"{path.name}: invalid GLB header")
    offset = 12
    doc = None
    while offset + 8 <= len(raw):
        length, kind = struct.unpack_from("<II", raw, offset)
        offset += 8
        payload = raw[offset : offset + length]
        if len(payload) != length:
            raise ValueError(f"{path.name}: truncated GLB chunk")
        if kind == 0x4E4F534A:
            doc = json.loads(payload.rstrip(b" \t\r\n\0").decode("utf-8"))
        offset += length
    if doc is None or offset != len(raw):
        raise ValueError(f"{path.name}: GLB JSON chunk missing or trailing bytes")
    return doc


def triangle_count(doc) -> int:
    accessors = doc.get("accessors", [])
    total = 0
    for mesh in doc.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            if primitive.get("mode", 4) != 4:
                raise ValueError("non-triangle primitive is outside this package contract")
            accessor_index = primitive.get("indices")
            if accessor_index is None:
                accessor_index = primitive.get("attributes", {}).get("POSITION")
            if accessor_index is None:
                raise ValueError("primitive has neither indices nor positions")
            total += int(accessors[accessor_index]["count"]) // 3
    return total


def clearance_for(catalog_entry, yaw_deg: float, uniform_scale: float = 1.0):
    width_m, depth_m, _height_m = catalog_entry["clearanceM"]
    quarter_turn = int(round(yaw_deg / 90.0)) % 2 == 1
    row_m, col_m = (width_m, depth_m) if quarter_turn else (depth_m, width_m)
    return row_m * uniform_scale / WORLD_UNITS_PER_CELL, col_m * uniform_scale / WORLD_UNITS_PER_CELL


def candidate_obstacles(root: Path):
    # Exact accepted + next-batch pads/corridors are copied as static evidence so
    # the decor contract remains independently auditable without importing game JS.
    repo = root.parents[2]
    accepted = read_json(repo / "assets/buildings/city_v3/accepted_v1/main_native_bindings.v1.json")
    next_batch = read_json(repo / "assets/buildings/city_v3/next_batch_v1/bindings.candidate.v1.json")
    obstacles = []
    for binding in accepted.get("bindings", []):
        obstacles.append({"id": f"building-pad:{binding['key']}", "kind": "building_pad", "polygonGridCR": binding["pad_polygon_grid_cr"]})
        obstacles.append({"id": f"public-door:{binding['key']}", "kind": "door_corridor", "polygonGridCR": binding["public_door"]["corridor_polygon_grid_cr"]})
        obstacles.append({"id": f"service-door:{binding['key']}", "kind": "door_corridor", "polygonGridCR": binding["service_access"]["corridor_polygon_grid_cr"]})
    for binding in next_batch.get("bindings", []):
        obstacles.append({"id": f"candidate-building-pad:{binding['key']}", "kind": "building_pad", "polygonGridCR": binding["pad_polygon_grid_cr"]})
        for role, section in (("public", binding["public_door"]), ("service", binding["service_access"])):
            for index, rect in enumerate(section.get("approach_segments_rect_grid_rc", [])):
                polygon = [
                    [rect["minC"], rect["minR"]],
                    [rect["maxC"], rect["minR"]],
                    [rect["maxC"], rect["maxR"]],
                    [rect["minC"], rect["maxR"]],
                ]
                obstacles.append({"id": f"candidate-{role}-door:{binding['key']}:{index}", "kind": "door_corridor", "polygonGridCR": polygon})
    return obstacles


def build(root: Path, source: Path) -> None:
    evidence = root / "source_evidence"
    models = root / "models"
    source_asset = read_json(source / "civic_park_decor_kit_v2.asset.json")
    source_sha = read_json(source / "civic_park_decor_kit_v2.sha256.json")
    source_validation = read_json(source / "civic_park_decor_kit_v2.validation.json")
    catalog = source_asset["catalog"]

    if len(catalog) != 18 or len(source_asset["runtimeFiles"]) != 57 or len(source_sha["files"]) != 57:
        raise ValueError("source cardinality contract failed")

    validated_files = {record["file"]: record for record in source_validation["files"]}
    glb_files = sorted(source.glob("*.glb"))
    if len(glb_files) != 57:
        raise ValueError(f"expected 57 source GLBs, found {len(glb_files)}")

    independent = []
    per_asset_triangles = {}
    for path in glb_files:
        expected = source_sha["files"].get(path.name)
        if not expected:
            raise ValueError(f"{path.name}: absent from source SHA manifest")
        actual_hash = sha256(path)
        if path.stat().st_size != expected["bytes"] or actual_hash.upper() != expected["sha256"].upper():
            raise ValueError(f"{path.name}: source byte/hash mismatch")
        doc = parse_glb_json(path)
        names = {node.get("name") for node in doc.get("nodes", []) if node.get("name")}
        if doc.get("images") or doc.get("textures"):
            raise ValueError(f"{path.name}: embedded texture/image is not allowed")
        record = validated_files.get(path.name)
        if not record or record.get("pass") is not True:
            raise ValueError(f"{path.name}: reverse-import validation missing")
        triangles = triangle_count(doc)
        independent.append({
            "file": path.name,
            "bytes": path.stat().st_size,
            "sha256": actual_hash,
            "nodes": len(doc.get("nodes", [])),
            "meshes": len(doc.get("meshes", [])),
            "trianglesIndependent": triangles,
            "catalogOnly": path.name.startswith("civic_park_decor_catalog_"),
        })
        for asset_name, entry in catalog.items():
            if path.name not in entry["lodFiles"]:
                continue
            required = [entry["placementSocket"], entry["clearanceSocket"]]
            if entry.get("collisionNode"):
                required.append(entry["collisionNode"])
            if entry.get("waterSocket"):
                required.append(entry["waterSocket"])
            missing = [name for name in required if name not in names]
            if missing:
                raise ValueError(f"{path.name}: missing required nodes {missing}")
            if entry["category"] == "fountain":
                if not any(name.startswith("ANIMATED_SURFACE_") for name in names):
                    raise ValueError(f"{path.name}: animated water surface missing")
                if not any(name.startswith("WATER_JET_SOCKET_") for name in names):
                    raise ValueError(f"{path.name}: water jet socket missing")
            lod = entry["lodFiles"].index(path.name)
            per_asset_triangles.setdefault(asset_name, {})[lod] = triangles

    for asset_name, lods in per_asset_triangles.items():
        if sorted(lods) != [0, 1, 2] or not (lods[0] > lods[1] > lods[2] > 0):
            raise ValueError(f"{asset_name}: independent LOD triangle descent failed: {lods}")

    copied = []
    entries = []
    for asset_name, entry in catalog.items():
        lods = []
        for lod, filename in enumerate(entry["lodFiles"]):
            path = models / filename
            expected = source_sha["files"][filename]
            if not path.is_file() or path.stat().st_size != expected["bytes"] or sha256(path).upper() != expected["sha256"].upper():
                raise ValueError(f"{filename}: copied runtime asset differs from source")
            record = {
                "lod": lod,
                "url": f"./models/{filename}",
                "bytes": path.stat().st_size,
                "sha256": sha256(path),
                "triangles": per_asset_triangles[asset_name][lod],
            }
            lods.append(record)
            copied.append(filename)
        entries.append({
            "key": f"{asset_name}@2",
            "assetId": asset_name,
            "category": entry["category"],
            "footprintM": entry["footprintM"],
            "clearanceM": entry["clearanceM"],
            "requiredNodes": [name for name in [entry["placementSocket"], entry["clearanceSocket"], entry.get("collisionNode"), entry.get("waterSocket")] if name],
            "requiresAnimatedWaterSurface": entry["category"] == "fountain",
            "requiresWaterJetSockets": entry["category"] == "fountain",
            "lods": lods,
        })

    if len(copied) != 54 or len(set(copied)) != 54:
        raise ValueError("runtime copy cardinality failed")

    placements = []
    for item in PLACEMENTS:
        source_entry = catalog[item["asset"]]
        # Gameplay camera feedback: civic silhouettes need stronger presence.
        # The central fountain is capped at 1.22 to keep the enlarged bicycle
        # rack clearance disjoint without moving any accepted placement.
        uniform_scale = (1.22 if item["asset"] == "fountain_central" else
                         1.3 if item["asset"].startswith("fountain_") else
                         1.0 if item["asset"].startswith("sign_") else 1.15)
        clear_r, clear_c = clearance_for(source_entry, item["yawDeg"], uniform_scale)
        placements.append({
            **item,
            "uniformScale": uniform_scale,
            "key": f"{item['asset']}@2",
            "clearanceGridRC": [round(clear_r, 6), round(clear_c, 6)],
            "clearanceAabbGridRC": {
                "minR": round(item["r"] - clear_r / 2, 6),
                "maxR": round(item["r"] + clear_r / 2, 6),
                "minC": round(item["c"] - clear_c / 2, 6),
                "maxC": round(item["c"] + clear_c / 2, 6),
            },
            "focusQuery": f"cityv3decorfocus={item['id']}",
        })

    placement_contract = {
        "schema": SCHEMA_PLACEMENT,
        "revision": 1,
        "status": "READY_STATIC_RUNTIME_WIRE_REQUIRED",
        "runtimeActivation": False,
        "placementAuthorized": False,
        "coordinateSpace": "main_map_row_column",
        "worldUnitsPerGridCellM": WORLD_UNITS_PER_CELL,
        "requiredLocalPreviewQuery": {"preview": "1", "previewcityv3": "stage-a", "cityv3decor": "1"},
        "baseMapContract": {
            "rows": 200,
            "cols": 180,
            "blockCells": 10,
            "westCityParkRule": "((blockR*17 + blockC*31) % 11) in {0,7}",
            "westCityRoadRemainders": [0, 1, 2, 3],
            "westCitySidewalkRemainders": [4, 9],
            "eastExpansionStartC": 100,
            "eastExpansionEndRExclusive": 150,
            "canal": {"minR": 0, "maxR": 149.999, "minC": 80, "maxC": 100},
            "redBridge": {"minR": 47, "maxR": 56, "minC": 80, "maxC": 100},
            "southRailEnvelope": {"minR": 139.0, "maxR": 153.6, "minC": 4.4, "maxC": 176.6},
            "southSeaKeepout": {"minR": 164.0, "maxR": 200, "minC": 0, "maxC": 180},
        },
        "protectedZones": [
            {"id": "police-jail", "shape": "circle", "r": 76, "c": 76, "radius": 8},
            {"id": "premium-red-bridge", "shape": "rect", "minR": 47, "maxR": 56, "minC": 80, "maxC": 100},
        ],
        "buildingAndDoorObstacles": candidate_obstacles(root),
        "densityPolicy": {
            "automaticScatter": False,
            "placementCount": len(placements),
            "fountainCount": 3,
            "pedestrianLightCount": sum(1 for p in placements if p["asset"].startswith("ped_light_")),
            "maxPedestrianLights": 4,
            "notes": "Three authored micro-scenes and two transit edges; no lamp rows and no catalog-layout placement.",
        },
        "placements": placements,
        "focusCoordinates": [{"id": p["id"], "r": p["r"], "c": p["c"], "query": p["focusQuery"]} for p in placements],
        "runtimePreflightRequired": [
            "exact map dimensions and world scale",
            "continuous clearance sampling against live road/water/building masks",
            "SAT against active building pads and public/service door corridors",
            "SAT against active rail/station/crossing masks",
            "protected police/jail and premium red bridge keep-outs",
            "all selected GLBs loaded and hash-validated before one atomic scene attach",
        ],
        "rollback": {
            "atomic": True,
            "sceneRoot": "CITY_V3_CIVIC_PARK_V2_ROOT",
            "removeOnlyThisRoot": True,
            "disposeOwnedGeometryAndMaterials": True,
            "removeRegisteredCollisionHandles": True,
            "mutatesMapTiles": False,
            "suppressesLegacyDecor": False,
            "restoresLegacyStructures": False,
        },
    }
    placement_path = root / "placement.candidate.v1.json"
    write_json(placement_path, placement_contract)

    evidence_records = {}
    for name in ("source.asset.json", "source.validation.json", "source.sha256.json", "SOURCE_HANDOFF.md"):
        path = evidence / name
        evidence_records[name] = {"url": f"./source_evidence/{name}", "bytes": path.stat().st_size, "sha256": sha256(path)}

    source_blend = source / "civic_park_decor_kit_v2.blend"
    proofs = []
    for name in ("civic_park_decor_kit_v2_day.png", "civic_park_decor_kit_v2_night.png", "civic_park_decor_kit_v2_game_camera.png"):
        path = source / name
        proofs.append({"file": name, "bytes": path.stat().st_size, "sha256": sha256(path)})
    source_audit = {
        "schema": "mafiozi.civic-park-decor-source-audit/v1",
        "status": "PASS_WITH_INTERNAL_PROJECT_SCOPE_RESTRICTION",
        "sourceAssetId": source_asset["assetId"],
        "glbCount": len(independent),
        "runtimeGlbCount": sum(not x["catalogOnly"] for x in independent),
        "catalogOnlyGlbCount": sum(x["catalogOnly"] for x in independent),
        "totalGlbBytes": sum(x["bytes"] for x in independent),
        "hashMismatches": 0,
        "reverseImportFailures": 0,
        "lodTriangleDescentFailures": 0,
        "missingSocketFailures": 0,
        "embeddedImageOrTextureFailures": 0,
        "sourceBlend": {"file": source_blend.name, "bytes": source_blend.stat().st_size, "sha256": sha256(source_blend)},
        "proofs": proofs,
        "files": independent,
        "rightsAndProvenance": {
            "sourceBlendDeclared": True,
            "externalRuntimeUrisInGlb": 0,
            "embeddedImagesOrTextures": 0,
            "explicitThirdPartyLicenseFiles": 0,
            "explicitPublicRedistributionGrant": False,
            "allowedScope": "internal_project_staging_only",
            "note": "Technical provenance is self-contained; public redistribution remains fail-closed until an explicit rights declaration is supplied.",
        },
    }
    source_audit_path = root / "SOURCE_AUDIT.v1.json"
    write_json(source_audit_path, source_audit)

    registry = {
        "schema": SCHEMA_REGISTRY,
        "revision": 1,
        "status": "READY_STATIC_RUNTIME_WIRE_REQUIRED",
        "activationPolicy": "explicit_local_preview_only_fail_closed",
        "runtimeActivation": False,
        "catalogGlbsShipped": False,
        "catalogLayoutPlacementForbidden": True,
        "hostThreePolicy": {
            "secondThreeInstanceForbidden": True,
            "threeInjectedByHost": True,
            "gltfLoaderInjectedByHost": True,
            "registryImportsThree": False,
        },
        "rightsScope": {
            "allowed": "internal_project_staging_only",
            "publicRedistributionCleared": False,
            "failClosedOutsideAllowedScope": True,
        },
        "lodPolicy": source_asset["lodPolicy"],
        "sourceEvidence": evidence_records,
        "sourceAudit": {"url": "./SOURCE_AUDIT.v1.json", "bytes": source_audit_path.stat().st_size, "sha256": sha256(source_audit_path)},
        "placementCandidate": {"url": "./placement.candidate.v1.json", "bytes": placement_path.stat().st_size, "sha256": sha256(placement_path)},
        "entries": entries,
        "runtimeGate": {
            "directVersionedKeyOnly": True,
            "requiredRightsScope": "internal_project_staging_only",
            "allFilesHashValidatedBeforeAtomicAttach": True,
            "liveMaskPreflightRequired": True,
            "liveWalkQaRequired": True,
            "failureLeavesSceneAndGameplayUnchanged": True,
        },
    }
    write_json(root / "registry.v1.json", registry)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent
    build(root, args.source.resolve())


if __name__ == "__main__":
    main()
