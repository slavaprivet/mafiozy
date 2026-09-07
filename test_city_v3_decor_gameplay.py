"""Execute the actual classic-world civic collision functions in Node.

Only environment data is synthetic; no duplicate implementation of the
classification, registration or approach rules is used by these regressions.
"""
from pathlib import Path
import json
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parent
WORLD = (ROOT / 'world.html').read_text(encoding='utf-8')


def function_source(name):
    start = WORLD.index('function ' + name + '(')
    brace = WORLD.index('{', start)
    depth, quote, escaped = 0, None, False
    for index in range(brace, len(WORLD)):
        char = WORLD[index]
        if quote:
            if escaped:
                escaped = False
            elif char == '\\':
                escaped = True
            elif char == quote:
                quote = None
        elif char in "'\"`":
            quote = char
        elif char == '{':
            depth += 1
        elif char == '}':
            depth -= 1
            if depth == 0:
                return WORLD[start:index + 1]
    raise AssertionError(name + ': unterminated function')


FUNCTIONS = '\n'.join(function_source(name) for name in (
    '_cityV3DecorGate', '_cityV3DecorBlocked',
    '_cityV3AcceptedGameplayAnchorConflict', '_cityV3DecorSurface',
    '_registerCityV3DecorCollisions', '_previewApproachCityV3Decor',
    'isBlocked', 'isBlockedPed', 'isBlockedCar', '_serviceVehicleBodyPointBlocked',
))

ENVIRONMENT = r"""
const assert=require('node:assert/strict');
const _LOCAL_PREVIEW=true, _UP=new URLSearchParams('preview=1&previewcityv3=stage-a&cityv3decor=1');
const OWNER='CITY_V3_CIVIC_PARK_V2_ROOT', _cityV3DecorBodies=new Map();
const MAP_ROWS=200,MAP_COLS=180,MAP=Array.from({length:200},()=>Array(180).fill(8));
const JAIL_CENTER_R=76,JAIL_CENTER_C=76,JAIL_RADIUS_TILES=7,DIST_ACTION_RAD=2.8;
const POI=[],BUSINESS_POIS=[],DISTRICTS=[],_beachDecor=[],_cityV3ActiveAcceptedBuildings=new Map();
const player={r:120,c:120,vr:2,vc:3,walking:true};const window={};
let road=false,wholeBuilding=false,businessBuilding=false,prison=null,bridgeOpen=false,container=false;
let civicSurface=null,acceptedSurface=null,vehicleSurfaceAllowed=true;
const inRaceTrack=()=>road,_isThreeWholeBuildingBlocked=()=>wholeBuilding;
const _businessExteriorPedBlocked=()=>businessBuilding,_prisonIslandCollisionAt=()=>prison;
const _openCityBridgeSurface=()=>bridgeOpen,_isPortContainerSolid=()=>container;
const _cityV3AcceptedCorridorAt=(contract,r,c)=>contract.r===r&&contract.c===c;
const _cityV3CivicSurfaceAt=()=>civicSurface,_cityV3AcceptedSurfaceAt=()=>acceptedSurface;
const _cityV3RailBlocksPed=()=>false,_cityV3RailBlocksCar=()=>false;
const _isRaceWaterEdgeBlockedForPed=()=>false;
const _playerVehicleSurfaceCapability=()=>1,_vehicleSurfaceAllows=()=>vehicleSurfaceAllowed;
const _SERVICE_ROUTE_FOOTPRINT_CAPABILITIES=[1],PASSABLE=new Set([0,8,9,14,19]);
const body=(id='test')=>({id,minR:26,maxR:28,minC:66,maxC:68});
"""


