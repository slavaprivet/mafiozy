"""Focused immutable-asset and atomic replacement checks for City V3 buildings."""

from __future__ import annotations

import hashlib
import json
import math
import struct
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent
ASSETS = ROOT / "assets" / "buildings" / "city_v3"
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")
CIVIC_RUNTIME = (ASSETS / "registry.v1.js").read_text(encoding="utf-8")
ACCEPTED = ASSETS / "accepted_v1"
ACCEPTED_RUNTIME = (ACCEPTED / "registry.v1.js").read_text(encoding="utf-8")


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def glb_json(path: Path):
    body = path.read_bytes()
    magic, version, declared = struct.unpack_from("<III", body, 0)
    assert (magic, version, declared) == (0x46546C67, 2, len(body))
    length, kind = struct.unpack_from("<II", body, 12)
    assert kind == 0x4E4F534A
    return json.loads(body[20 : 20 + length])


def function_body(source: str, name: str) -> str:
    start = source.index(f"function {name}")
    brace = source.index("{", start)
    depth = 0
    for index in range(brace, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[brace : index + 1]
    raise AssertionError(f"unterminated {name}")


class CityV3BuildingRuntimeTests(unittest.TestCase):
    def test_immutable_bytes_and_direct_registries(self):
        expected = {
            ASSETS / "registry.v1.json": (1231, "1551ff8bcf6df0b37fb9d07dbbb3632c075f9aeef41c8674488f928f1a0d4745"),
            ASSETS / "civic_hall_landmark" / "v1" / "manifest.v1.json": (6744, "7f692c40fddac3577528c944a4e4cbcde1439e961912368d1546cade5b145592"),
            ASSETS / "civic_hall_landmark" / "v1" / "civic_hall_landmark_v1.2ef23fb5e7f9.glb": (823628, "2ef23fb5e7f9888fe465c896811d3f88bb4fbc027f91394ca3b4e7477075cc35"),
            ASSETS / "civic_hall_landmark" / "v1" / "civic_hall_landmark_v1.45a57298bb1a.asset.json": (4391, "45a57298bb1a32bffbb78b16ab2bbfb7e4b090552bfc8a41ac9531d4aae53641"),
            ACCEPTED / "main_native_bindings.v1.json": (5427, "af32124e3581fca1cc01bae31691f6ba17a0c381974638e4134457f7134ae297"),
            ACCEPTED / "registry.v1.json": (1552, "c1b79fe64b550b4898351155a1cd17dac2b23b64075a6e0f9b77d202b853635e"),
            ACCEPTED / "registry.v1.js": (21127, "c69aae841d943e2189f60f347d47c08e0310c45b6ccbbf4f1dbbbacf99f706a5"),
            ACCEPTED / "pawnshop" / "v1" / "manifest.v1.json": (5236, "2ba165499140834cd6a85a5e2d54e626bc5e37192792e5469aea010d5fcf19ea"),
            ACCEPTED / "pawnshop" / "v1" / "pawnshop.1a95f97569d9.glb": (1453452, "1a95f97569d94d162d2d0c4217e1435a2b9e5860a49a2d140d90e4d899d6232f"),
            ACCEPTED / "pawnshop" / "v1" / "pawnshop.f428a09b9b80.asset.json": (803, "f428a09b9b8076376e6632f3aa71cf030fca18f1adba88bb224525342ff969de"),
            ACCEPTED / "print_shop" / "v1" / "manifest.v1.json": (5182, "c348f00ae5ebfab59e56d2f1b5a40bed27712c7f21925acb9d17bb11ebe980c4"),
            ACCEPTED / "print_shop" / "v1" / "print_shop.ad7b8ef7e7e4.glb": (966720, "ad7b8ef7e7e4143f0e989b7a585c03bb9bd1c13d5efb8689cf67ebcb92ac4d97"),
            ACCEPTED / "print_shop" / "v1" / "print_shop.60b7d9d16fb9.asset.json": (968, "60b7d9d16fb99750f18b324ca169990a54a30daa5942a3b5b71d460717735ace"),
        }
        for path, (size, digest) in expected.items():
            self.assertTrue(path.is_file(), path)
            self.assertEqual(path.stat().st_size, size, path)
            self.assertEqual(sha(path), digest, path)

        civic = load(ASSETS / "registry.v1.json")
        accepted = load(ACCEPTED / "registry.v1.json")
        self.assertEqual([entry["key"] for entry in civic["entries"]], ["civic_hall_landmark@1"])
        self.assertEqual([entry["key"] for entry in accepted["entries"]], ["pawnshop@1", "print_shop@1"])
        self.assertNotIn("pawnshop", [entry["key"] for entry in accepted["entries"]])
        self.assertTrue(all(entry["live_activation"] is False for entry in accepted["entries"]))

    def test_provenance_rights_and_binding_authority(self):
        bindings = load(ACCEPTED / "main_native_bindings.v1.json")
        self.assertEqual(bindings["schema"], "mafiozi.city-v3-main-native-bindings/v1")
        self.assertEqual(bindings["prohibited_targets"], [
            "gameplay_poi", "bank", "business", "police", "premium_red_bridge", "water", "road", "rail", "race_track"
        ])
        self.assertEqual(len(bindings["bindings"]), 2)
        self.assertEqual(bindings["planning_authority"]["superseded_v2"]["status"], "superseded_do_not_apply")
        self.assertFalse(bindings["planning_authority"]["superseding_v3"]["status"].endswith("ready_true"))
        self.assertEqual(bindings["planning_authority"]["superseding_v3"]["contract_sha256"], "9a8ee4a98062c0b1e171cafc5552cfd1d65e91d2da167ee45f282c47a83787f7")
        by_key = {item["key"]: item for item in bindings["bindings"]}
        for key in ("pawnshop@1", "print_shop@1"):
            manifest = load(ACCEPTED / key.split("@")[0] / "v1" / "manifest.v1.json")
            self.assertEqual(manifest["provenance"]["origin"], "project_generated")
            self.assertEqual(manifest["provenance"]["external_sources"], [])
            self.assertEqual(manifest["provenance"]["usage"], "internal_project_asset")
            self.assertEqual(manifest["authority"]["placement_v2_contract_sha256"], "e917883063d0dcc3326ed2ea508f4d3956e10688296d1f063a34c61378bc4c78")
            self.assertEqual(manifest["authority"]["placement_v2_status"], "superseded_do_not_apply")
            self.assertEqual(manifest["authority"]["placement_v3_contract_sha256"], "9a8ee4a98062c0b1e171cafc5552cfd1d65e91d2da167ee45f282c47a83787f7")
            self.assertEqual(manifest["authority"]["placement_v3_status"], "stage_a_topology_only_main_native_runtime_rollout_ready_false")
            self.assertEqual(manifest["authority"]["main_native_bindings_sha256"], sha(ACCEPTED / "main_native_bindings.v1.json"))
            self.assertTrue(manifest["runtime_gate"]["fail_closed"])
            self.assertTrue(manifest["runtime_gate"]["failure_keeps_legacy"])
            self.assertEqual(by_key[key]["replacement"]["policy"], "addressed_removal_only")
            self.assertTrue(by_key[key]["replacement"]["zero_untracked_demolition"])

    def test_glb_nodes_bounds_and_recentered_entrances(self):
        bindings = {item["key"]: item for item in load(ACCEPTED / "main_native_bindings.v1.json")["bindings"]}
        for key in ("pawnshop@1", "print_shop@1"):
            role = key.split("@")[0]
            manifest = load(ACCEPTED / role / "v1" / "manifest.v1.json")
            asset = ACCEPTED / role / "v1" / manifest["asset"]["file"]
            gltf = glb_json(asset)
            named = {node.get("name"): node for node in gltf["nodes"] if node.get("name")}
            for name in manifest["geometry"]["required_nodes"]:
                self.assertIn(name, named)
            self.assertTrue(manifest["geometry"]["public_door_visual_nodes"])
            self.assertTrue(set(manifest["geometry"]["public_door_visual_nodes"]).issubset(named))
            for kind in ("public_door", "service_door"):
                node = named[manifest["geometry"][f"{kind}_node"]]
                expected = manifest["geometry"][f"{kind}_local_xyz_m"]
                for actual, wanted in zip(node.get("translation", [0, 0, 0]), expected):
                    self.assertAlmostEqual(actual, wanted, delta=0.015)
            if manifest["geometry"]["root_node"]:
                self.assertIn(manifest["geometry"]["root_node"], named)
                self.assertTrue(named[manifest["geometry"]["root_node"]].get("children"))

            binding = bindings[key]
            center_x, _, center_z = manifest["geometry"]["horizontal_center_xyz_m"]
            scale = binding["uniform_asset_scale"]
            yaw = math.radians(binding["yaw_deg"])
            for kind, target in (("public_door", binding["public_door"]), ("service_door", binding["service_access"])):
                x, _, z = manifest["geometry"][f"{kind}_local_xyz_m"]
                x = (x - center_x) * scale / 4.1
                z = (z - center_z) * scale / 4.1
                expected_rc = [binding["center_grid_rc"][0] - x * math.sin(yaw) + z * math.cos(yaw), binding["center_grid_rc"][1] + x * math.cos(yaw) + z * math.sin(yaw)]
                for actual, wanted in zip(target["actual_anchor_grid_rc"], expected_rc):
                    self.assertAlmostEqual(actual, wanted, delta=1e-5)

    def test_main_native_shells_are_deterministic_and_not_protected_blocks(self):
        bindings = load(ACCEPTED / "main_native_bindings.v1.json")["bindings"]
        protected = {"2,1","8,2","5,7","2,5","9,5","2,6","6,2","8,4","4,7","12,7","5,6","1,7","9,3","6,7","5,4","3,3","12,1","7,5","13,6"}
        for binding in bindings:
            legacy = binding["legacy_tile_bounds"]
            self.assertEqual((legacy["max_r_exclusive"] - legacy["min_r"]) * (legacy["max_c_exclusive"] - legacy["min_c"]), 16)
            block_key = f"{legacy['min_r']//10},{legacy['min_c']//10}"
            self.assertNotIn(block_key, protected)
            br, bc = map(int, block_key.split(","))
            self.assertNotIn((br * 17 + bc * 31) % 11, (0, 7), "chosen procedural shell is a park")
            self.assertTrue(binding["legacy_structure_id"].startswith("legacy:procedural:"))
            self.assertNotEqual(binding["superseded_planning_v2_binding"]["center_grid_cr"], binding["center_grid_cr"])
            self.assertFalse(binding["planning_v3_topology_candidate"]["runtime_main_scope_tested"])

    def test_atomic_loader_scale_preflight_and_suppression_order(self):
        accepted_install = ACCEPTED_RUNTIME[ACCEPTED_RUNTIME.index("export function installCityV3AcceptedCandidate") :]
        self.assertIn("+worldScale/4.1", accepted_install)
        self.assertIn("scene.add(candidate.placementRoot)", accepted_install)
        self.assertIn("scene.remove(candidate.placementRoot)", accepted_install)
        self.assertLess(accepted_install.index("scene.add(candidate.placementRoot)"), accepted_install.index("bridge.activateCityV3AcceptedBuildingPreview"))
        self.assertIn("recenter[0]*binding.uniform_asset_scale", ACCEPTED_RUNTIME)
        self.assertIn("localAnchorToGrid", ACCEPTED_RUNTIME)
        self.assertIn("object.userData.cityV3DoorLeafHidden=true", ACCEPTED_RUNTIME)
        self.assertIn("associations.get(object)?.nodes===rawIndex", ACCEPTED_RUNTIME)
        self.assertNotIn("assetRoot.getObjectByName(name)", ACCEPTED_RUNTIME)

        activation = function_body(WORLD, "_activateCityV3AcceptedBuildingPreview")
        self.assertIn("receipt?.loaded!==true", activation)
        self.assertIn("receipt?.eligible!==true", activation)
        self.assertIn("receipt?.registered!==true", activation)
        self.assertLess(activation.index("_cityV3AcceptedPreflight"), activation.index("_cityV3ActiveAcceptedBuildings.set"))
        self.assertLess(activation.index("_cityV3AcceptedLegacyPart"), activation.index("_cityV3ActiveAcceptedBuildings.set"))
        self.assertIn("_cityV3ActiveAcceptedBuildings.delete", activation)
        preflight = function_body(WORLD, "_cityV3AcceptedPreflight")
        for marker in ("pad", "footprint", "door.corridor", "service.corridor", "tile===16", "tile===18||tile===19||inRaceTrack", "tile===0&&!allowRoad"):
            self.assertIn(marker, preflight)
        self.assertIn("NPC_EMPIRE_HQ_BLOCK_KEYS", function_body(WORLD, "_cityV3AcceptedLegacyPart"))
        self.assertIn("_cityV3ActiveAcceptedBuildings.values()", function_body(WORLD, "_cityV3SuppressLegacyPart"))
        self.assertIn("_cityV3ActiveAcceptedBuildings.values()", function_body(WORLD, "_cityV3SuppressLegacyDoor"))
        self.assertIn("rollbackCityV3AcceptedBuildingPreview", accepted_install)
        self.assertIn("rollbackCityV3AcceptedCandidate(instance", THREE)

        install_index = THREE.index("installCityV3AcceptedCandidate(candidate")
        snapshot_index = THREE.index("getWorldSnapshot?.(WORLD_SNAPSHOT_RADIUS)")
        self.assertLess(install_index, snapshot_index)
        self.assertIn("retaining exact legacy placeholder", THREE)
        self.assertIn("loadedBuildings:", WORLD)
        self.assertIn("replacedPlaceholder:", WORLD)
        self.assertIn("overlap:", WORLD)
        interaction = function_body(WORLD, "_cityV3AcceptedInteractionFor3D")
        self.assertIn("_cityV3ActiveAcceptedBuildings.values()", interaction)
        self.assertIn("entryR:door.anchorR,entryC:door.anchorC", interaction)
        nearby = function_body(WORLD, "_nearbyBuildingInteractionFor3D")
        self.assertIn("_cityV3AcceptedInteractionFor3D()", nearby)
        self.assertLess(nearby.index("const accepted=_cityV3AcceptedInteractionFor3D()"), nearby.index("for(const biz of BUSINESS_POIS)"))
        self.assertIn("if(accepted){", nearby)
        self.assertIn("return accepted", nearby)

    def test_authored_door_interaction_uses_exact_public_threshold(self):
        approach = function_body(WORLD, "_cityV3AcceptedDoorApproachAt")
        helper = function_body(WORLD, "_cityV3AcceptedInteractionFor3D")
        nearby = function_body(WORLD, "_nearbyBuildingInteractionFor3D")
        script = f"""
let player={{r:10.5,c:66.900488}};
const contract={{key:'pawnshop@1',center:{{r:7,c:67}},door:{{anchorR:7.755878,anchorC:66.900488,corridor:{{minR:7.755878,maxR:10.25,minC:66.534634,maxC:67.266341}},roadProbe:{{r:10.5,c:66.900488}}}}}};
const _cityV3ActiveAcceptedBuildings=new Map([['pawnshop@1',{{contract}}]]);
function _cityV3AcceptedDoorApproachAt(contract,r,c,maxDistance=3.05){approach}
function _cityV3AcceptedInteractionFor3D(maxDistance=3.05){helper}
let _buildingInt=null,_gtaActionKind=null,_bankInt=null,myDrivingCarId=null,myDead=false;
const JAIL_ISLAND_LAYOUT={{intake:{{north:1,south:0,west:1,east:0}}}},JAIL_ISLAND_3D_ENABLED=false;
function _nearbyBuildingInteractionFor3D(){nearby}
if(!_cityV3AcceptedDoorApproachAt(contract,contract.door.anchorR,contract.door.corridor.minC))throw new Error('inclusive corridor boundary rejected');
if(_cityV3AcceptedDoorApproachAt(contract,contract.door.anchorR,contract.door.corridor.minC-0.000002))throw new Error('outside lateral corridor accepted');
player={{r:contract.door.anchorR,c:contract.door.anchorC+0.5}};
if(_cityV3AcceptedInteractionFor3D())throw new Error('side approach stole another interaction');
player={{r:contract.door.roadProbe.r,c:contract.door.roadProbe.c}};
const result=_nearbyBuildingInteractionFor3D();
if(!result||result.id!=='city-v3:pawnshop@1')throw new Error('authored interaction not selected over broad garage zone');
if(result.entryR!==contract.door.anchorR||result.entryC!==contract.door.anchorC)throw new Error('marker drifted from authored door');
if(result.distance>3.05)throw new Error('road approach cannot reach authored door');
process.stdout.write(JSON.stringify(result));
"""
        run = subprocess.run(
            ["node", "-e", script], cwd=ROOT, text=True, encoding="utf-8",
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
        )
        self.assertEqual(run.returncode, 0, run.stderr)
        result = json.loads(run.stdout)
        self.assertEqual(result["name"], "Ломбард")
        self.assertAlmostEqual(result["entryR"], 7.755878, places=6)
        self.assertAlmostEqual(result["entryC"], 66.900488, places=6)

    def test_post_activation_failure_restores_legacy_atomically(self):
        module_url = (ACCEPTED / "registry.v1.js").resolve().as_uri()
        script = f"""
const runtime=await import({json.dumps(module_url)});
let active=0,suppressed=0,removed=0,tokenSeen=false;const token={{nonce:{{}}}};
const root={{name:'CITY_V3_ACCEPTED__pawnshop_1',parent:null,userData:{{}},scale:{{setScalar(v){{this.value=v;}}}},position:{{set(x,y,z){{this.x=x;this.y=y;this.z=z;}}}},updateMatrixWorld(){{}}}};
const scene={{isScene:true,add(o){{o.parent=this;}},remove(o){{removed++;o.parent=null;}},getObjectByName(name){{return root.parent===this&&name===root.name?root:null;}}}};
const THREE={{Box3:class{{setFromObject(o){{this.min={{x:o.position.x-1,y:0,z:o.position.z-1}};this.max={{x:o.position.x+1,y:2,z:o.position.z+1}};return this;}}}}}};
const bridge={{activateCityV3AcceptedBuildingPreview(){{active=1;suppressed=1;return {{ok:true,active:'pawnshop@1',rollbackToken:token}};}},rollbackCityV3AcceptedBuildingPreview(value){{tokenSeen=value===token;active=0;suppressed=0;return {{ok:true,rolledBack:'pawnshop@1'}};}}}};
const dataset=new Proxy({{}},{{set(target,key,value){{if(key==='cityV3AcceptedBuildings')throw new Error('forced-post-activation');target[key]=value;return true;}}}});
const candidate={{key:'pawnshop@1',installed:false,placementRoot:root,visibleMeshes:[{{}}],binding:{{center_grid_rc:[7,67],uniform_asset_scale:.68,yaw_deg:0,instance_id:'MAIN-AV1-INST-PAWNSHOP-01',legacy_structure_id:'legacy:procedural:0:60:5:65:8:68',public_door:{{actual_anchor_grid_rc:[7.755878,66.900488]}},service_access:{{actual_anchor_grid_rc:[6.46222,67.953659]}}}},manifest:{{authority:{{main_native_bindings_sha256:'af32124e3581fca1cc01bae31691f6ba17a0c381974638e4134457f7134ae297'}}}},registrySha256:'r',manifestSha256:'m',sidecarSha256:'s',assetSha256:'a',correctedBox:{{dimensions:[9.452,7.803,7.477]}}}};
let threw=false;try{{runtime.installCityV3AcceptedCandidate(candidate,{{THREE,scene,bridge,renderer:{{domElement:{{dataset}}}},originR:0,originC:0,worldScale:3}});}}catch(error){{threw=String(error.message).includes('forced-post-activation');}}
if(!threw||active||suppressed||!tokenSeen||removed!==1||root.parent!==null||candidate.installed)throw new Error(JSON.stringify({{threw,active,suppressed,tokenSeen,removed,parent:root.parent,installed:candidate.installed}}));
process.stdout.write('atomic-rollback-pass');
"""
        run = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, text=True, encoding="utf-8", stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertEqual(run.stdout, "atomic-rollback-pass")

    def test_accepted_road_probe_rejects_grass_track_bridge_and_race(self):
        body = function_body(WORLD, "_cityV3AcceptedOrdinaryRoadAt")
        script = f"""
let MAP=[[0,0],[0,0]],race=false;function inRaceTrack(){{return race;}}
function _cityV3AcceptedOrdinaryRoadAt(r,c){body}
if(!_cityV3AcceptedOrdinaryRoadAt(1,1))throw new Error('ordinary road rejected');
for(const tile of [8,18,19]){{MAP[1][1]=tile;if(_cityV3AcceptedOrdinaryRoadAt(1,1))throw new Error('non-road accepted '+tile);}}
MAP[1][1]=0;race=true;if(_cityV3AcceptedOrdinaryRoadAt(1,1))throw new Error('race overlay accepted');
process.stdout.write('semantic-road-pass');
"""
        run = subprocess.run(["node", "-e", script], cwd=ROOT, text=True, encoding="utf-8", stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertEqual(run.stdout, "semantic-road-pass")

    def test_runtime_raw_node_association_cardinality_fails_closed(self):
        module_url = (ACCEPTED / "registry.v1.js").resolve().as_uri()
        script = f"""
const runtime=await import({json.dumps(module_url)});
const resolve=runtime.resolveCityV3RuntimeNodeByRawIndex;
const one={{id:'one'}},two={{id:'two'}};
const scene=nodes=>({{traverse:callback=>nodes.forEach(callback)}});
const reject=(nodes,entries)=>{{
  const associations=new Map(entries);
  try{{resolve({{scene:scene(nodes),associations,rawIndex:7,rawName:'Door raw',code:'door_assoc'}});}}
  catch(error){{if(error?.code==='door_assoc')return;throw error;}}
  throw new Error('association cardinality did not fail closed');
}};
reject([one],[[one,{{nodes:8}}]]);
reject([one,two],[[one,{{nodes:7}}],[two,{{nodes:7}}]]);
const exact=resolve({{scene:scene([one]),associations:new Map([[one,{{nodes:7}}]]),rawIndex:7,rawName:'Door raw',code:'door_assoc'}});
if(exact!==one)throw new Error('unique raw-node association did not resolve');
process.stdout.write('association-cardinality-pass');
"""
        run = subprocess.run(
            ["node", "--input-type=module", "-e", script], cwd=ROOT,
            text=True, encoding="utf-8", stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, check=False,
        )
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertEqual(run.stdout, "association-cardinality-pass")

    def test_default_startup_does_not_fetch_authored_assets(self):
        gate = "if(cityV3BuildingPreviewRequested){"
        gate_index = THREE.index(gate)
        accepted_import = THREE.index("accepted_v1/registry.v1.js")
        gate_else = THREE.index("}else document.documentElement.dataset.cityV3BuildingLoader='inactive:gate-closed';", gate_index)
        self.assertLess(gate_index, accepted_import)
        self.assertLess(accepted_import, gate_else)
        self.assertIn("rendererParams.get('preview')==='1'", THREE)
        self.assertIn("rendererParams.get('previewcityv3')==='stage-a'", THREE)
        self.assertIn("rendererParams.get('cityv3buildings')==='1'", THREE)
        self.assertIn("import('../assets/buildings/city_v3/registry.v1.js", THREE)
        self.assertIn("import('../assets/buildings/city_v3/accepted_v1/registry.v1.js", THREE)
        self.assertNotIn("import('./assets/buildings/city_v3/", THREE)
        self.assertLess(ACCEPTED_RUNTIME.index("const hiddenDoorObjects="), ACCEPTED_RUNTIME.index("placementRoot.add(assetRoot)"))
        self.assertIn("&cityv3=accepted-c1b79fe6-atomic-v1\"", WORLD)
        self.assertIn("accepted-main-v1-c1b79fe6-atomic-v1", THREE)


if __name__ == "__main__":
    unittest.main()
