from __future__ import annotations

import hashlib
import json
import math
import os
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")
REGISTRY_RUNTIME = ROOT / "assets/buildings/city_v3/registry.v1.js"

DEFAULT_OUTPUTS = Path(
    r"C:\Users\Слава\Documents\Codex\2026-09-05\mafiozy-architect-city-replacement\outputs"
)
V1_PATH = Path(
    os.environ.get(
        "MAFIOZI_CITY_PLACEMENT_V1",
        DEFAULT_OUTPUTS
        / "city_building_placement_v1/city_building_placement_v1.contract.json",
    )
)
V2_PATH = Path(
    os.environ.get(
        "MAFIOZI_CITY_PLACEMENT_V2",
        DEFAULT_OUTPUTS
        / "city_building_placement_v2/city_building_placement_v2.contract.json",
    )
)

EPSILON = 1e-7


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def signed_area(polygon):
    return sum(
        polygon[index][0] * polygon[(index + 1) % len(polygon)][1]
        - polygon[(index + 1) % len(polygon)][0] * polygon[index][1]
        for index in range(len(polygon))
    ) / 2


def counter_clockwise(polygon):
    result = [tuple(map(float, point)) for point in polygon]
    return result if signed_area(result) >= 0 else list(reversed(result))


def cross(a, b, c):
    return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])


def axes(polygon):
    result = []
    for start, end in zip(polygon, polygon[1:] + polygon[:1]):
        dx, dy = end[0] - start[0], end[1] - start[1]
        length = math.hypot(dx, dy)
        if length:
            result.append((-dy / length, dx / length))
    return result


def sat_overlap(a, b):
    """Strict positive-area SAT for the convex placement polygons."""
    a, b = counter_clockwise(a), counter_clockwise(b)
    for axis_x, axis_y in axes(a) + axes(b):
        projection_a = [x * axis_x + y * axis_y for x, y in a]
        projection_b = [x * axis_x + y * axis_y for x, y in b]
        if max(projection_a) <= min(projection_b) + EPSILON:
            return False
        if max(projection_b) <= min(projection_a) + EPSILON:
            return False
    return True


def orientation(a, b, c):
    value = cross(a, b, c)
    return 1 if value > EPSILON else -1 if value < -EPSILON else 0


def segments_cross_strict(a, b, c, d):
    return (
        orientation(a, b, c) * orientation(a, b, d) < 0
        and orientation(c, d, a) * orientation(c, d, b) < 0
    )


def point_in_polygon(point, polygon):
    inside = False
    x, y = point
    for a, b in zip(polygon, polygon[1:] + polygon[:1]):
        if (a[1] > y) != (b[1] > y):
            edge_x = a[0] + (y - a[1]) * (b[0] - a[0]) / (b[1] - a[1])
            if edge_x > x:
                inside = not inside
    return inside


def segment_crosses_polygon(start, end, polygon):
    polygon = counter_clockwise(polygon)
    return (
        point_in_polygon(start, polygon)
        or point_in_polygon(end, polygon)
        or any(
            segments_cross_strict(start, end, a, b)
            for a, b in zip(polygon, polygon[1:] + polygon[:1])
        )
    )


def polygon_intersects_general(a, b):
    a, b = counter_clockwise(a), counter_clockwise(b)
    return (
        any(point_in_polygon(point, b) for point in a)
        or any(point_in_polygon(point, a) for point in b)
        or any(
            segments_cross_strict(a0, a1, b0, b1)
            for a0, a1 in zip(a, a[1:] + a[:1])
            for b0, b1 in zip(b, b[1:] + b[:1])
        )
    )


def obb_polygon(row, world_units_per_cell):
    obb = row["obb"]
    center_x, center_z = row["origin_grid"]
    half_x = obb["size_xyz"][0] / world_units_per_cell / 2
    half_z = obb["size_xyz"][2] / world_units_per_cell / 2
    yaw = math.radians(obb["yaw_deg"])
    cosine, sine = math.cos(yaw), math.sin(yaw)
    return counter_clockwise(
        [
            (
                center_x + local_x * cosine + local_z * sine,
                center_z - local_x * sine + local_z * cosine,
            )
            for local_x, local_z in (
                (-half_x, -half_z),
                (half_x, -half_z),
                (half_x, half_z),
                (-half_x, half_z),
            )
        ]
    )


