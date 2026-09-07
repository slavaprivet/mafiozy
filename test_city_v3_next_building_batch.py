"""Fail-closed static acceptance checks for the next City V3 building slice.

This suite intentionally does not activate assets or suppress legacy geometry.  It
proves immutable art identity, exact authored entrance transforms, and placement
geometry against the frozen MAIN-native runtime snapshot.  A fresh live runtime
preflight remains mandatory after the rail handoff and before activation.
"""

from __future__ import annotations

import hashlib
import json
import math
import os
from pathlib import Path
import struct
import subprocess
import unittest


ROOT = Path(__file__).resolve().parent
NEXT = ROOT / "assets" / "buildings" / "city_v3" / "next_batch_v1"
ACCEPTED = ROOT / "assets" / "buildings" / "city_v3" / "accepted_v1"
BINDINGS_PATH = NEXT / "bindings.candidate.v1.json"
REGISTRY_PATH = NEXT / "registry.v1.json"
AUDIT_PATH = NEXT / "audit.v1.json"

DEFAULT_ADDENDUM = Path(
    r"C:\Users\Слава\Documents\Codex\2026-09-05\mafiozy-architect-city-replacement\outputs\city_building_placement_v3_main_native_addendum_v1"
)
ADDENDUM = Path(os.environ.get("MAFIOZI_CITY_V3_MAIN_NATIVE_ADDENDUM", DEFAULT_ADDENDUM))
ADDENDUM_CONTRACT = ADDENDUM / "city_building_placement_v3_main_native_addendum_v1.contract.json"
RUNTIME_SNAPSHOT = ADDENDUM / "runtime_snapshot.json"

DEFAULT_ACCEPTED_RELEASE = Path(
    r"C:\Users\Слава\Documents\Codex\2026-09-02\mafiozy-prog10\work\release_stage_accepted_buildings_v3_20260902"
)
ACCEPTED_RELEASE = Path(os.environ.get("MAFIOZI_ACCEPTED_BUILDING_RELEASE", DEFAULT_ACCEPTED_RELEASE))
ACCEPTED_RELEASE_MANIFEST = ACCEPTED_RELEASE / "assets" / "buildings" / "skins" / "accepted_v1" / "manifest.json"

DEFAULT_WRAPPER_PACKAGE = Path(
    r"C:\Users\Слава\Documents\Codex\2026-09-05\mafiozy-architect-shops-replacement\outputs\main_native_all10_missing_business_facades_v1"
)
WRAPPER_PACKAGE = Path(os.environ.get("MAFIOZI_MAIN_NATIVE_FACADE_PACKAGE", DEFAULT_WRAPPER_PACKAGE))
WRAPPER_MANIFEST = WRAPPER_PACKAGE / "main_native_all10_missing_business_facades_v1.package_manifest.json"

EXPECTED_KEYS = ("gun_shop@1", "bookmaker@1", "strip_club@1")
EPSILON = 1e-7


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def glb_json(path: Path):
    body = path.read_bytes()
    magic, version, declared = struct.unpack_from("<III", body, 0)
    if (magic, version, declared) != (0x46546C67, 2, len(body)):
        raise AssertionError(f"invalid GLB envelope: {path}")
    length, kind = struct.unpack_from("<II", body, 12)
    if kind != 0x4E4F534A:
        raise AssertionError(f"first GLB chunk is not JSON: {path}")
    return json.loads(body[20 : 20 + length])


def overlaps(left, right) -> bool:
    return (
        left["minR"] < right["maxR"] - EPSILON
        and left["maxR"] > right["minR"] + EPSILON
        and left["minC"] < right["maxC"] - EPSILON
        and left["maxC"] > right["minC"] + EPSILON
    )


def point_rect_distance(point, rect) -> float:
    return math.hypot(
        max(rect["minR"] - point["r"], 0.0, point["r"] - rect["maxR"]),
        max(rect["minC"] - point["c"], 0.0, point["c"] - rect["maxC"]),
    )


