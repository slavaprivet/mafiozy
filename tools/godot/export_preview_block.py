"""Export a deterministic, hash-verified slice of the existing Walk city.

No Walk files or gameplay state are changed. Run with --check to verify that
generated files still reproduce the current source documents and GLBs.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import struct


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/maps/city_rebuild_v1"
PROJECT = ROOT / "godot/mafiozi_walk"
ANCHOR = "REBUILD-VISUAL-print_shop-001"
HELPER = re.compile(
    r"(^|[_\s])(collision|collider|clearance|socket|anchor|keepout|nav|proxy|datum)([_\s]|$)"
    r"|^(COLLISION|SOCKET|CLEARANCE|NAV_|COL_)", re.I)
TILES = {0: ("road", "#525a5a"), 8: ("grass", "#789274"),
         9: ("sidewalk", "#c4c1ab"), 14: ("sand", "#d9c698"),
         16: ("water", "#4f9eb0"), 19: ("bridge", "#858e89")}


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def source_json(name: str) -> tuple[dict, dict]:
    path = SOURCE / name
    raw = path.read_bytes()
    return json.loads(raw.decode("utf-8-sig")), {
        "path": path.relative_to(ROOT).as_posix(), "bytes": len(raw), "sha256": digest(raw)}


def verified_glb(binding: dict) -> tuple[bytes, dict]:
    relative = binding["url"].lstrip("/")
    path = (ROOT / relative).resolve()
    if not path.is_relative_to(ROOT / "assets"):
        raise ValueError(f"Asset path outside repository assets: {relative}")
    raw = path.read_bytes()
    if len(raw) != binding["bytes"] or digest(raw) != binding["sha256"].lower():
        raise ValueError(f"Binding bytes/SHA mismatch: {relative}")
    if len(raw) < 20 or struct.unpack_from("<4sII", raw) != (b"glTF", 2, len(raw)):
        raise ValueError(f"Not a complete glTF 2 binary: {relative}")
    size, kind = struct.unpack_from("<II", raw, 12)
    if kind != 0x4E4F534A:
        raise ValueError(f"Missing GLB JSON chunk: {relative}")
    gltf = json.loads(raw[20:20 + size])
    for entry in gltf.get("buffers", []) + gltf.get("images", []):
        if entry.get("uri") and not entry["uri"].startswith("data:"):
            raise ValueError(f"External GLB dependency requires an explicit exporter: {relative}")
    return raw, gltf


def point_in_polygon(x: float, z: float, polygon: list) -> bool:
    inside = False
    for a, b in zip(polygon, polygon[1:] + polygon[:1]):
        if (a[1] > z) != (b[1] > z) and x < (b[0] - a[0]) * (z - a[1]) / (b[1] - a[1]) + a[0]:
            inside = not inside
    return inside


def segment_distance(x: float, z: float, a: list, b: list) -> float:
    dx, dz = b[0] - a[0], b[1] - a[1]
    denom = dx * dx + dz * dz
    t = max(0.0, min(1.0, ((x-a[0])*dx + (z-a[1])*dz) / denom)) if denom else 0
    return math.hypot(x-a[0]-t*dx, z-a[1]-t*dz)


def export(count: int) -> tuple[dict, dict[str, bytes]]:
    buildings, building_receipt = source_json("buildings_placement.v1.json")
    topology, topology_receipt = source_json("topology_for_placement.json")
    decor, decor_receipt = source_json("decor_placement.v1.json")
    hero, hero_receipt = source_json("hero_walk.manifest.json")
    anchor = next(item for item in buildings["instances"] if item["id"] == ANCHOR)
    origin = anchor["transform"]["positionM"][:]
    cell = buildings["metresPerCell"]
    if cell != topology["map"]["worldUnitsPerCell"]:
        raise ValueError("Building and topology coordinate scales differ")
    selected = sorted(buildings["instances"], key=lambda item: (
        (item["transform"]["positionM"][0] - origin[0])**2 +
        (item["transform"]["positionM"][2] - origin[2])**2, item["id"]))[:count]
    rows, cols = topology["map"]["rows"], topology["map"]["cols"]
    # Bounds are the union of authored footprints plus three actual map cells.
    r0 = max(0, math.floor(min(i["footprint"]["minR"] for i in selected)) - 3)
    r1 = min(rows, math.ceil(max(i["footprint"]["maxR"] for i in selected)) + 3)
    c0 = max(0, math.floor(min(i["footprint"]["minC"] for i in selected)) - 3)
    c1 = min(cols, math.ceil(max(i["footprint"]["maxC"] for i in selected)) + 3)
    nearby_decor = sorted((i for i in decor["instances"]
        if c0 * cell <= i["transform"]["positionM"][0] < c1 * cell
        and r0 * cell <= i["transform"]["positionM"][2] < r1 * cell), key=lambda i: i["id"])
    assets: dict[str, bytes] = {}

    def instance(item: dict, folder: str) -> dict:
        raw, gltf = verified_glb(item["binding"])
        filename = f"{folder}/{item['assetId']}.{digest(raw)[:12]}.glb"
        assets[filename] = raw
        transform = json.loads(json.dumps(item["transform"]))
        transform.setdefault("uniformScale", 1)
        transform.setdefault("horizontalScale", [1, 1])
        transform.setdefault("modelLocalOffsetM", [0, 0, 0])
        transform.setdefault("yawDegrees", 0)
        source_bodies = item.get("collision", {}).get("worldBodies", [])
        converted = []
        for index, body in enumerate(source_bodies):
            polygon = body["polygonCR"]
            if len(polygon) < 3 or "minYM" not in body or "maxYM" not in body:
                raise ValueError(f"Incomplete authored collision body: {item['id']}[{index}]")
            if body["maxYM"] <= body["minYM"]:
                raise ValueError(f"Nonpositive collider height: {item['id']}[{index}]")
            converted.append({"sourceIndex": index, "node": body.get("node"),
                "polygonXZ": [[p[0] * cell-origin[0], p[1] * cell-origin[2]] for p in polygon],
                "minY": body["minYM"]-origin[1], "maxY": body["maxYM"]-origin[1]})
        hidden = sorted(set(item.get("hideNodeNames", [])) | {
            n["name"] for n in gltf.get("nodes", []) if HELPER.search(n.get("name", ""))})
        return {"id": item["id"], "assetId": item["assetId"],
            "role": item.get("role"), "path": "res://assets/" + filename,
            "binding": item["binding"], "transform": transform,
            "positionLocalM": [v-origin[k] for k, v in enumerate(transform["positionM"])],
            "hideNodeNames": item.get("hideNodeNames", []), "effectiveHiddenNodeNames": hidden,
            "collision": item.get("collision", {}), "collisionBodiesM": converted,
            "entry": item.get("entry"), "footprint": item.get("footprint"),
            "gameplayId": item.get("gameplayId"), "gameplayActive": False,
            "sourceGameplayActive": item.get("gameplayActive", False)}

    exported_buildings = [instance(i, "buildings") for i in selected]
    exported_decor = [instance(i, "decor") for i in nearby_decor]
    hero_binding = {k: hero[k] for k in ("url", "sha256", "bytes")}
    hero_raw, hero_gltf = verified_glb(hero_binding)
    assets["hero.glb"] = hero_raw
    masks = ["roadMask", "walkableMask", "protectedMask", "policeMask", "bridgeDeckMask"]
    surface = {"startRow": r0, "startCol": c0, "rows": r1-r0, "cols": c1-c0,
        "cellSize": cell, "sourceMapRows": rows, "sourceMapCols": cols,
        "grid": [row[c0:c1] for row in topology["grid"][r0:r1]],
        "masks": {key: [row[c0:c1] for row in topology[key][r0:r1]] for key in masks},
        "maskSemantics": topology["maskSemantics"],
        "palette": {str(tile): {"kind": kind, "colorSrgb": color,
            "heightM": -0.18 if tile == 16 else 0, "solid": tile != 16}
            for tile, (kind, color) in TILES.items()},
        "protectedColorSrgb": "#9a9990",
        "materialDescriptors": decor.get("materialDescriptors", []),
        "boundsLocalM": {"min": [c0*cell-origin[0], -0.18-origin[1], r0*cell-origin[2]],
                         "max": [c1*cell-origin[0], 0-origin[1], r1*cell-origin[2]]},
        "heightPolicy": "Walk native tile mesh: water -0.18m, other tiles 0m; no exterior landscape export"}
    unknown = {tile for row in surface["grid"] for tile in row} - TILES.keys()
    if unknown:
        raise ValueError(f"Unknown source tile IDs: {unknown}")
    # Spawn is a presentation aid certified against this static exported block.
    # It is not a gameplay teleport or proof of dynamic navigation authority.
    probe = anchor["entry"]["roadProbeRC"]
    px, pz = probe["c"]*cell-origin[0], probe["r"]*cell-origin[2]
    all_bodies = [b for item in exported_buildings+exported_decor for b in item["collisionBodiesM"]]
    radius = 0.45

    def safe(x: float, z: float) -> bool:
        for n in range(16):
            angle = n*math.tau/16
            r = math.floor((z + origin[2] + math.sin(angle)*radius)/cell)
            c = math.floor((x + origin[0] + math.cos(angle)*radius)/cell)
            if not (r0 <= r < r1 and c0 <= c < c1):
                return False
            if not topology["walkableMask"][r][c] or topology["grid"][r][c] == 16:
                return False
        for body in all_bodies:
            if body["maxY"] <= 0.05 or body["minY"] >= 1.9:
                continue
            polygon = body["polygonXZ"]
            if point_in_polygon(x, z, polygon) or any(segment_distance(x, z, a, b) <= radius
                    for a, b in zip(polygon, polygon[1:] + polygon[:1])):
                return False
        return True

    candidates = [(px, pz)]
    for distance in range(1, 21):
        candidates.extend((px+math.cos(n*math.tau/32)*distance,
                           pz+math.sin(n*math.tau/32)*distance) for n in range(32))
    spawn = next(((x, z) for x, z in candidates if safe(x, z)), None)
    if spawn is None:
        raise ValueError("No static, dry, clear preview spawn near authored public approach")
    data = {"schema": "mafiozi.godot.preview-block/v1", "anchorId": ANCHOR,
        "scope": "real authored city excerpt; migration preview; gameplay not migrated",
        "originM": origin, "metresPerCell": cell,
        "coordinateContract": "RH Y-up; local X=source X-origin X, local Z=source Z-origin Z; positive yaw preserved",
        "sources": [building_receipt, topology_receipt, decor_receipt, hero_receipt],
        "sourceStatus": {"placement": buildings.get("status"), "topology": topology.get("status"),
                         "pendingHostSnapshot": topology.get("pendingHostSnapshot")},
        "buildings": exported_buildings, "decor": exported_decor, "surface": surface,
        "hero": {"path": "res://assets/hero.glb", "binding": hero_binding,
            "targetHeightM": hero["targetHeightM"], "scalePolicy": hero["scalePolicy"],
            "animations": [a.get("name", "") for a in hero_gltf.get("animations", [])],
            "spawnLocalM": [spawn[0], 0.05, spawn[1]], "spawnClearanceRadiusM": radius,
            "spawnEvidence": "authored print_shop roadProbeRC, validated against exported dry walkable tiles and static bodies"},
        "counts": {"buildings": len(exported_buildings), "decor": len(exported_decor),
            "uniqueGlbs": len(assets), "collisionBodies": len(all_bodies),
            "surfaceCells": (r1-r0)*(c1-c0)},
        "limitations": ["Source gameplay IDs, ownership, interiors, doors, missions and NPC authority are not activated.",
            "Collision bodies are the original conservative exterior proxies, not dynamic interior geometry.",
            "Only the actual source crop is exported; no invented roads or land beyond its bounds.",
            "Water keeps its source tile identity and has no solid land support; swimming is not migrated.",
            "No measured Godot gameplay FPS or visual parity claim is made by this exporter."]}
    return data, assets


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--count", type=int, default=8)
    parser.add_argument("--check", action="store_true", help="Verify generated outputs without writes")
    args = parser.parse_args()
    if not 6 <= args.count <= 10:
        parser.error("--count must be between 6 and 10")
    data, assets = export(args.count)  # Verify every dependency before writing any output.
    manifest = (json.dumps(data, ensure_ascii=False, indent=2, allow_nan=False) + "\n").encode("utf-8")
    outputs = {PROJECT / "assets" / name: raw for name, raw in assets.items()}
    outputs[PROJECT / "data/block.json"] = manifest
    for path, raw in outputs.items():
        if args.check:
            if not path.exists() or path.read_bytes() != raw:
                raise ValueError(f"Generated output differs: {path.relative_to(ROOT)}")
        elif not path.exists() or path.read_bytes() != raw:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
    print(json.dumps({"result": "verified" if args.check else "exported", **data["counts"],
        "assetBytes": sum(map(len, assets.values())), "blockSha256": digest(manifest),
        "spawnLocalM": data["hero"]["spawnLocalM"]}))


if __name__ == "__main__":
    main()
