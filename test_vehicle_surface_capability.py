from pathlib import Path
import json
import subprocess
import unittest


WORLD_PATH = Path(__file__).with_name("world.html")
WORLD = WORLD_PATH.read_text(encoding="utf-8")


def function_body(source: str, name: str) -> str:
    marker = f"function {name}("
    signature = source.find(marker)
    if signature < 0:
        raise AssertionError(f"missing function {name}")
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
                return source[start:index + 1]
    raise AssertionError(f"unterminated function {name}")


def function_source(source: str, name: str) -> str:
    marker = f"function {name}("
    signature = source.find(marker)
    body = function_body(source, name)
    body_start = source.find("{", signature + len(marker))
    return source[signature:body_start + len(body)]


def surface_contract_source() -> str:
    start = WORLD.index("const VEHICLE_SURFACE_CAPABILITY = Object.freeze({")
    end = WORLD.index("// Спецтранспорт едет ПО ДОРОГАМ.", start)
    return WORLD[start:end]


def traffic_graph_source() -> str:
    start = WORLD.index("const _TRAFFIC_PATH_CACHE_MAX=1024;")
    end = WORLD.index("function _trafficGoalScore", start)
    return WORLD[start:end]


def run_node(script: str) -> str:
    completed = subprocess.run(
        ["node", "-e", script],
        check=True,
        text=True,
        capture_output=True,
        encoding="utf-8",
    )
    return completed.stdout.strip()