class CivicDecorGameplayTests(unittest.TestCase):
    def run_js(self, script, *, environment=ENVIRONMENT, functions=FUNCTIONS):
        run = subprocess.run(['node', '-e', environment + '\n' + functions + '\n' + script],
                             cwd=ROOT, capture_output=True, text=True, encoding='utf-8', timeout=20)
        self.assertEqual(run.returncode, 0, run.stderr or run.stdout)

    def test_surface_map_props_and_hq_are_authoritative(self):
        self.run_js(r"""
for(const [tile,want] of [[8,'grass'],[9,'pavement'],[14,'sand'],[16,'water'],[0,'road'],[18,'road'],[19,'road'],[1,'building'],[2,'protected'],[3,'protected'],[4,'protected'],[6,'protected'],[7,'protected'],[99,'unknown']]){
  MAP[27][67]=tile;assert.equal(_cityV3DecorSurface(27,67),want,'tile '+tile);
}
MAP[27][67]=8;
_beachDecor.push({r:27,c:67,scale:2});assert.equal(_cityV3DecorSurface(28.1,67),'protected');_beachDecor.length=0;
for(const field of ['hq','intel','escape','sabotage']){
  DISTRICTS.push({id:'hq-test',[field]:field==='sabotage'?[{r:27,c:67}]:{r:27,c:67}});
  assert.equal(_cityV3DecorSurface(29,67),'protected',field);DISTRICTS.length=0;
}
POI.push({r:27,c:67});assert.equal(_cityV3DecorSurface(27,67),'protected');POI.length=0;
_cityV3ActiveAcceptedBuildings.set('door',{contract:{r:27,c:67}});assert.equal(_cityV3DecorSurface(27,67),'door');_cityV3ActiveAcceptedBuildings.clear();
assert.equal(_cityV3DecorSurface(145,55),'rail');
assert.equal(_cityV3DecorSurface(NaN,67),'unknown');assert.equal(_cityV3DecorSurface(-1,67),'unknown');
assert.equal(_cityV3DecorSurface(76,76),'protected');
wholeBuilding=true;assert.equal(_cityV3DecorSurface(27,67),'building');wholeBuilding=false;
container=true;assert.equal(_cityV3DecorSurface(27,67),'protected');
""")

    def test_invalid_late_body_and_occupied_player_leave_no_registration(self):
        self.run_js(r"""
for(const bad of [{...body('bad'),maxR:NaN},{...body('bad'),maxC:66},{...body('bad'),maxR:40},body('good')]){
 const result=_registerCityV3DecorCollisions(OWNER,[body('good'),bad]);
 assert.equal(result.ok,false);assert.equal(_cityV3DecorBodies.size,0);
}
player.r=28.2;player.c=67;
assert.equal(_registerCityV3DecorCollisions(OWNER,[body()]).reason,'player-occupied');assert.equal(_cityV3DecorBodies.size,0);
player.r=120;player.c=120;
MAP[27][67]=16;assert.equal(_registerCityV3DecorCollisions(OWNER,[body()]).reason,'body-surface');assert.equal(_cityV3DecorBodies.size,0);
""")

    def test_registration_owns_frozen_copy_and_exact_boundaries(self):
        self.run_js(r"""
const input=body();assert.equal(_registerCityV3DecorCollisions(OWNER,[input]).ok,true);
input.maxR=100;assert.equal(_cityV3DecorBlocked(50,67),false);
assert.equal(Object.isFrozen(_cityV3DecorBodies.get(OWNER)),true);
assert.equal(Object.isFrozen(_cityV3DecorBodies.get(OWNER)[0]),true);
for(const [r,c] of [[26,66],[28,68],[27,67]])assert.equal(_cityV3DecorBlocked(r,c),true);
assert.equal(_cityV3DecorBlocked(28.00001,67),false);
assert.equal(_registerCityV3DecorCollisions(OWNER,[body('other')]).ok,false);
assert.equal(_cityV3DecorBodies.get(OWNER).length,1);
_cityV3DecorBodies.delete(OWNER);assert.equal(_cityV3DecorBlocked(27,67),false);
""")

    def test_owner_and_preview_gate_reject_before_mutation(self):
        self.run_js(r"""
assert.equal(_registerCityV3DecorCollisions('wrong',[body()]).ok,false);
_UP.delete('cityv3decor');assert.equal(_registerCityV3DecorCollisions(OWNER,[body()]).ok,false);
assert.equal(_previewApproachCityV3Decor({r:27,c:67}).ok,false);
assert.equal(_cityV3DecorBodies.size,0);
""")

    def test_generic_blocker_precedes_civic_and_prison_surface_overrides(self):
        self.run_js(r"""
_cityV3DecorBodies.set(OWNER,[body()]);
for(const which of ['prison','civic','accepted']){
 prison=which==='prison'?{blocked:false}:null;civicSurface=which==='civic'?{blocked:false}:null;acceptedSurface=which==='accepted'?{blocked:false}:null;
 assert.equal(isBlocked(27,67),true,which+' override bypassed decor');
}
""")

    def test_ped_car_and_service_blockers_precede_bridge_override(self):
        self.run_js(r"""
_cityV3DecorBodies.set(OWNER,[body()]);bridgeOpen=true;
assert.equal(isBlockedPed(27,67),true,'ped bridge override bypassed decor');
assert.equal(isBlockedCar(27,67),true,'car bridge override bypassed decor');
assert.equal(_serviceVehicleBodyPointBlocked(27,67),true,'service body bypassed decor');
""")

    def test_focus_checks_player_footprint_and_never_places_inside_fountain(self):
        self.run_js(r"""
assert.equal(_registerCityV3DecorCollisions(OWNER,[body()]).ok,true);
// Reject first (south) center using a legacy obstacle; next east center looks
// walkable but its southeast footprint corner is blocked. North is safe.
MAP[29][67]=1;MAP[26][69]=1;
const result=_previewApproachCityV3Decor({r:27,c:67,id:'DEC-FNT-CENTRAL-01'});
assert.equal(result.ok,true);assert.equal(player.r,25);assert.equal(player.c,67);
assert.equal(player.vr,0);assert.equal(player.vc,0);assert.equal(player.walking,false);
assert.equal(_cityV3DecorBlocked(player.r,player.c),false);
assert.ok(window._studioTeleportUntil>Date.now());
const before={...player};wholeBuilding=true;
assert.equal(_previewApproachCityV3Decor({r:27,c:67}).reason,'no-safe-approach');assert.deepEqual(player,before);
""")

    def test_bootstrap_has_initialized_decor_storage_before_first_map_generation(self):
        declaration = re.search(r'const _cityV3DecorBodies\s*=\s*new Map\(\);', WORLD)
        self.assertIsNotNone(declaration)
        self.assertLess(declaration.start(), WORLD.index('\nbuildMap();'))
        # Execute exactly the production declaration before a hoisted collision
        # call, with later lexical game state deliberately still uninitialized.
        script = declaration.group(0) + '\n' + "assert.equal(_cityV3DecorBlocked(27,67),false);\nconst laterGameState=new Map();"
        self.run_js(script, environment="const assert=require('node:assert/strict');",
                    functions=function_source('_cityV3DecorBlocked'))


if __name__ == '__main__':
    unittest.main()