def rect_cells(rect):
    for row in range(math.floor(rect["minR"]), math.ceil(rect["maxR"])):
        for col in range(math.floor(rect["minC"]), math.ceil(rect["maxC"])):
            yield row, col


def polygon_rect(polygon_cr):
    cols = [float(point[0]) for point in polygon_cr]
    rows = [float(point[1]) for point in polygon_cr]
    return {"minR": min(rows), "maxR": max(rows), "minC": min(cols), "maxC": max(cols)}


class CityV3NextBuildingBatchTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        for required in (BINDINGS_PATH, REGISTRY_PATH, AUDIT_PATH, ADDENDUM_CONTRACT, RUNTIME_SNAPSHOT, ACCEPTED_RELEASE_MANIFEST, WRAPPER_MANIFEST):
            if not required.is_file():
                raise AssertionError(f"required acceptance evidence is missing: {required}")
        cls.bindings_doc = load(BINDINGS_PATH)
        cls.bindings = {item["key"]: item for item in cls.bindings_doc["bindings"]}
        cls.registry = load(REGISTRY_PATH)
        cls.audit = load(AUDIT_PATH)
        cls.contract = load(ADDENDUM_CONTRACT)
        cls.snapshot = load(RUNTIME_SNAPSHOT)
        cls.release = load(ACCEPTED_RELEASE_MANIFEST)
        cls.wrapper_package = load(WRAPPER_MANIFEST)

    def test_scope_is_exactly_three_and_runtime_is_inactive(self):
        self.assertEqual(tuple(self.bindings), EXPECTED_KEYS)
        self.assertEqual(tuple(entry["key"] for entry in self.registry["entries"]), EXPECTED_KEYS)
        self.assertEqual(self.bindings_doc["status"], "CORRECTED_STATIC_SAT_PASS_RUNTIME_INACTIVE_LIVE_PROBE_REQUIRED")
        self.assertFalse(self.bindings_doc["runtime_activation"])
        self.assertFalse(self.bindings_doc["legacy_suppression"])
        self.assertTrue(self.bindings_doc["atomic_apply_policy"]["all_three_assets_required"])
        self.assertTrue(self.bindings_doc["atomic_apply_policy"]["partial_legacy_suppression_forbidden"])
        self.assertTrue(self.bindings_doc["atomic_apply_policy"]["failure_keeps_every_legacy_structure_and_door"])
        candidate = self.registry["bindings_candidate"]
        self.assertEqual(candidate["bytes"], BINDINGS_PATH.stat().st_size)
        self.assertEqual(candidate["sha256"], sha(BINDINGS_PATH))
        self.assertEqual(self.audit["registry_sha256"], sha(REGISTRY_PATH))
        self.assertEqual(self.audit["bindings_candidate"]["sha256"], sha(BINDINGS_PATH))
        for entry in self.registry["entries"]:
            self.assertFalse(entry["runtime_activation"])
            self.assertFalse(entry["legacy_suppression"])
            for field in ("manifest", "asset", "sidecar"):
                record = entry[field]
                path = NEXT / record["url"].removeprefix("./")
                self.assertEqual(path.stat().st_size, record["bytes"], path)
                self.assertEqual(sha(path), record["sha256"], path)

        world = (ROOT / "world.html").read_text(encoding="utf-8")
        three = (ROOT / "three_preview.js").read_text(encoding="utf-8")
        # The immutable source snapshot remains inactive metadata. A separate
        # executable integration now consumes it through a host transaction.
        self.assertIn("function _activateCityV3NextBuilding(receipt)", world)
        self.assertIn("next_batch_v1/runtime.v1.js", three)
        self.assertLess(three.index("cityV3NextInstance=await Promise.race"),
                        three.index("const worldSnapshot=bridge?.getWorldSnapshot"))

    def test_exact_immutable_assets_sidecars_and_accepted_release(self):
        expected = {
            "gun_shop": {
                "asset": ("gun_shop.e97d6fac4097.glb", 1568892, "e97d6fac4097af61eaf45ad79d84caf5eadf5f167d3ff3acebfae72ff42d9755"),
                "sidecar": ("gun_shop.d8855a9a0ec6.asset.json", 828, "d8855a9a0ec60e57fcf3fdfa966eccff8117a665004063fa18d8bdc89ce91303"),
            },
            "bookmaker": {
                "asset": ("bookmaker.cf7da54c2037.glb", 1218304, "cf7da54c2037182ca975bf5d08c291a8c7a41e7a1107c7f223b5522468ce8d70"),
                "sidecar": ("bookmaker.dc83704901c9.asset.json", 621, "dc83704901c9c317b73ffeb21bbd106d1a720edfa3948785e726596f112f7e99"),
            },
            "strip_club": {
                "asset": ("strip_club.a29f4603767b.glb", 978332, "a29f4603767b74b71baae3d42c4cbd44e7831b90634bc1bfa7dbfe23e3f4272c"),
                "sidecar": ("strip_club.9ee63b05a351.asset.json", 819, "9ee63b05a351501b706e72d882d5537305607c2b3c2864b98837fb24dd16964a"),
            },
        }
        self.assertEqual(sha(ACCEPTED_RELEASE_MANIFEST), "687d2ff4927a43859100c6b8475138664e67839781bdd00789e206f3e4e2612d")
        release_assets = self.release["assets"]
        for role, evidence in expected.items():
            manifest = load(NEXT / role / "v1" / "manifest.v1.json")
            asset_name, asset_bytes, asset_sha = evidence["asset"]
            sidecar_name, sidecar_bytes, sidecar_sha = evidence["sidecar"]
            asset = NEXT / role / "v1" / asset_name
            sidecar = NEXT / role / "v1" / sidecar_name
            self.assertEqual((asset.stat().st_size, sha(asset)), (asset_bytes, asset_sha))
            self.assertEqual((sidecar.stat().st_size, sha(sidecar)), (sidecar_bytes, sidecar_sha))
            self.assertEqual(manifest["asset"]["sha256"], asset_sha)
            self.assertEqual(manifest["asset"]["sidecar_sha256"], sidecar_sha)
            self.assertEqual(manifest["provenance"]["origin"], "project_generated")
            self.assertEqual(manifest["provenance"]["external_sources"], [])
            self.assertEqual(manifest["provenance"]["usage"], "internal_project_asset")
            self.assertEqual(release_assets[role]["bytes"], asset_bytes)
            self.assertEqual(release_assets[role]["sha256"].lower(), asset_sha)
            self.assertEqual(release_assets[role]["front"], "+Z")
            self.assertEqual(release_assets[role]["entrance"], manifest["geometry"]["public_anchor_local_xyz_m"])

    def test_glbs_have_exact_authored_visual_and_service_nodes(self):
        for key, binding in self.bindings.items():
            role = key.split("@")[0]
            manifest = load(NEXT / role / "v1" / "manifest.v1.json")
            gltf = glb_json(NEXT / role / "v1" / manifest["asset"]["file"])
            named = {node.get("name"): node for node in gltf["nodes"] if node.get("name")}
            self.assertTrue(set(manifest["geometry"]["public_door_visual_nodes"]).issubset(named))
            service_name = manifest["geometry"]["service_door_node"]
            self.assertIn(service_name, named)
            for actual, expected in zip(named[service_name]["translation"], manifest["geometry"]["service_anchor_local_xyz_m"]):
                self.assertAlmostEqual(float(actual), float(expected), delta=1e-5)
            root_node = manifest["geometry"]["root_node"]
            if root_node:
                self.assertIn(root_node, named)
                self.assertTrue(named[root_node].get("children"))
            self.assertTrue(all("uri" not in buffer for buffer in gltf.get("buffers", [])), role)
            self.assertFalse(gltf.get("images"), role)
            self.assertEqual(binding["service_access"]["authored_node"], service_name)

    def test_fresh_main_native_wrappers_are_a_negative_control_for_current_loader(self):
        self.assertEqual(sha(WRAPPER_MANIFEST), "a7a3065369aa44a6d8c8444a0ad73943fe178cc935db2b30f42838666fdf6141")
        self.assertFalse(self.wrapper_package["main_safety"]["snapshot_match_at_audit"])
        self.assertTrue(self.wrapper_package["main_safety"]["hash_gate_required_before_any_future_apply"])
        accepted_runtime = (ACCEPTED / "registry.v1.js").read_text(encoding="utf-8")
        self.assertIn("CITY_V3_ACCEPTED_KEYS=Object.freeze(['pawnshop@1','print_shop@1'])", accepted_runtime)
        self.assertIn("unsupported or duplicate keys", accepted_runtime)

        expected = {
            "gun_shop": ("Armored delivery shutter", 0.162535, 9.245553, 1.390942),
            "bookmaker": ("Employee door", 0.225797, 9.250341, 1.387257),
            "strip_club": ("Service_Door", 0.170580, 6.658368, 0.995954),
            "poker_club": ("Cash_Service_Door", 0.065218, 5.914981, 0.949564),
            "chop_shop": ("Rear burgundy service door", 0.096829, 1.989244, 0.426637),
        }
        wrapper_entries = {item["key"]: item for item in self.wrapper_package["assets"]}
        for role, (service_node, expected_public_error, expected_local_service_delta, expected_service_error) in expected.items():
            record = wrapper_entries[role]["glb"]
            wrapper = WRAPPER_PACKAGE / record["path"]
            self.assertEqual((wrapper.stat().st_size, sha(wrapper)), (record["bytes"], record["sha256"]))
            wrapper_manifest = load(WRAPPER_PACKAGE / role / f"{role}_main_native_facade_v1.manifest.json")
            gltf = glb_json(wrapper)
            named = {node.get("name"): node for node in gltf["nodes"] if node.get("name")}
            public_socket = named["SOCKET_PUBLIC_DOOR"]
            service_socket = named["SOCKET_SERVICE"]
            self.assertIn(service_node, named)
            placement = wrapper_manifest["placement_binding"]
            bounds = wrapper_manifest["asset_contract"]["bounds"]
            center_x = (bounds["min_xyz"][0] + bounds["max_xyz"][0]) / 2
            center_z = (bounds["min_xyz"][2] + bounds["max_xyz"][2]) / 2
            yaw = math.radians(placement["yaw_deg"])

            def loader_anchor(local):
                x_cells = (local[0] - center_x) * placement["uniform_scale"] / 4.1
                z_cells = (local[2] - center_z) * placement["uniform_scale"] / 4.1
                return [
                    placement["center_grid_rc"][0] - x_cells * math.sin(yaw) + z_cells * math.cos(yaw),
                    placement["center_grid_rc"][1] + x_cells * math.cos(yaw) + z_cells * math.sin(yaw),
                ]

            # Wrapper socket extras copied the addendum's origin-based anchor.  The
            # current accepted loader recenters by the horizontal bounds center.
            public_actual = loader_anchor(public_socket["translation"])
            public_declared = public_socket["extras"]["anchor_rc"]
            self.assertAlmostEqual(math.dist(public_declared, public_actual), expected_public_error, delta=1e-6, msg=role)
            self.assertGreater(expected_public_error, 0.015, role)

            # The fresh wrapper's rear-center service socket is not the real visible
            # service entrance in the accepted source art.
            service_visual = named[service_node]["translation"]
            horizontal_service_delta = math.hypot(
                service_socket["translation"][0] - service_visual[0],
                service_socket["translation"][2] - service_visual[2],
            )
            self.assertAlmostEqual(horizontal_service_delta, expected_local_service_delta, delta=1e-5, msg=role)
            service_actual = loader_anchor(service_visual)
            service_declared = service_socket["extras"]["anchor_rc"]
            self.assertAlmostEqual(math.dist(service_declared, service_actual), expected_service_error, delta=1e-6, msg=role)
            self.assertGreater(expected_service_error, 0.015, role)

            if f"{role}@1" in self.bindings:
                binding = self.bindings[f"{role}@1"]
                for actual, wanted in zip(public_actual, binding["public_door"]["exact_anchor_grid_rc"]):
                    self.assertAlmostEqual(actual, wanted, delta=1e-6)
                for actual, wanted in zip(service_actual, binding["service_access"]["exact_anchor_grid_rc"]):
                    self.assertAlmostEqual(actual, wanted, delta=1e-6)

    def test_public_and_service_anchors_include_horizontal_recenter(self):
        addendum = {item["key"]: item for item in self.contract["placements"]}
        for key, binding in self.bindings.items():
            role = key.split("@")[0]
            manifest = load(NEXT / role / "v1" / "manifest.v1.json")
            center_x, _, center_z = manifest["geometry"]["horizontal_center_xyz_m"]
            yaw = math.radians(binding["yaw_deg"])
            for target_name, local_name in (("public_door", "public_anchor_local_xyz_m"), ("service_access", "service_anchor_local_xyz_m")):
                local_x, _, local_z = manifest["geometry"][local_name]
                x_cells = (local_x - center_x) * binding["uniform_asset_scale"] / 4.1
                z_cells = (local_z - center_z) * binding["uniform_asset_scale"] / 4.1
                expected = [
                    binding["center_grid_rc"][0] - x_cells * math.sin(yaw) + z_cells * math.cos(yaw),
                    binding["center_grid_rc"][1] + x_cells * math.cos(yaw) + z_cells * math.sin(yaw),
                ]
                actual = binding[target_name]["exact_anchor_grid_rc"]
                for got, wanted in zip(actual, expected):
                    self.assertAlmostEqual(got, wanted, delta=1e-8, msg=f"{key}:{target_name}")

            original = addendum[role]
            public_error = math.dist(binding["public_door"]["exact_anchor_grid_rc"], original["public_anchor_rc"])
            service_error = math.dist(binding["service_access"]["exact_anchor_grid_rc"], original["service_anchor_rc"])
            self.assertGreater(public_error, 0.15, key)
            self.assertGreater(service_error, 0.9, key)
            self.assertAlmostEqual(public_error, binding["public_door"]["superseded_error_cells"], delta=1e-6)
            self.assertAlmostEqual(service_error, binding["service_access"]["superseded_error_cells"], delta=1e-6)

    def test_exact_legacy_shell_tiles_doors_and_preexisting_road_access(self):
        parts = {item["legacyStructureId"]: item for item in self.snapshot["parts"]}
        doors = {item["id"]: item for item in self.snapshot["doors"]}
        for binding in self.bindings.values():
            legacy = binding["legacy"]
            part = parts[legacy["structure_id"]]
            exact_tile_ids = [f"runtime:building-tile:{row}:{col}" for row, col in part["tiles"]]
            self.assertEqual(legacy["tile_ids"], exact_tile_ids)
            self.assertEqual(legacy["tile_bounds"]["tile_count"], len(exact_tile_ids))
            door = doors[legacy["door"]["id"]]
            self.assertEqual(legacy["door"]["grid_rc"], [door["r"], door["c"]])
            self.assertEqual(legacy["door"]["wall_grid_rc"], [door["wallR"], door["wallC"]])
            self.assertEqual(legacy["door"]["facing_grid_rc"], [door["facingR"], door["facingC"]])
            self.assertIsNone(legacy["gameplay_poi"])
            self.assertEqual(legacy["gameplay_identity"], "procedural_shell_only_no_fixed_business_poi")
            before = legacy["before_road_probe"]
            row, col = map(int, before["id"].rsplit(":", 2)[-2:])
            self.assertEqual([math.floor(before["grid_rc"][0]), math.floor(before["grid_rc"][1])], [row, col])
            self.assertEqual(self.snapshot["map"][row][col], 0)

    def test_static_sat_for_body_pad_and_corrected_access_routes(self):
        self.assertEqual(sha(RUNTIME_SNAPSHOT), "14cab22200589a453adc1a983dcbe8ec1a5872d535fd09f78c0fa0a97c42073c")
        protected = set(self.snapshot["bankTiles"] + self.snapshot["casinoTiles"] + self.snapshot["businessTiles"])
        anchors = []
        for item in self.snapshot["pois"]:
            anchors.append({"id": f"poi:{item['id']}", "r": item["r"], "c": item["c"]})
        for item in self.snapshot["businesses"]:
            anchors.append({"id": f"business:{item['id']}", "r": item["r"], "c": item["c"]})
        for district in self.snapshot["districts"]:
            for name in ("hq", "intel", "escape"):
                if district.get(name):
                    anchors.append({"id": f"district:{district['id']}:{name}", **district[name]})
            for index, point in enumerate(district.get("sabotage", [])):
                anchors.append({"id": f"district:{district['id']}:sabotage:{index}", **point})

        police = self.contract["immutable_protections"]["police_no_build_rect_rc"]
        bridge = self.contract["immutable_protections"]["premium_red_bridge_rect_rc"]
        all_shapes = []
        for binding in self.bindings.values():
            allowed = {item.rsplit(":", 2)[-2] + "," + item.rsplit(":", 1)[-1] for item in binding["legacy"]["tile_ids"]}
            block_key = f"{binding['legacy']['block_bounds']['r0'] // 10},{binding['legacy']['block_bounds']['c0'] // 10}"
            self.assertNotIn(block_key, set(self.snapshot["npcHqBlocks"]))
            self.assertFalse(allowed & protected)

            shapes = [
                ("pad", binding["pad_rect_grid_rc"], False),
                ("footprint", binding["footprint_rect_grid_rc"], False),
            ]
            shapes.extend(("public_route", rect, True) for rect in binding["public_door"]["approach_segments_rect_grid_rc"])
            shapes.extend(("service_route", rect, True) for rect in binding["service_access"]["approach_segments_rect_grid_rc"])
            for name, rect, allow_road in shapes:
                all_shapes.append((binding["key"], name, rect))
                for row, col in rect_cells(rect):
                    self.assertGreaterEqual(row, 0)
                    self.assertGreaterEqual(col, 0)
                    self.assertLess(row, self.snapshot["mapRows"])
                    self.assertLess(col, self.snapshot["mapCols"])
                    tile = self.snapshot["map"][row][col]
                    cell = f"{row},{col}"
                    self.assertFalse(tile == 1 and cell not in allowed, f"{binding['key']}:{name}:building:{cell}")
                    self.assertNotIn(tile, (7, 16, 18, 19), f"{binding['key']}:{name}:blocked-tile:{cell}:{tile}")
                    self.assertFalse(tile == 0 and not allow_road, f"{binding['key']}:{name}:road:{cell}")
                    self.assertFalse(cell in protected and cell not in allowed, f"{binding['key']}:{name}:gameplay:{cell}")
                self.assertFalse(overlaps(rect, police), f"{binding['key']}:{name}:police")
                self.assertFalse(overlaps(rect, bridge), f"{binding['key']}:{name}:red-bridge")
                for anchor in anchors:
                    self.assertGreaterEqual(point_rect_distance(anchor, rect), 2.8 - EPSILON, f"{binding['key']}:{name}:{anchor['id']}")

            for access in (binding["public_door"], binding["service_access"]):
                probe = access["road_probe"]
                row, col = map(int, probe["id"].rsplit(":", 2)[-2:])
                self.assertEqual([math.floor(probe["grid_rc"][0]), math.floor(probe["grid_rc"][1])], [row, col])
                self.assertEqual(self.snapshot["map"][row][col], 0, probe["id"])

        for index, (left_key, left_name, left_rect) in enumerate(all_shapes):
            for right_key, right_name, right_rect in all_shapes[index + 1 :]:
                if left_key != right_key:
                    self.assertFalse(overlaps(left_rect, right_rect), f"{left_key}:{left_name} vs {right_key}:{right_name}")

    def test_candidate_does_not_overlap_existing_accepted_pawn_or_print_slice(self):
        accepted = load(ACCEPTED / "main_native_bindings.v1.json")["bindings"]
        accepted_shapes = []
        for binding in accepted:
            accepted_shapes.extend(
                [
                    (binding["key"], polygon_rect(binding["pad_polygon_grid_cr"])),
                    (binding["key"], polygon_rect(binding["footprint_polygon_grid_cr"])),
                    (binding["key"], polygon_rect(binding["public_door"]["corridor_polygon_grid_cr"])),
                    (binding["key"], polygon_rect(binding["service_access"]["corridor_polygon_grid_cr"])),
                ]
            )
        for binding in self.bindings.values():
            candidate_shapes = [binding["pad_rect_grid_rc"], binding["footprint_rect_grid_rc"]]
            candidate_shapes.extend(binding["public_door"]["approach_segments_rect_grid_rc"])
            candidate_shapes.extend(binding["service_access"]["approach_segments_rect_grid_rc"])
            for shape in candidate_shapes:
                for accepted_key, accepted_shape in accepted_shapes:
                    self.assertFalse(overlaps(shape, accepted_shape), f"{binding['key']} overlaps {accepted_key}")

    def test_district_distribution_and_low_density_slice(self):
        self.assertEqual({binding["district_id"] for binding in self.bindings.values()}, {"southside", "industrial", "docklands"})
        district_bounds = {
            "southside": (40, 99, 0, 39),
            "industrial": (40, 99, 40, 79),
            "docklands": (75, 149, 100, 179),
        }
        centers = []
        for binding in self.bindings.values():
            row, col = binding["center_grid_rc"]
            r0, r1, c0, c1 = district_bounds[binding["district_id"]]
            self.assertTrue(r0 <= row <= r1 and c0 <= col <= c1)
            centers.append((row, col))
            pad = binding["pad_rect_grid_rc"]
            pad_area = (pad["maxR"] - pad["minR"]) * (pad["maxC"] - pad["minC"])
            self.assertLess(pad_area, binding["legacy"]["tile_bounds"]["tile_count"])
        for index, left in enumerate(centers):
            for right in centers[index + 1 :]:
                self.assertGreater(math.dist(left, right), 30.0)

    def test_focus_urls_are_one_tab_ready_but_explicitly_post_integration(self):
        urls = self.bindings_doc["post_integration_focus_urls"]
        self.assertEqual(tuple(urls), EXPECTED_KEYS)
        for key, url in urls.items():
            self.assertIn("previewcityv3=stage-a", url)
            self.assertIn("cityv3buildings=1", url)
            self.assertIn(f"cityv3focus={key.replace('@', '%40')}", url)
            self.assertIn("force3d=1", url)
            self.assertIn("render=3d", url)

    def test_audited_git_blobs_and_addendum_hash_gate_remain_fail_closed(self):
        audited = self.bindings_doc["audited_head"]
        for path, field in (("world.html", "git_blob_world_html_sha256"), ("three_preview.js", "git_blob_three_preview_js_sha256")):
            run = subprocess.run(
                ["git", "show", f"{audited['commit']}:{path}"],
                cwd=ROOT,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
            )
            self.assertEqual(run.returncode, 0, run.stderr.decode(errors="replace"))
            self.assertEqual(hashlib.sha256(run.stdout).hexdigest(), audited[field])
        self.assertNotEqual(audited["audited_worktree_world_html_sha256"], self.contract["source"]["current_main_world_sha256"])
        self.assertNotEqual(audited["audited_worktree_three_preview_js_sha256"], self.contract["source"]["current_main_three_preview_sha256"])
        self.assertFalse(self.bindings_doc["runtime_activation"])
        self.assertTrue(self.bindings_doc["atomic_apply_policy"]["current_runtime_preflight_required"])


if __name__ == "__main__":
    unittest.main()
