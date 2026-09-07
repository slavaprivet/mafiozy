import hashlib
import json
import math
import re
import struct
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent
PACK = ROOT / "assets" / "decor" / "civic_park_v2"
REGISTRY_PATH = PACK / "registry.v1.json"
PLACEMENT_PATH = PACK / "placement.candidate.v1.json"
AUDIT_PATH = PACK / "SOURCE_AUDIT.v1.json"
REGISTRY = json.loads(REGISTRY_PATH.read_text(encoding="utf-8"))
PLACEMENT = json.loads(PLACEMENT_PATH.read_text(encoding="utf-8"))
AUDIT = json.loads(AUDIT_PATH.read_text(encoding="utf-8"))


def file_sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def parse_glb(path):
    raw = path.read_bytes()
    if len(raw) < 20 or raw[:4] != b"glTF":
        raise AssertionError(f"{path.name}: GLB magic")
    version, declared = struct.unpack_from("<II", raw, 4)
    if version != 2 or declared != len(raw):
        raise AssertionError(f"{path.name}: GLB header")
    offset = 12
    doc = None
    while offset + 8 <= len(raw):
        length, kind = struct.unpack_from("<II", raw, offset)
        offset += 8
        payload = raw[offset : offset + length]
        if len(payload) != length:
            raise AssertionError(f"{path.name}: GLB chunk")
        if kind == 0x4E4F534A:
            doc = json.loads(payload.rstrip(b" \t\r\n\0").decode("utf-8"))
        offset += length
    if offset != len(raw) or doc is None:
        raise AssertionError(f"{path.name}: GLB JSON/trailing bytes")
    return doc


def triangle_count(doc):
    total = 0
    accessors = doc.get("accessors", [])
    for mesh in doc.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            if primitive.get("mode", 4) != 4:
                raise AssertionError("non-triangle primitive")
            accessor_index = primitive.get("indices")
            if accessor_index is None:
                accessor_index = primitive.get("attributes", {}).get("POSITION")
            total += accessors[accessor_index]["count"] // 3
    return total


def aabb_polygon_cr(aabb):
    return [
        (aabb["minC"], aabb["minR"]),
        (aabb["maxC"], aabb["minR"]),
        (aabb["maxC"], aabb["maxR"]),
        (aabb["minC"], aabb["maxR"]),
    ]


def polygons_overlap_sat(a, b, epsilon=1e-9):
    def axes(poly):
        for index, point in enumerate(poly):
            nxt = poly[(index + 1) % len(poly)]
            edge = (nxt[0] - point[0], nxt[1] - point[1])
            length = math.hypot(*edge)
            if length > epsilon:
                yield (-edge[1] / length, edge[0] / length)

    for axis in list(axes(a)) + list(axes(b)):
        pa = [point[0] * axis[0] + point[1] * axis[1] for point in a]
        pb = [point[0] * axis[0] + point[1] * axis[1] for point in b]
        if max(pa) <= min(pb) + epsilon or max(pb) <= min(pa) + epsilon:
            return False
    return True


