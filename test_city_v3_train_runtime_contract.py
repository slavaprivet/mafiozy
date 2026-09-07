"""Executable acceptance contract for the City V3 passenger railway.

The production runtime exposes ``_cityV3RailContractProbe`` only for local QA.
The probe must exercise the same state machine and snapshot serializer used by
the live world; a hard-coded second implementation does not satisfy this gate.
"""

from pathlib import Path
import hashlib
import json
import struct
import subprocess
import unittest


ROOT = Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")
RAIL_ROOT = ROOT / "assets" / "rail" / "city_v3"
CONTRACT_PATH = RAIL_ROOT / "v1" / "runtime_slice.contract.json"
BINDING_PATH = RAIL_ROOT / "v1" / "runtime_slice.main_binding.json"
TIMETABLE_PATH = RAIL_ROOT / "v1" / "runtime_slice.timetable.json"
ASSET_PATH = RAIL_ROOT / "v1" / "regional_train_and_track_tiles_v1.glb"
REGISTRY = (RAIL_ROOT / "registry.v1.js").read_text(encoding="utf-8")


def function_source(source: str, name: str) -> str:
    marker = f"function {name}("
    signature = source.find(marker)
    if signature < 0:
        raise AssertionError(f"missing executable QA adapter {name}")
    start = source.find("{", signature + len(marker))
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
                return source[signature:index + 1]
    raise AssertionError(f"unterminated function {name}")


def rail_probe() -> dict:
    names = (
        "_cityV3RailForwardDelta",
        "_cityV3RailMachineCreate",
        "_cityV3RailMachineDoor",
        "_cityV3RailMachineStep",
        "_cityV3RailPassengerAction",
        "_cityV3RailMachineSnapshot",
        "_cityV3RailContractProbe",
    )
    probe = "\n".join(function_source(WORLD, name) for name in names)
    completed = subprocess.run(
        [
            "node",
            "-e",
            (
                f"{probe}\n"
                "const result=_cityV3RailContractProbe();\n"
                "console.log(JSON.stringify(result));"
            ),
        ],
        check=True,
        text=True,
        capture_output=True,
        encoding="utf-8",
    )
    return json.loads(completed.stdout)


def run_world_js(names,body):
    source="\n".join(function_source(WORLD,name) for name in names)
    result=subprocess.run(["node","-e",source+"\n"+body],check=True,text=True,capture_output=True,encoding="utf-8")
    return json.loads(result.stdout)


