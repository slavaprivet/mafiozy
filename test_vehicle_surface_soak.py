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


def function_source(name: str) -> str:
    marker = f"function {name}("
    signature = WORLD.find(marker)
    body = function_body(WORLD, name)
    body_start = WORLD.find("{", signature + len(marker))
    return WORLD[signature:body_start + len(body)]


def surface_contract_source() -> str:
    start = WORLD.index("const VEHICLE_SURFACE_CAPABILITY = Object.freeze({")
    end = WORLD.index("// Спецтранспорт едет ПО ДОРОГАМ.", start)
    return WORLD[start:end]


def traffic_graph_source() -> str:
    start = WORLD.index("const _TRAFFIC_PATH_CACHE_MAX=1024;")
    end = WORLD.index("function _trafficGoalScore", start)
    return WORLD[start:end]


def service_footprint_source() -> str:
    start = WORLD.index("const _SERVICE_ROUTE_FOOTPRINT_CAPABILITIES=Object.freeze([")
    end = WORLD.index("// Ближайший дорожный тайл", start)
    return WORLD[start:end]


def vehicle_route_source() -> str:
    start = WORLD.index("function _setVehicleRoute(")
    end = WORLD.index("function _ambulanceSceneParking", start)
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


def production_functions(*names: str) -> str:
    return "\n".join(function_source(name) for name in names)


def full_size_surface_fixture() -> str:
    """A deterministic 180x200 topology fixture; movement logic stays production JS."""
    return r"""
const BLOCK=10,BEACH_R0=150,BEACH_R1=165;
const CITY_CANAL_C0=80,CITY_CANAL_C1=100,CITY_BRIDGE_R0=47,CITY_BRIDGE_R1=56;
let MAP_ROWS=200,MAP_COLS=180;
const raw=Array.from({length:MAP_ROWS},()=>Array(MAP_COLS).fill(1));
for(let r=1;r<MAP_ROWS-1;r++)for(let c=1;c<MAP_COLS-1;c++){
  let tile;
  if(c>=CITY_CANAL_C0&&c<CITY_CANAL_C1&&r<BEACH_R0){
    tile=(r>=CITY_BRIDGE_R0&&r<CITY_BRIDGE_R1)?19:16;
  }else if(r>=175&&r<185&&c>=28&&c<57){
    tile=17;
  }else if(r>=165&&r<175&&c>=36&&c<45){
    tile=15;
  }else if(r>=BEACH_R0){
    tile=r<BEACH_R1?14:16;
  }else{
    const roadR=r%BLOCK<=3,roadC=c%BLOCK<=3;
    const sideR=r%BLOCK===4||r%BLOCK===BLOCK-1;
    const sideC=c%BLOCK===4||c%BLOCK===BLOCK-1;
    tile=(roadR||roadC)?0:(sideR||sideC)?9:(((r/BLOCK|0)+(c/BLOCK|0))%3===0?8:1);
  }
  raw[r][c]=tile;
}
// Dedicated race asphalt is intentionally disjoint from the ordinary network.
for(let r=170;r<180;r++)for(let c=105;c<170;c++)raw[r][c]=18;
// Put every non-road surface beside an otherwise valid road. This makes a body
// crossing observable even when its centre remains on asphalt.
const edgeTiles=[16,8,9,14,15,17,18];
for(let i=0;i<edgeTiles.length;i++){
  const r=112+i*4;
  for(let c=22;c<=32;c++)raw[r][c]=0;
  for(let c=22;c<=32;c++)raw[r+1][c]=edgeTiles[i];
}
let tracedReads=null;
let MAP=raw.map((row,r)=>new Proxy(row,{get(target,key,receiver){
  if(tracedReads&&typeof key==='string'&&/^\d+$/.test(key)){
    const c=Number(key);tracedReads.push({r,c,tile:target[c]});
  }
  return Reflect.get(target,key,receiver);
}}));
"""