def east_surface(ri, ci):
    lr, lc = ri % 20, (ci - 100) % 20
    if lr <= 3 or lc <= 3:
        return "road"
    if lr == 4 or lc == 4 or lr == 19 or lc == 19:
        return "sidewalk"
    vertical = ((ri // 20 + (ci - 100) // 20) & 1) == 1
    a, b = (lc, lr) if vertical else (lr, lc)
    bulb = math.hypot(a - 11, b - 14)
    if (10 <= a <= 12 and b <= 14) or bulb <= 3.05:
        return "road"
    if ((a in (9, 13) and b <= 14) or (3.05 < bulb <= 4.15)):
        return "sidewalk"
    if (((6 <= a <= 8) or (14 <= a <= 16)) and b == 5):
        return "road"
    if (((6 <= a <= 8) or (14 <= a <= 16)) and 6 <= b <= 8):
        return "road" if ((a + b + ri // 20) & 1) == 0 else "sidewalk"
    if b in (9, 13, 14):
        return "sidewalk"
    if 15 <= b <= 18 and 9 <= a <= 13:
        return "park"
    side_lot = (5 <= a <= 7) or (15 <= a <= 18)
    building_lot = (10 <= b <= 12) or (15 <= b <= 18)
    return "building" if side_lot and building_lot else "sidewalk"


def base_surface(r, c):
    ri, ci = math.floor(r), math.floor(c)
    if ri < 0 or ri >= 200 or ci < 0 or ci >= 180:
        return "protected"
    if ri in (0, 199) or ci in (0, 179):
        return "building"
    if ci >= 80 and ci < 100 and ri < 150:
        return "road" if 47 <= ri < 56 else "water"
    if ci >= 100 and ri < 150:
        return east_surface(ri, ci)
    if ri % 10 <= 3 or ci % 10 <= 3:
        return "road"
    if ri % 10 in (4, 9) or ci % 10 in (4, 9):
        return "sidewalk"
    br, bc = ri // 10, ci // 10
    return "park" if ((br * 17 + bc * 31) % 11) in (0, 7) else "building"


def sample_aabb(aabb, step=0.08):
    rows = max(1, math.ceil((aabb["maxR"] - aabb["minR"]) / step))
    cols = max(1, math.ceil((aabb["maxC"] - aabb["minC"]) / step))
    for ri in range(rows + 1):
        for ci in range(cols + 1):
            yield (
                aabb["minR"] + (aabb["maxR"] - aabb["minR"]) * ri / rows,
                aabb["minC"] + (aabb["maxC"] - aabb["minC"]) * ci / cols,
            )


class CivicParkDecorStaticPackageTests(unittest.TestCase):
    def test_source_audit_covers_all_57_glbs_and_rights_scope_is_honest(self):
        self.assertEqual(AUDIT["status"], "PASS_WITH_INTERNAL_PROJECT_SCOPE_RESTRICTION")
        self.assertEqual(AUDIT["glbCount"], 57)
        self.assertEqual(AUDIT["runtimeGlbCount"], 54)
        self.assertEqual(AUDIT["catalogOnlyGlbCount"], 3)
        self.assertEqual(AUDIT["hashMismatches"], 0)
        self.assertEqual(AUDIT["reverseImportFailures"], 0)
        self.assertEqual(AUDIT["lodTriangleDescentFailures"], 0)
        self.assertEqual(AUDIT["missingSocketFailures"], 0)
        self.assertEqual(AUDIT["embeddedImageOrTextureFailures"], 0)
        self.assertEqual(len(AUDIT["files"]), 57)
        rights = AUDIT["rightsAndProvenance"]
        self.assertEqual(rights["allowedScope"], "internal_project_staging_only")
        self.assertFalse(rights["explicitPublicRedistributionGrant"])
        self.assertEqual(rights["externalRuntimeUrisInGlb"], 0)

    def test_registry_and_evidence_are_exactly_hash_pinned(self):
        self.assertEqual(REGISTRY["schema"], "mafiozi.civic-park-decor-registry/v1")
        self.assertEqual(REGISTRY["status"], "READY_STATIC_RUNTIME_WIRE_REQUIRED")
        self.assertFalse(REGISTRY["runtimeActivation"])
        self.assertFalse(REGISTRY["catalogGlbsShipped"])
        self.assertTrue(REGISTRY["catalogLayoutPlacementForbidden"])
        self.assertEqual(len(REGISTRY["entries"]), 18)
        self.assertEqual(REGISTRY["placementCandidate"]["bytes"], PLACEMENT_PATH.stat().st_size)
        self.assertEqual(REGISTRY["placementCandidate"]["sha256"], file_sha256(PLACEMENT_PATH))
        self.assertEqual(REGISTRY["sourceAudit"]["bytes"], AUDIT_PATH.stat().st_size)
        self.assertEqual(REGISTRY["sourceAudit"]["sha256"], file_sha256(AUDIT_PATH))
        for record in REGISTRY["sourceEvidence"].values():
            path = PACK / record["url"].removeprefix("./")
            self.assertEqual(record["bytes"], path.stat().st_size)
            self.assertEqual(record["sha256"], file_sha256(path))

    def test_54_runtime_glbs_hashes_nodes_textures_and_lods(self):
        seen = set()
        for entry in REGISTRY["entries"]:
            self.assertEqual([record["lod"] for record in entry["lods"]], [0, 1, 2])
            triangles = []
            for record in entry["lods"]:
                path = PACK / record["url"].removeprefix("./")
                self.assertTrue(path.is_file())
                self.assertNotIn(path.name, seen)
                seen.add(path.name)
                self.assertEqual(path.stat().st_size, record["bytes"])
                self.assertEqual(file_sha256(path), record["sha256"])
                doc = parse_glb(path)
                self.assertFalse(doc.get("images"), path.name)
                self.assertFalse(doc.get("textures"), path.name)
                names = [node.get("name") for node in doc.get("nodes", []) if node.get("name")]
                for name in entry["requiredNodes"]:
                    self.assertEqual(names.count(name), 1, f"{path.name}: {name}")
                if entry["requiresAnimatedWaterSurface"]:
                    self.assertTrue(any(name.startswith("ANIMATED_SURFACE_") for name in names), path.name)
                if entry["requiresWaterJetSockets"]:
                    self.assertTrue(any(name.startswith("WATER_JET_SOCKET_") for name in names), path.name)
                actual_triangles = triangle_count(doc)
                self.assertEqual(actual_triangles, record["triangles"], path.name)
                triangles.append(actual_triangles)
            self.assertGreater(triangles[0], triangles[1], entry["key"])
            self.assertGreater(triangles[1], triangles[2], entry["key"])
        self.assertEqual(len(seen), 54)
        self.assertFalse(any(name.startswith("civic_park_decor_catalog_") for name in seen))

    def test_registry_module_uses_only_injected_host_three_and_is_static_only(self):
        source = (PACK / "registry.v1.js").read_text(encoding="utf-8")
        self.assertNotRegex(source, r"\bimport\s*\(")
        self.assertNotIn("cdn.jsdelivr.net/npm/three", source)
        self.assertIn("GLTFLoader", source)
        self.assertIn("gltf.scene instanceof THREE.Object3D", source)
        self.assertNotIn("installCivicPark", source)
        self.assertIn("READY_STATIC_RUNTIME_WIRE_REQUIRED", source)
        self.assertIn("internal_project_staging_only", source)
        sha_match = re.search(r"CIVIC_PARK_V2_REGISTRY_SHA256 = '([0-9a-f]{64})'", source)
        bytes_match = re.search(r"CIVIC_PARK_V2_REGISTRY_BYTES = (\d+)", source)
        self.assertIsNotNone(sha_match)
        self.assertIsNotNone(bytes_match)
        self.assertEqual(sha_match.group(1), file_sha256(REGISTRY_PATH))
        self.assertEqual(int(bytes_match.group(1)), REGISTRY_PATH.stat().st_size)

    def test_placement_ids_coordinates_and_fountain_variety(self):
        self.assertEqual(PLACEMENT["schema"], "mafiozi.civic-park-decor-placement-candidate/v1")
        self.assertEqual(PLACEMENT["status"], "READY_STATIC_RUNTIME_WIRE_REQUIRED")
        self.assertFalse(PLACEMENT["runtimeActivation"])
        self.assertFalse(PLACEMENT["placementAuthorized"])
        placements = PLACEMENT["placements"]
        self.assertEqual(PLACEMENT["densityPolicy"]["placementCount"], len(placements))
        self.assertEqual(len({item["id"] for item in placements}), len(placements))
        self.assertEqual(len({(item["r"], item["c"]) for item in placements}), len(placements))
        fountains = [item for item in placements if item["asset"].startswith("fountain_")]
        self.assertEqual(len(fountains), 3)
        self.assertEqual({item["asset"] for item in fountains}, {"fountain_central", "fountain_district", "fountain_park"})
        self.assertEqual({item["district"] for item in fountains}, {"northside", "downtown", "southside"})
        focuses = {item["id"]: (item["r"], item["c"], item["focusQuery"]) for item in placements}
        self.assertEqual(len(PLACEMENT["focusCoordinates"]), len(placements))
        for focus in PLACEMENT["focusCoordinates"]:
            self.assertEqual((focus["r"], focus["c"], focus["query"]), focuses[focus["id"]])

    def test_continuous_clearance_is_off_roads_water_and_buildings(self):
        allowed = {"park", "sidewalk"}
        for placement in PLACEMENT["placements"]:
            surfaces = {base_surface(r, c) for r, c in sample_aabb(placement["clearanceAabbGridRC"])}
            self.assertTrue(surfaces <= allowed, f"{placement['id']}: {surfaces}")

    def test_candidate_clearances_do_not_overlap_each_other(self):
        placements = PLACEMENT["placements"]
        for index, left in enumerate(placements):
            a = aabb_polygon_cr(left["clearanceAabbGridRC"])
            for right in placements[index + 1 :]:
                b = aabb_polygon_cr(right["clearanceAabbGridRC"])
                self.assertFalse(polygons_overlap_sat(a, b), f"{left['id']} overlaps {right['id']}")

    def test_transit_shelters_use_corrected_old_park_anchors(self):
        by_id = {item['id']: item for item in PLACEMENT['placements']}
        east = by_id['DEC-SHELTER-DOWNTOWN']
        north = by_id['DEC-SHELTER-INDUSTRIAL']
        self.assertEqual((east['r'], east['c'], east['yawDeg']), (37.0, 8.9, 90))
        self.assertEqual((north['r'], north['c'], north['yawDeg']), (35.0, 6.5, 0))
        self.assertEqual(east['district'], 'northside')
        self.assertEqual(north['district'], 'northside')
        kiosk = by_id['DEC-KIOSK-OLD']['clearanceAabbGridRC']
        self.assertGreater(east['clearanceAabbGridRC']['minC'], kiosk['maxC'])
        self.assertLess(north['clearanceAabbGridRC']['maxR'], kiosk['minR'])
        for placement in (east, north):
            rect = placement['clearanceAabbGridRC']
            self.assertGreaterEqual(rect['minR'], 34)
            self.assertLess(rect['maxR'], 40)
            self.assertGreaterEqual(rect['minC'], 4)
            self.assertLess(rect['maxC'], 10)

    def test_visual_scale_expands_full_clearance_not_only_meshes(self):
        entries = {entry['key']: entry for entry in REGISTRY['entries']}
        for placement in PLACEMENT['placements']:
            asset = placement['asset']
            expected = 1.22 if asset == 'fountain_central' else 1.3 if asset.startswith('fountain_') else 1.0 if asset.startswith('sign_') else 1.15
            self.assertEqual(placement['uniformScale'], expected, placement['id'])
            width, depth, _ = entries[placement['key']]['clearanceM']
            row, col = (width, depth) if placement['yawDeg'] % 180 == 90 else (depth, width)
            self.assertAlmostEqual(placement['clearanceGridRC'][0], row * expected / 4.1, places=6)
            self.assertAlmostEqual(placement['clearanceGridRC'][1], col * expected / 4.1, places=6)
            rect = placement['clearanceAabbGridRC']
            self.assertAlmostEqual(rect['maxR'] - rect['minR'], row * expected / 4.1, places=5)
            self.assertAlmostEqual(rect['maxC'] - rect['minC'], col * expected / 4.1, places=5)

    def test_sat_avoids_active_and_candidate_building_door_obstacles(self):
        obstacles = PLACEMENT["buildingAndDoorObstacles"]
        self.assertGreaterEqual(len(obstacles), 15)
        for placement in PLACEMENT["placements"]:
            candidate = aabb_polygon_cr(placement["clearanceAabbGridRC"])
            for obstacle in obstacles:
                polygon = [tuple(point) for point in obstacle["polygonGridCR"]]
                self.assertFalse(polygons_overlap_sat(candidate, polygon), f"{placement['id']} overlaps {obstacle['id']}")

    def test_no_police_red_bridge_water_or_rail_intersection(self):
        base = PLACEMENT["baseMapContract"]
        rectangles = [base["canal"], base["redBridge"], base["southRailEnvelope"], base["southSeaKeepout"]]
        police = next(zone for zone in PLACEMENT["protectedZones"] if zone["id"] == "police-jail")
        for placement in PLACEMENT["placements"]:
            aabb = placement["clearanceAabbGridRC"]
            polygon = aabb_polygon_cr(aabb)
            for rect in rectangles:
                self.assertFalse(polygons_overlap_sat(polygon, aabb_polygon_cr(rect)), placement["id"])
            nearest_r = min(max(police["r"], aabb["minR"]), aabb["maxR"])
            nearest_c = min(max(police["c"], aabb["minC"]), aabb["maxC"])
            self.assertGreater(math.hypot(nearest_r - police["r"], nearest_c - police["c"]), police["radius"], placement["id"])

    def test_light_density_is_deliberately_sparse(self):
        lights = [item for item in PLACEMENT["placements"] if item["asset"].startswith("ped_light_")]
        self.assertEqual(len(lights), PLACEMENT["densityPolicy"]["pedestrianLightCount"])
        self.assertLessEqual(len(lights), PLACEMENT["densityPolicy"]["maxPedestrianLights"])
        self.assertLessEqual(len(lights), 4)
        for index, left in enumerate(lights):
            for right in lights[index + 1 :]:
                self.assertGreaterEqual(math.hypot(left["r"] - right["r"], left["c"] - right["c"]), 4.0)

    def test_rollback_is_atomic_and_non_destructive(self):
        rollback = PLACEMENT["rollback"]
        self.assertTrue(rollback["atomic"])
        self.assertTrue(rollback["removeOnlyThisRoot"])
        self.assertTrue(rollback["disposeOwnedGeometryAndMaterials"])
        self.assertTrue(rollback["removeRegisteredCollisionHandles"])
        self.assertFalse(rollback["mutatesMapTiles"])
        self.assertFalse(rollback["suppressesLegacyDecor"])
        self.assertFalse(rollback["restoresLegacyStructures"])


if __name__ == "__main__":
    unittest.main()