class VehicleSurfaceCapabilityTests(unittest.TestCase):
    def test_runtime_surface_matrix_rejects_non_vehicle_ground(self):
        surface = surface_contract_source()
        tiles = [0, 1, 7, 8, 9, 14, 15, 16, 17, 18, 19]
        script = f"""
const vm=require('vm');
const tiles={json.dumps(tiles)};
const MAP=[tiles.map(()=>1),tiles.slice(),tiles.map(()=>1)];
const context={{MAP,MAP_ROWS:MAP.length,MAP_COLS:tiles.length,Math,Object}};
vm.runInNewContext({surface!r}+`;globalThis.testApi={{
  cap:VEHICLE_SURFACE_CAPABILITY,
  allows:_vehicleSurfaceAllows
}};`,context);
const result={{}};
for(const [name,capability] of Object.entries(context.testApi.cap)){{
  result[name]=tiles.filter((tile,index)=>context.testApi.allows(1.5,index+.5,capability));
}}
console.log(JSON.stringify(result));
"""
        matrix = json.loads(run_node(script))
        self.assertEqual(matrix["ORDINARY"], [0, 19])
        self.assertEqual(matrix["AMBIENT_TRAFFIC"], [0, 19])
        self.assertEqual(matrix["SERVICE_ROUTE"], [0, 19])
        self.assertEqual(matrix["RACE"], [0, 18, 19])
        self.assertEqual(matrix["RESCUE_APPROACH"], [0, 8, 9, 19])
        self.assertEqual(matrix["BEACH_RESCUE"], [14])

    def test_ambient_graph_crosses_bridge_and_not_water(self):
        surface = surface_contract_source()
        graph = traffic_graph_source()
        script = f"""
const vm=require('vm');
const MAP_ROWS=43,MAP_COLS=43,BLOCK=10,BEACH_R0=43;
const MAP=Array.from({{length:MAP_ROWS}},()=>Array(MAP_COLS).fill(16));
for(let r=10;r<=13;r++)for(let c=0;c<MAP_COLS;c++)MAP[r][c]=0;
for(let r=10;r<=13;r++)for(let c=10;c<30;c++)MAP[r][c]=19;
const context={{MAP,MAP_ROWS,MAP_COLS,BLOCK,BEACH_R0,
  JAIL_CENTER_R:999,JAIL_CENTER_C:999,JAIL_RADIUS_TILES:1,Math,Map,Object}};
vm.runInNewContext({surface!r}+{graph!r}+`;globalThis.testApi={{
  build:_buildTrafficRoadGraph,
  find:_trafficFindNodePath,
  reset:()=>{{_trafficRoadGraph=null;_trafficPathCache.clear();}}
}};`,context);
let built=context.testApi.build();
let start=built.byKey.get('10:0'),goal=built.byKey.get('10:30');
const bridgePath=context.testApi.find(start,goal)?.map(node=>node.key)||null;
for(let r=10;r<=13;r++)for(let c=10;c<30;c++)MAP[r][c]=16;
context.testApi.reset();built=context.testApi.build();
start=built.byKey.get('10:0');goal=built.byKey.get('10:30');
const waterPath=context.testApi.find(start,goal)?.map(node=>node.key)||null;
console.log(JSON.stringify({{bridgePath,waterPath}}));
"""
        result = json.loads(run_node(script))
        self.assertEqual(result["bridgePath"], ["10:0", "10:10", "10:20", "10:30"])
        self.assertIsNone(result["waterPath"])

    def test_player_car_uses_full_footprint_and_race_is_explicit(self):
        car_point = function_body(WORLD, "isBlockedCar")
        car_body = function_body(WORLD, "_playerVehicleFootprintClear")
        capability = function_body(WORLD, "_playerVehicleSurfaceCapability")
        update_start = WORLD.index("// Применяем позицию с проверкой всей площади кузова")
        update_end = WORLD.index("// Гоночные бортики", update_start)
        movement = WORLD[update_start:update_end]

        self.assertIn("_vehicleSurfaceAllows(r, c, capability)", car_point)
        self.assertIn("model?.race", capability)
        self.assertIn("VEHICLE_SURFACE_CAPABILITY.RACE", capability)
        self.assertIn("[halfLength,halfWidth]", car_body)
        self.assertIn("[-halfLength,-halfWidth]", car_body)
        self.assertEqual(movement.count("_playerVehicleFootprintClear("), 3)
        self.assertNotIn("!isBlockedCar(newY, newX)", movement)

    def test_runtime_player_footprint_checks_nose_and_corners_at_both_angles(self):
        surface = surface_contract_source()
        capability = function_source(WORLD, "_playerVehicleSurfaceCapability")
        car_point = function_source(WORLD, "isBlockedCar")
        car_body = function_source(WORLD, "_playerVehicleFootprintClear")
        script = f"""
let MAP_ROWS=5,MAP_COLS=5;
let MAP=Array.from({{length:MAP_ROWS}},()=>Array(MAP_COLS).fill(0));
const QUEST_CAR_MODELS={{sedan:{{L:1.8,W:.88}},racer:{{L:1.8,W:.88,race:true}}}};
function resolveCarModel(id){{return QUEST_CAR_MODELS[id]||QUEST_CAR_MODELS.sedan;}}
function _openCityBridgeSurface(){{return false;}}
function _prisonIslandCollisionAt(){{return null;}}
function isBlocked(r,c){{
  const ri=Math.floor(r),ci=Math.floor(c);
  return ri<0||ci<0||ri>=MAP_ROWS||ci>=MAP_COLS||![0,18,19].includes(MAP[ri][ci]);
}}
{surface}
{capability}
{car_point}
{car_body}
const sedan={{model:'sedan',ang:0}};
const racer={{model:'racer',ang:0}};
const centreClear=!isBlockedCar(2.5,2.4,sedan);
MAP[2][3]=8;
const noseBlocked=!_playerVehicleFootprintClear(sedan,2.5,2.4,0);
MAP=Array.from({{length:MAP_ROWS}},()=>Array(MAP_COLS).fill(0));
MAP[3][2]=16;
const rotatedCornerBlocked=!_playerVehicleFootprintClear(sedan,2.4,2.5,Math.PI/2);
MAP=Array.from({{length:MAP_ROWS}},()=>Array(MAP_COLS).fill(18));
const raceTrackClear=_playerVehicleFootprintClear(racer,2.5,2.5,Math.PI/4);
const ordinaryTrackBlocked=!_playerVehicleFootprintClear(sedan,2.5,2.5,Math.PI/4);
console.log(JSON.stringify({{centreClear,noseBlocked,rotatedCornerBlocked,raceTrackClear,ordinaryTrackBlocked}}));
"""
        result = json.loads(run_node(script))
        self.assertEqual(result, {
            "centreClear": True,
            "noseBlocked": True,
            "rotatedCornerBlocked": True,
            "raceTrackClear": True,
            "ordinaryTrackBlocked": True,
        })

    def test_routes_share_capability_contract_without_changing_pedestrians(self):
        service = function_body(WORLD, "_vehicleRoadPassable")
        traffic = function_body(WORLD, "_trafficRoadTile")
        recovery = function_body(WORLD, "_recoverTrafficCarToRoad")
        pedestrian = function_body(WORLD, "isBlockedPed")
        self.assertIn("VEHICLE_SURFACE_CAPABILITY.SERVICE_ROUTE", service)
        self.assertIn("VEHICLE_SURFACE_CAPABILITY.AMBIENT_TRAFFIC", traffic)
        self.assertIn("VEHICLE_SURFACE_CAPABILITY.AMBIENT_TRAFFIC", recovery)
        self.assertIn("_trafficCarFootprintClear(car,nr,nc)", recovery)
        self.assertIn("isBlocked(r, c)", pedestrian)
        self.assertIn("const PASSABLE = new Set([0, 7, 8, 9, 14, 15, 17, 18, 19]);", WORLD)


if __name__ == "__main__":
    unittest.main()