def function_body(source: str, name: str) -> str:
    signature = source.index(f"function {name}(")
    start = source.index("{", signature)
    depth = 0
    quote = None
    escaped = False
    for index in range(start, len(source)):
        char = source[index]
        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = None
            continue
        if char in "'\"`":
            quote = char
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return source[start : index + 1]
    raise AssertionError(f"unterminated function {name}")


class CityBuildingOverlapContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not V1_PATH.is_file() or not V2_PATH.is_file():
            raise unittest.SkipTest(
                "set MAFIOZI_CITY_PLACEMENT_V1/V2 to run the staging geometry gate"
            )
        cls.v1 = json.loads(V1_PATH.read_text(encoding="utf-8"))
        cls.v2 = json.loads(V2_PATH.read_text(encoding="utf-8"))
        cls.world_scale = cls.v2["map"]["world_units_per_cell"]

    def test_contract_bytes_are_the_independently_audited_inputs(self):
        self.assertEqual(
            sha256(V1_PATH),
            "afe4459677228424412e273ec3a32a04cc17b1a3a3c24d4f70d2cafb022ce58c",
        )
        self.assertEqual(
            sha256(V2_PATH),
            "e917883063d0dcc3326ed2ea508f4d3956e10688296d1f063a34c61378bc4c78",
        )

    def test_accepted_bindings_have_no_unexcepted_overlap(self):
        bindings = self.v2["immutable_accepted_v1_bindings"]
        self.assertEqual(len(bindings), 8)
        self.assertEqual(len({item["instance_id"] for item in bindings}), 8)
        replaced_ids = {
            parcel_id
            for binding in bindings
            for parcel_id in binding["source_legacy_parcel_ids"]
        }
        legacy_bodies = {
            row["parcel_id"]: obb_polygon(row, self.world_scale)
            for row in self.v1["building_placements"]
            if row.get("obb") and row["parcel_id"] not in replaced_ids
        }
        civic_bodies = {
            row["dedicated_parcel_id"]: counter_clockwise(row["footprint_grid"])
            for row in self.v2["civic_landmark_placements"]
        }
        static_bodies = {**legacy_bodies, **civic_bodies}
        accepted_pads = {
            item["instance_id"]: counter_clockwise(item["pad"]["polygon_grid"])
            for item in bindings
        }
        roads = []
        for layer in (
            "crossings",
            "arterials",
            "collectors",
            "local_roads",
            "alleys_service",
        ):
            for road in self.v2["roads"][layer]:
                roads.extend(
                    (road["id"], layer, start, end)
                    for start, end in zip(
                        road["points_grid"], road["points_grid"][1:]
                    )
                )
        rails = [
            (edge["id"], start, end)
            for edge in self.v2["rail_placement"]["track_edges"]
            for start, end in zip(edge["points_grid"], edge["points_grid"][1:])
        ]
        platforms = {
            station["id"]: counter_clockwise(station["platform_footprint_grid"])
            for station in self.v2["rail_placement"]["passenger_stations"]
        }
        waters = {
            water["id"]: counter_clockwise(water["polygon_grid"])
            for water in self.v2["water_polygons"]["waterbodies"]
        }
        findings = []
        for binding in bindings:
            instance = binding["instance_id"]
            parts = {
                "body": counter_clockwise(binding["obb"]["footprint_grid"]),
                "pad": accepted_pads[instance],
                "public_door": counter_clockwise(
                    binding["public_door_corridor"]["corridor_polygon_grid"]
                ),
                "service": counter_clockwise(
                    binding["service_access"]["corridor_polygon_grid"]
                ),
            }
            # Only this binding's addressed legacy source may be replaced. All
            # other physical bodies remain hard obstacles.
            source_rows = {
                row["parcel_id"]: obb_polygon(row, self.world_scale)
                for row in self.v1["building_placements"]
                if row.get("obb")
                and row["parcel_id"] in binding["source_legacy_parcel_ids"]
            }
            if not any(
                sat_overlap(parts["pad"], source_body)
                for source_body in source_rows.values()
            ):
                findings.append(f"{instance}:pad>declared-target:none")
            for part_name, part in parts.items():
                for obstacle_id, obstacle in static_bodies.items():
                    if sat_overlap(part, obstacle):
                        findings.append(
                            f"{instance}:{part_name}>building:{obstacle_id}"
                        )
                for other_id, other_pad in accepted_pads.items():
                    if other_id != instance and sat_overlap(part, other_pad):
                        findings.append(f"{instance}:{part_name}>accepted:{other_id}")
                for water_id, water in waters.items():
                    if polygon_intersects_general(part, water):
                        findings.append(f"{instance}:{part_name}>water:{water_id}")
                for rail_id, start, end in rails:
                    if segment_crosses_polygon(start, end, part):
                        findings.append(f"{instance}:{part_name}>rail:{rail_id}")
                for station_id, platform in platforms.items():
                    if sat_overlap(part, platform):
                        findings.append(
                            f"{instance}:{part_name}>platform:{station_id}"
                        )
                allowed_road = None
                if part_name == "public_door":
                    allowed_road = binding["public_door_corridor"]["connects_road_id"]
                elif part_name == "service":
                    allowed_road = binding["service_access"]["connects_road_id"]
                for road_id, layer, start, end in roads:
                    if road_id != allowed_road and segment_crosses_polygon(start, end, part):
                        findings.append(
                            f"{instance}:{part_name}>road:{layer}:{road_id}"
                        )
        findings = sorted(set(findings))
        # The broad v2 package is not a blanket rollout authority. Only the
        # two independently clean assets may advance to MAIN-native binding;
        # every other accepted-v1 candidate must remain gated by at least one
        # concrete geometry finding.
        clean = {"AV1-INST-PAWNSHOP-01", "AV1-INST-PRINT_SHOP-01"}
        blocked = {binding["instance_id"] for binding in bindings} - clean
        self.assertFalse(
            [finding for finding in findings if finding.split(":", 1)[0] in clean],
            "clean rollout pair gained an overlap:\n" + "\n".join(findings),
        )
        finding_instances = {finding.split(":", 1)[0] for finding in findings}
        self.assertEqual(blocked, finding_instances)

    def test_civic_activation_and_legacy_suppression_are_fail_closed(self):
        self.assertTrue(REGISTRY_RUNTIME.is_file())
        runtime = REGISTRY_RUNTIME.read_text(encoding="utf-8")
        install = runtime[runtime.index("export function installCityV3BuildingCandidate") :]
        activation = function_body(WORLD, "_activateCityV3BuildingPreview")
        suppress_part = function_body(WORLD, "_cityV3SuppressLegacyPart")
        suppress_door = function_body(WORLD, "_cityV3SuppressLegacyDoor")

        self.assertLess(install.index("scene.add(candidate.placementRoot)"), install.index("bridge.activateCityV3BuildingPreview"))
        self.assertIn("scene.remove(candidate.placementRoot)", install)
        self.assertIn("receipt?.loaded!==true", activation)
        self.assertIn("receipt?.eligible!==true", activation)
        self.assertIn("receipt?.registered!==true", activation)
        self.assertIn("legacyPart=_cityV3CivicLegacyPart()", activation)
        self.assertLess(activation.index("legacyPart=_cityV3CivicLegacyPart()"), activation.index("_cityV3ActiveCivicPreview=active"))
        self.assertIn("if(!q)return false", suppress_part)
        self.assertIn("if(_cityV3ActiveCivicPreview)", suppress_part)
        self.assertIn("_cityV3ActiveAcceptedBuildings.values()", suppress_part)
        self.assertIn("if(!door)return false", suppress_door)
        self.assertIn("if(_cityV3ActiveCivicPreview)", suppress_door)
        self.assertIn("_cityV3ActiveAcceptedBuildings.values()", suppress_door)
        self.assertLess(
            THREE.index("installCityV3BuildingCandidate("),
            THREE.index("getWorldSnapshot?.(WORLD_SNAPSHOT_RADIUS)"),
        )
        # Corrected bounds extend beyond the 4x4 target. The activation gate
        # must therefore inspect non-target live MAP cells before suppression.
        city_gate = WORLD[
            WORLD.index("function _cityV3CivicLegacyPart") :
            WORLD.index("function _isThreeWholeBuildingBlocked")
        ]
        self.assertIn("function _cityV3CivicPreflight(legacyPart)", city_gate)
        self.assertIn("MAP[", city_gate)
        self.assertIn("tile===1&&!targetTiles.has(key)", city_gate)
        self.assertIn("tile===16", city_gate)
        self.assertIn("tile===0||tile===18||tile===19||inRaceTrack", city_gate)
        self.assertLess(
            activation.index("_cityV3CivicPreflight"),
            activation.index("_cityV3ActiveCivicPreview=active"),
        )


if __name__ == "__main__":
    unittest.main()