RUNTIME_STUBS = r"""
const JAIL_CENTER_R=999,JAIL_CENTER_C=999,JAIL_RADIUS_TILES=1;
const QUEST_CAR_MODELS={sedan:{L:1.8,W:.88},racer:{L:1.8,W:.88,race:true}};
function resolveCarModel(id){return QUEST_CAR_MODELS[id]||QUEST_CAR_MODELS.sedan;}
function inArena(){return false;}
function inLair(){return false;}
function _prisonIslandCollisionAt(){return null;}
function _cityV3CivicSurfaceAt(){return null;}
function _isPortContainerSolid(){return false;}
function _isThreeWholeBuildingBlocked(){return false;}
const PASSABLE=new Set([0,7,8,9,14,15,17,18,19]);
"""


class VehicleSurfaceSoakTests(unittest.TestCase):
    maxDiff = None

    def test_route_service_body_rejects_each_nonroad_edge_surface(self):
        script = f"""
let MAP_ROWS=9,MAP_COLS=11;
let MAP=Array.from({{length:MAP_ROWS}},()=>Array(MAP_COLS).fill(0));
function _isPortContainerSolid(){{return false;}}
function _isThreeWholeBuildingBlocked(){{return false;}}
{surface_contract_source()}
{service_footprint_source()}
const result={{}};
for(const tile of [16,8,9,14,15,17,18]){{
  MAP=Array.from({{length:MAP_ROWS}},()=>Array(MAP_COLS).fill(0));
  for(let c=0;c<MAP_COLS;c++)MAP[4][c]=tile;
  result[tile]=_serviceVehicleFootprintClear({{kind:'firetruck',ang:0}},3.5,5.5,0);
}}
console.log(JSON.stringify(result));
"""
        result = json.loads(run_node(script))
        self.assertEqual(result, {str(tile): False for tile in (16, 8, 9, 14, 15, 17, 18)})

    def test_seeded_player_ambient_and_route_service_footprint_soak(self):
        script = f"""
{full_size_surface_fixture()}
{RUNTIME_STUBS}
{surface_contract_source()}
{service_footprint_source()}
{production_functions(
    '_vehicleRoadPassable',
    '_trafficRoadTile',
    '_trafficHardTileAt',
    '_trafficCarFootprintClear',
    'isBlocked',
    '_openCityBridgeSurface',
    '_playerVehicleSurfaceCapability',
    'isBlockedCar',
    '_playerVehicleFootprintClear',
)}
let seed=0x5EEDC0DE;
function random(){{
  seed^=seed<<13;seed^=seed>>>17;seed^=seed<<5;
  return (seed>>>0)/4294967296;
}}
const allowed=new Set([0,19]),forbidden=new Set([16,8,9,14,15,17,18]);
function soak(label,predicate,steps=16000){{
  let accepted=0,rejected=0,reads=0;
  const violations={{}},coverage=new Set();
  for(let i=0;i<steps;i++){{
    const r=1+random()*(MAP_ROWS-2),c=1+random()*(MAP_COLS-2),ang=random()*Math.PI*2;
    tracedReads=[];
    const clear=predicate(r,c,ang);
    const probeReads=tracedReads;tracedReads=null;
    reads+=probeReads.length;
    for(const sample of probeReads)if(forbidden.has(sample.tile))coverage.add(sample.tile);
    if(clear){{
      accepted++;
      for(const sample of probeReads)if(!allowed.has(sample.tile)){{
        const key=String(sample.tile);violations[key]=(violations[key]||0)+1;
      }}
    }}else rejected++;
  }}
  return {{label,steps,accepted,rejected,reads,coverage:[...coverage].sort((a,b)=>a-b),violations}};
}}
const sedan={{model:'sedan',ang:0}};
const ambient={{parked:false,model:QUEST_CAR_MODELS.sedan,dirDy:0,dirDx:1}};
const service={{kind:'firetruck',ang:0}};
const player=soak('player',(r,c,ang)=>{{sedan.ang=ang;return _playerVehicleFootprintClear(sedan,r,c,ang);}});
const traffic=soak('ambient',(r,c,ang)=>{{ambient.dirDy=Math.sin(ang);ambient.dirDx=Math.cos(ang);return _trafficRoadTile(r,c)&&_trafficCarFootprintClear(ambient,r,c);}});
const routeService=soak('route-service',(r,c,ang)=>{{service.ang=ang;return _vehicleRoadPassable(r,c)&&_serviceVehicleFootprintClear(service,r,c,ang);}});
console.log(JSON.stringify({{seed:0x5EEDC0DE,player,traffic,routeService}}));
"""
        result = json.loads(run_node(script))
        required_coverage = [8, 9, 14, 15, 16, 17, 18]
        self.assertEqual(result["seed"], 0x5EEDC0DE)
        for mode in ("player", "traffic", "routeService"):
            report = result[mode]
            self.assertEqual(report["steps"], 16000)
            self.assertGreater(report["accepted"], 1000, report)
            self.assertGreater(report["reads"], report["steps"], report)
            self.assertEqual(report["coverage"], required_coverage, report)
            self.assertEqual(report["violations"], {}, report)

    def test_rescue_footprint_modes_are_explicit_and_narrow(self):
        script = f"""
let MAP_ROWS=9,MAP_COLS=11;
let MAP=Array.from({{length:MAP_ROWS}},()=>Array(MAP_COLS).fill(0));
function _isPortContainerSolid(){{return false;}}
function _isThreeWholeBuildingBlocked(){{return false;}}
{surface_contract_source()}
{service_footprint_source()}
function edgeResult(vehicle,tile){{
  MAP=Array.from({{length:MAP_ROWS}},()=>Array(MAP_COLS).fill(0));
  for(let c=0;c<MAP_COLS;c++)MAP[4][c]=tile;
  return _serviceVehicleFootprintClear(
    vehicle,3.5,5.5,0,_serviceVehicleFootprintCapabilities(vehicle));
}}
const ordinaryAmbulance={{kind:'ambulance',ang:0}};
const beachAmbulance={{kind:'ambulance',ang:0,_beachRescueRoute:true}};
const gasFire={{kind:'firetruck',ang:0,payload:{{fireRef:{{kind:'gas_station'}}}}}};
const fallbackTow={{kind:'tow',ang:0,_offroadRoute:true}};
const result={{
  beachSeamExplicit:edgeResult(beachAmbulance,14),
  beachSeamOrdinary:edgeResult(ordinaryAmbulance,14),
  gas:{{}},fallback:{{}},
}};
for(const tile of [8,9,14,15,16,17,18]){{
  result.gas[tile]=edgeResult(gasFire,tile);
  result.fallback[tile]=edgeResult(fallbackTow,tile);
}}
console.log(JSON.stringify(result));
"""
        result = json.loads(run_node(script))
        self.assertTrue(result["beachSeamExplicit"])
        self.assertFalse(result["beachSeamOrdinary"])
        expected_rescue = {
            "8": True,
            "9": True,
            "14": False,
            "15": False,
            "16": False,
            "17": False,
            "18": False,
        }
        self.assertEqual(result["gas"], expected_rescue)
        self.assertEqual(result["fallback"], expected_rescue)

    def test_beach_route_authors_outbound_and_return_sand_waypoints(self):
        script = f"""
let MAP_ROWS=12,MAP_COLS=12,BEACH_R1=10;
let MAP=Array.from({{length:MAP_ROWS}},()=>Array(MAP_COLS).fill(0));
for(let r=5;r<=7;r++)for(let c=0;c<MAP_COLS;c++)MAP[r][c]=14;
function _isPortContainerSolid(){{return false;}}
function _isThreeWholeBuildingBlocked(){{return false;}}
let roadPath=[];
function _bfsRoadPathForVehicle(){{return roadPath.map(point=>({{...point}}));}}
function _bfsFireStationPath(){{return null;}}
{surface_contract_source()}
{service_footprint_source()}
{vehicle_route_source()}
roadPath=[{{r:2.5,c:5.5}},{{r:3.5,c:5.5}},{{r:4.5,c:5.5}}];
const outbound={{kind:'ambulance',ang:Math.PI/2}};
_setVehicleRoute(outbound,2.5,5.5,6.5,5.5);
const outboundSand=outbound.path.filter(point=>MAP[Math.floor(point.r)]?.[Math.floor(point.c)]===14).length;
const outboundCaps=_serviceVehicleFootprintCapabilities(outbound);
const outboundSeamClear=_serviceVehicleFootprintClear(outbound,4.5,5.5,Math.PI/2,outboundCaps);
roadPath=[{{r:4.5,c:5.5}},{{r:3.5,c:5.5}},{{r:2.5,c:5.5}}];
const returning={{kind:'ambulance',ang:-Math.PI/2}};
_setVehicleRoute(returning,6.5,5.5,2.5,5.5);
const returnSand=returning.path.filter(point=>MAP[Math.floor(point.r)]?.[Math.floor(point.c)]===14).length;
const returnCaps=_serviceVehicleFootprintCapabilities(returning);
const returnSeamClear=_serviceVehicleFootprintClear(returning,4.5,5.5,-Math.PI/2,returnCaps);
const returnDefaultBlocked=!_serviceVehicleFootprintClear(returning,4.5,5.5,-Math.PI/2);
const returnFlagBeforeReset=returning._beachRescueRoute;
roadPath=[{{r:2.5,c:5.5}},{{r:3.5,c:5.5}}];
_setVehicleRoute(returning,2.5,5.5,3.5,5.5);
console.log(JSON.stringify({{
  outboundFlag:outbound._beachRescueRoute,outboundSand,outboundSeamClear,
  returnFlagBeforeReset,returnSand,returnSeamClear,returnDefaultBlocked,
  ordinaryReset:!returning._beachRescueRoute&&!returning._offroadRoute,
}}));
"""
        result = json.loads(run_node(script))
        self.assertTrue(result["outboundFlag"])
        self.assertGreater(result["outboundSand"], 0)
        self.assertTrue(result["outboundSeamClear"])
        self.assertTrue(result["returnFlagBeforeReset"])
        self.assertGreater(result["returnSand"], 0)
        self.assertTrue(result["returnSeamClear"])
        self.assertTrue(result["returnDefaultBlocked"])
        self.assertTrue(result["ordinaryReset"])

    def test_bridge_cut_race_and_rescue_capability_isolation(self):
        script = f"""
{full_size_surface_fixture()}
{RUNTIME_STUBS}
{surface_contract_source()}
{traffic_graph_source()}
const tiles=[0,8,9,14,15,16,17,18,19];
const matrix={{}};
for(const [name,capability] of Object.entries(VEHICLE_SURFACE_CAPABILITY)){{
  matrix[name]=tiles.filter(tile=>{{raw[20][20]=tile;return _vehicleSurfaceAllows(20.5,20.5,capability);}});
}}
let graph=_buildTrafficRoadGraph();
let start=graph.byKey.get('50:70'),goal=graph.byKey.get('50:100');
const intact=_trafficFindNodePath(start,goal)?.map(node=>node.key)||null;
for(let r=CITY_BRIDGE_R0;r<CITY_BRIDGE_R1;r++)for(let c=CITY_CANAL_C0;c<CITY_CANAL_C1;c++)raw[r][c]=16;
_trafficRoadGraph=null;_trafficPathCache.clear();graph=_buildTrafficRoadGraph();
start=graph.byKey.get('50:70');goal=graph.byKey.get('50:100');
const cut=_trafficFindNodePath(start,goal)?.map(node=>node.key)||null;
console.log(JSON.stringify({{matrix,intact,cut}}));
"""
        result = json.loads(run_node(script))
        self.assertEqual(result["matrix"]["ORDINARY"], [0, 19])
        self.assertEqual(result["matrix"]["AMBIENT_TRAFFIC"], [0, 19])
        self.assertEqual(result["matrix"]["SERVICE_ROUTE"], [0, 19])
        self.assertEqual(result["matrix"]["RACE"], [0, 18, 19])
        self.assertEqual(result["matrix"]["RESCUE_APPROACH"], [0, 8, 9, 19])
        self.assertEqual(result["matrix"]["BEACH_RESCUE"], [14])
        self.assertEqual(result["intact"], ["50:70", "50:80", "50:90", "50:100"])
        self.assertIsNone(result["cut"])


if __name__ == "__main__":
    unittest.main()