class CityV3TrainRuntimeContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.proof = rail_probe()

    def test_eight_stations_and_visible_moving_train(self):
        stations = self.proof["stations"]
        station_ids = {station["id"] for station in stations}
        self.assertEqual(len(stations), 8)
        self.assertEqual(len(station_ids), 8)

        samples = self.proof["samples"]
        self.assertTrue(samples, "rail QA probe returned no runtime samples")
        self.assertTrue(any(sample["trainVisible"] for sample in samples))
        self.assertTrue(
            any(sample["trainVisible"] and sample["moving"] and sample["speed"] > 0
                for sample in samples),
            "no sample proves a rendered train moving on the route",
        )
        for sample in samples:
            self.assertIn(sample["stationId"], station_ids)
            self.assertGreaterEqual(sample["dwellRemaining"], 0)

    def test_exact_four_second_dwell_is_state_machine_output(self):
        profile = self.proof["dwellProfile"]
        self.assertEqual(profile, {"open": 0.4, "hold": 3.2, "close": 0.4})
        self.assertAlmostEqual(sum(profile.values()), 4.0, places=9)

        dwell = [sample for sample in self.proof["samples"] if sample["phase"] == "dwell"]
        self.assertTrue(dwell, "no stopped-at-station dwell samples")
        self.assertAlmostEqual(max(sample["dwellRemaining"] for sample in dwell), 4.0, places=3)
        departures = [sample for sample in self.proof["samples"] if sample["phase"] == "depart"]
        self.assertTrue(departures, "probe never reaches departure")
        self.assertTrue(all(sample["dwellRemaining"] == 0 for sample in departures))
        self.assertTrue(all(sample["doorsClosed"] for sample in departures))

    def test_board_and_exit_use_live_passenger_state(self):
        board = self.proof["board"]
        exit_result = self.proof["exit"]
        self.assertTrue(board["ok"])
        self.assertTrue(board["aboard"])
        self.assertTrue(exit_result["ok"])
        self.assertFalse(exit_result["aboard"])
        self.assertEqual(board["stationId"], exit_result["stationId"])

    def test_snapshot_is_consumed_by_the_three_renderer(self):
        self.assertIn("rail:", WORLD, "getWorldSnapshot must serialize rail state")
        self.assertIn("worldSnapshot?.rail", THREE)
        self.assertIn("trainVisible", THREE)
        self.assertIn("dwellRemaining", THREE)

        rail_assets = [
            path for path in (ROOT / "assets").rglob("*.glb")
            if "train" in path.name.lower() or "rail" in path.name.lower()
        ]
        self.assertTrue(rail_assets, "no train/rail GLB is shipped by the live project")

    def test_slice_is_default_off_and_requires_exact_local_stage_a_gate(self):
        gate = "rendererParams.get('preview')==='1'&&rendererParams.get('previewcityv3')==='stage-a'&&rendererParams.get('cityv3rail')==='1'"
        self.assertIn(gate, THREE)
        self.assertIn("_UP.get('cityv3rail')==='1'", WORLD)
        self.assertIn("if(cityV3RailPreviewRequested)", THREE)
        self.assertIn("import('../assets/rail/city_v3/registry.v1.js", THREE)
        self.assertNotIn("cityv3rail=1", WORLD)

    def test_hash_pinned_asset_and_main_native_binding_are_shipped_exactly(self):
        expected = {
            CONTRACT_PATH: (4179, "bdab0b2c8ffc9243a86b1ca01dde7abfb4a3ec11c30957eb13899a4fc6e9fee2"),
            BINDING_PATH: (183287, "6667e473509717d50aa848d14c8781c17345ee04efd27c10353f9ff3169258d2"),
            TIMETABLE_PATH: (1140, "2ef53e0badb2d87921b976aa3dc6e5e3a51fe2f1c0f0f90caaae451c68e80cb4"),
            ASSET_PATH: (5981212, "fb63b5303a9c16ac94f7a52896ab30123ad6014aa675dc87bb7cca6df032c9cc"),
        }
        for path, (size, digest) in expected.items():
            with self.subTest(path=path.name):
                body = path.read_bytes()
                self.assertEqual(len(body), size)
                self.assertEqual(hashlib.sha256(body).hexdigest(), digest)
                self.assertIn(digest, REGISTRY)

        contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
        binding = json.loads(BINDING_PATH.read_text(encoding="utf-8"))
        timetable = json.loads(TIMETABLE_PATH.read_text(encoding="utf-8"))
        self.assertEqual(binding["route"]["id"], "MAIN-NATIVE-SOUTH-COAST-RL-01")
        self.assertTrue(binding["route"]["closed"])
        self.assertEqual(len(binding["stations"]), 8)
        self.assertEqual(len(binding["protectedCrossings"]), 2)
        self.assertEqual(binding["geometry"]["preserve"], ["police", "premium_red_suspension_bridge"])
        self.assertEqual(contract["stationPlatform"]["clearLengthM"], 64)
        self.assertGreaterEqual(contract["stationPlatform"]["clearLengthM"], contract["consist"]["lengthM"])
        self.assertEqual((contract["consist"]["tailAlignmentM"], contract["consist"]["headAlignmentM"]), (-27.6, 27.6))
        self.assertLessEqual(max(abs(contract["consist"]["tailAlignmentM"]), abs(contract["consist"]["headAlignmentM"])), contract["stationPlatform"]["clearLengthM"] / 2)
        self.assertEqual(timetable["dwellProfile"], {"openMs": 400, "holdMs": 3200, "closeMs": 400, "nominalTotalMs": 4000})

    def test_asset_nodes_drive_live_doors_collision_and_crossing_authority(self):
        body = ASSET_PATH.read_bytes()
        self.assertEqual(body[:4], b"glTF")
        offset = 12
        gltf = None
        while offset + 8 <= len(body):
            length, kind = struct.unpack_from("<II", body, offset)
            offset += 8
            chunk = body[offset:offset + length]
            offset += length
            if kind == 0x4E4F534A:
                gltf = json.loads(chunk.decode("utf-8").rstrip(" \t\r\n\0"))
        self.assertIsNotNone(gltf)
        names = [node.get("name", "") for node in gltf.get("nodes", [])]
        for name in (
            "TRAIN_REGIONAL_CLAY_CONSIST_ROOT",
            "TRAIN_LOD0_ROOT", "TRAIN_LOD1_ROOT", "TRAIN_LOD2_ROOT",
            "TRAIN_COLLISION_ROOT",
            "COLLISION_TRAIN_BODY_CAR00",
            "COLLISION_TRAIN_BODY_CAR01",
            "COLLISION_TRAIN_BODY_CAR02",
        ):
            self.assertEqual(names.count(name), 1, name)
        self.assertEqual(len([name for name in names if name.startswith("DoorPivot_")]), 24)
        self.assertIn("expected 24 unique exported door pivots", REGISTRY)
        self.assertIn("TRAIN_COLLISION_ROOT", WORLD)
        self.assertIn("_cityV3RailTrainBodyContains", WORLD)
        self.assertIn("_cityV3RailGateContains", WORLD)
        self.assertIn("_cityV3RailVehicleOccupied", WORLD)
        self.assertIn("_cityV3RailAuthorityReady", WORLD)
        self.assertIn("_cityV3RailDoorObstructed", WORLD)
        service_block = function_source(WORLD, "_serviceVehicleBodyPointBlocked")
        ambient_block = function_source(WORLD, "_trafficCarFootprintClear")
        self.assertIn("_cityV3RailBlocksCar(r,c)", service_block)
        self.assertIn("_cityV3RailBlocksCar(sampleR,sampleC)", ambient_block)
        self.assertIn("safe_exit_blocked", WORLD)
        self.assertIn("toggleCityV3RailBoarding", THREE)
        self.assertIn("updateCityV3RailCandidate", THREE)
        self.assertIn("new THREE.InstancedMesh", REGISTRY)
        self.assertIn("CITY_V3_RAIL_SLEEPERS_BATCH", REGISTRY)

    def test_unapproved_hub_and_depot_are_not_faked(self):
        self.assertIn("centralInterchange:null,depot:null", WORLD)
        self.assertNotIn("port_depot_v1.glb", REGISTRY)
        self.assertNotIn("central_interchange_v1.glb", REGISTRY)

    def test_dwell_consumes_large_and_fractional_frames_without_time_loss(self):
        result=run_world_js(("_cityV3RailForwardDelta","_cityV3RailMachineCreate","_cityV3RailMachineDoor","_cityV3RailMachineStep"),"""
const stations=[{progress:.1},{progress:.5}];
const results=[];
for(const chunks of [[4],[1,1,1,1],Array(40).fill(.1),[.17,.33,.5,1,2]]){
 const s=_cityV3RailMachineCreate(stations);
 for(const dt of chunks)_cityV3RailMachineStep(s,dt,stations,1000,true);
 results.push({mode:s.mode,elapsed:s.dwellElapsed,progress:s.progress,door:_cityV3RailMachineDoor(s)});
}
const residual=_cityV3RailMachineCreate(stations);_cityV3RailMachineStep(residual,4.1,stations,1000,true);
const held=_cityV3RailMachineCreate(stations);_cityV3RailMachineStep(held,8,stations,1000,false);
console.log(JSON.stringify({results,residual,held}));
""")
        for item in result["results"]:
            self.assertEqual(item["mode"],"MOVING")
            self.assertEqual(item["elapsed"],4)
            self.assertAlmostEqual(item["progress"],.1)
            self.assertEqual(item["door"]["amount"],0)
        self.assertGreater(result["residual"]["progress"],.1)
        self.assertEqual(result["held"]["mode"],"DWELL")
        self.assertEqual(result["held"]["dwellElapsed"],4)

    def test_obstruction_holds_doors_and_blocks_departure(self):
        result=run_world_js(("_cityV3RailForwardDelta","_cityV3RailMachineCreate","_cityV3RailMachineDoor","_cityV3RailMachineStep"),"""
const stations=[{progress:.1},{progress:.5}],s=_cityV3RailMachineCreate(stations);
s.obstruction=true;s.dwellElapsed=3.7;
_cityV3RailMachineStep(s,10,stations,1000,true);
console.log(JSON.stringify({state:s,door:_cityV3RailMachineDoor(s)}));
""")
        self.assertEqual(result["state"]["mode"],"DWELL")
        self.assertEqual(result["state"]["progress"],.1)
        self.assertEqual(result["door"]["phase"],"blocked")
        self.assertEqual(result["door"]["amount"],1)

    def test_platforms_are_on_contract_side_on_both_route_directions(self):
        script="\n".join(function_source(REGISTRY,name) for name in ("routePoint","cityV3RailPlatformPose"))+"\n"+"""
const binding=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));
console.log(JSON.stringify(binding.stations.map(station=>{
const p=cityV3RailPlatformPose(binding,station),t=routePoint(binding,station.progress);
return {side:station.platformSide,offset:((p.r-station.r)*t.dc-(p.c-station.c)*t.dr)*2.8};
})));
"""
        completed=subprocess.run(["node","-e",script,str(BINDING_PATH)],check=True,text=True,capture_output=True,encoding="utf-8")
        for pose in json.loads(completed.stdout):
            self.assertAlmostEqual(pose["offset"],5.25 if pose["side"]=="L" else -5.25)

    def test_crossing_leaves_occupied_road_open_and_ignores_hidden_entities(self):
        result=run_world_js(("_cityV3RailCrossingStep","_cityV3RailVehicleOverlapsCrossing"),"""
const crossing={r:0,c:0,gateClosedAmount:1};
_cityV3RailCrossingStep(crossing,.6,true,35);
const occupied={...crossing};
_cityV3RailCrossingStep(crossing,.3,false,35);const settling={...crossing};
_cityV3RailCrossingStep(crossing,.3,false,35);
_cityV3RailCrossingStep(crossing,.3,false,35);
const point={dr:0,dc:1},cars=[{r:0,c:0},{r:0,c:0,_hidden:true},{r:0,c:0,_towed:true},{r:0,c:0,parked:true},{r:3,c:0,parked:true},{r:0,c:0,_wrecked:true},{x:NaN,y:NaN}];
console.log(JSON.stringify({occupied,settling,cleared:crossing,hits:cars.map(c=>_cityV3RailVehicleOverlapsCrossing(c,{r:0,c:0},point))}));
""")
        self.assertEqual(result["occupied"]["gateClosedAmount"],0)
        self.assertEqual(result["occupied"]["roadState"],"clearing")
        self.assertEqual(result["settling"]["gateClosedAmount"],0)
        self.assertEqual(result["cleared"]["gateClosedAmount"],1)
        self.assertEqual(result["hits"],[True,False,False,True,False,True,False])

    def test_car_poses_follow_separate_path_samples_and_match_collision(self):
        result=run_world_js(("_cityV3RailRoutePoint","_cityV3RailCarPose","_cityV3RailCarLocalToGrid","_cityV3RailTrainBodyContains"),"""
const CITY_V3_RAIL_ROUTE={lengthTiles:400,lengthM:1120,metresPerTile:2.8,points:[[0,0],[0,100],[100,100],[100,0]]};
const progress=.25,poses=[18.8,0,-18.8].map(offset=>_cityV3RailCarPose(progress,offset));
let _cityV3RailState={sim:{progress},receipt:{collisionBodies:[18.8,0,-18.8].map(x=>({center:[x,2,0],size:[17.6,4,2.86]}))}};
const hits=poses.map(p=>_cityV3RailTrainBodyContains(p.r,p.c));
const door=_cityV3RailCarLocalToGrid([18.8+4,1,1.43],progress,18.8);
console.log(JSON.stringify({poses,hits,door}));
""")
        self.assertEqual(result["hits"],[True,True,True])
        self.assertAlmostEqual(result["poses"][0]["c"],100)
        self.assertAlmostEqual(result["poses"][2]["r"],0)
        self.assertAlmostEqual(result["poses"][0]["yaw"],-1.5707963267948966)
        self.assertAlmostEqual(result["poses"][2]["yaw"],0)
        self.assertAlmostEqual(result["door"]["c"],100-1.43/2.8)

    def test_renderer_applies_each_authoritative_car_pose(self):
        script="""
const {updateCityV3RailCandidate}=await import('./assets/rail/city_v3/registry.v1.js');
const node=()=>({position:{set(x,y,z){this.value=[x,y,z];}},rotation:{y:0}});
const candidate={installed:true,scale:1,trainRoot:node(),carRoots:[0,1,2].map(index=>({index,object:node()})),lodRoots:[{children:[]}],doorPivots:[],crossingRoots:[],signals:[]};
const cars=[{r:6,c:100,yaw:-Math.PI/2},{r:0,c:100,yaw:-Math.PI/4},{r:0,c:94,yaw:0}].map((p,index)=>({...p,name:`COLLISION_TRAIN_BODY_CAR0${index}`}));
updateCityV3RailCandidate(candidate,{position:{r:0,c:100,yaw:-Math.PI/4,cars},phase:'depart'},{originR:0,originC:0,worldScale:2.8});
console.log(JSON.stringify({rootYaw:candidate.trainRoot.rotation.y,cars:candidate.carRoots.map(c=>({pos:c.object.position.value,yaw:c.object.rotation.y}))}));
"""
        completed=subprocess.run(["node","--input-type=module","-e",script],cwd=ROOT,check=True,text=True,capture_output=True,encoding="utf-8")
        result=json.loads(completed.stdout)
        self.assertEqual(result["rootYaw"],0)
        self.assertAlmostEqual(result["cars"][0]["pos"][2],16.8)
        self.assertAlmostEqual(result["cars"][2]["pos"][0],-16.8)
        self.assertAlmostEqual(result["cars"][0]["yaw"],-1.5707963267948966)
        self.assertEqual(result["cars"][2]["yaw"],0)


if __name__ == "__main__":
    unittest.main()
