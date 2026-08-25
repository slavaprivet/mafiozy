import json
import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")

def _collision_results(cases):
    match = re.search(r"function _isBlockedBankInterior\(int,r,c\) \{.*?\n\}\n\nfunction _isBlockedInterior", WORLD, re.S)
    if not match:
        raise AssertionError("active bank collision helper not found")
    fn = match.group(0).rsplit("\n\nfunction _isBlockedInterior", 1)[0]
    script = fn + "\nconst cases=" + json.dumps(cases) + ";\nprocess.stdout.write(JSON.stringify(cases.map(x=>_isBlockedBankInterior(x.i,x.r,x.c))));"
    proc = subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True)
    return json.loads(proc.stdout)

class BankInteriorSpatialContractTests(unittest.TestCase):
    LAYOUTS = (("small",28,24,15),("medium",36,30,19),("large",44,36,23))

    def test_active_layout_and_visual_version(self):
        self.assertIn("const BANK_INTERIOR_VISUAL_VERSION = 6;", WORLD)
        for name,width,height,counter in self.LAYOUTS:
            self.assertRegex(WORLD, rf"{name}:\s*\{{\s*W:{width},\s*H:{height},.*counterRow:{counter}")
        self.assertIn("dataset.bankVisualVersion='6'", THREE)
        self.assertIn("visible-solids-match-collision-v6", THREE)
        self.assertIn("_LOCAL_PREVIEW&&_UP.has('previewbankinterior')", WORLD)

    def test_center_route_and_authored_openings_all_sizes(self):
        cases=[];expected=[]
        for _,width,height,counter in self.LAYOUTS:
            layout={"room":"lobby","W":width,"H":height,"counterRow":counter}
            for row in [height-1.8,counter+3,counter,counter-2,counter-4,1.0]:
                cases.append({"i":layout,"r":row,"c":width/2});expected.append(False)
            cases += [
                {"i":layout,"r":height-.1,"c":2},
                {"i":layout,"r":counter-4,"c":width-2},
                {"i":layout,"r":counter,"c":1.8},
                {"i":layout,"r":height-4.45,"c":3.35},
                {"i":layout,"r":counter+1.5,"c":width-.8},
            ];expected += [True]*5
        self.assertEqual(_collision_results(cases),expected)

    def test_teller_count_and_queue_leave_center_clear(self):
        self.assertIn("const wingCount=W<36?2:W<44?3:4",WORLD)
        self.assertIn("const wingCount=W<36?2:W<44?3:4,tellerCenters=[]",THREE)
        self.assertIn("[W/2-3,W/2+3]",WORLD);self.assertIn("[W/2-3,W/2+3]",THREE)
        self.assertIn("[[2.3,W/2-3.2],[W/2+3.2,W-2.3]]",THREE)
        self.assertNotIn("for(const r of [cr+2,H-3.8])",THREE)

    def test_declutter_is_size_tiered_and_exit_strip_is_clear(self):
        self.assertIn("vaultSmall=B.size==='small'||W<16",THREE)
        self.assertIn("vaultLarge=B.size==='large'||W>=19",THREE)
        self.assertIn("if(vaultLarge){wireCagePanel",THREE)
        self.assertNotIn("fileCabinets(W*.5,H-1.15",THREE)
        self.assertNotIn("const workC=W-1.65,workR=H-1.55",THREE)
        self.assertNotIn("roomSign('АДМИНИСТРАТОР'",THREE)
        self.assertNotIn("sofa(loungeStart+1.25",THREE)
        self.assertIn("if(W>=44)conferenceTable",THREE)

    def test_npcs_use_body_sweep_and_spawns_avoid_fixtures(self):
        self.assertGreaterEqual(WORLD.count("_canStandBankInterior("),7)
        self.assertIn("_isBlockedBankInterior(lobbyLayout,r,c)",WORLD)
        self.assertIn("int.W/2 - 4.2",WORLD);self.assertIn("int.W/2 + 4.2",WORLD)

    def test_bag_identity_contract_is_preserved(self):
        for symbol in ("_stableBankBagId","_bankRob.myBag.id","bank_bag_drop","bank_bag_pickup"):
            self.assertIn(symbol,WORLD)
        self.assertIn("for(const bag of B.bags||[])moneyBag",THREE)

    def test_open_roof_has_no_occluding_ceiling_slabs_and_runner_matches_2d(self):
        self.assertNotIn("new THREE.BoxGeometry(2.4*S,.12,.55*S)", THREE)
        self.assertNotIn("new THREE.RingGeometry(1.5*S,1.92*S,32)", THREE)
        self.assertIn("dataset.bankFloorStyle='warm-stone-red-runner-v6'", THREE)
        self.assertIn("dataset.bankNamePresentation='hud-only-no-floating-face-label'", THREE)
        self.assertNotIn("roomSign(B.name||'ГОРОДСКОЙ БАНК'", THREE)
        self.assertIn("floorZone(W/2,runnerMid,3.2,runnerLength,runnerRed,.064)", THREE)
        self.assertIn("floorZone(W/2+side*1.56,runnerMid,.09,runnerLength,gold,.071)", THREE)

    def test_bank_guards_keep_role_weapon_and_visible_tracer_in_3d(self):
        self.assertIn("x?.role||x?.type||x?._arcKey", WORLD)
        self.assertIn("x.role||x.type||x._arcKey||'civilian'", WORLD)
        self.assertIn("const visualBulletSpeed = Math.max(3.5, dist / .32);", WORLD)
        self.assertGreaterEqual(WORLD.count("speed:visualBulletSpeed, fullSizeNpc:true, bulletScale:1.12, trailScale:1.65"), 2)
        self.assertIn("_bankInt&&x.type==='guard'?'Охранник банка':''", WORLD)
        self.assertIn("speech:_bankInt&&x.type==='guard'?'':", WORLD)

    def test_wall_finish_has_no_overlapping_ends_or_shadow_acne(self):
        self.assertIn("const wallVolume=(geometry,material,c,y,r)=>", THREE)
        self.assertIn("mesh.castShadow=false;mesh.receiveShadow=false", THREE)
        self.assertIn("wall=new THREE.MeshLambertMaterial({color:0xd4cab7})", THREE)
        self.assertIn("bankWallFinish='single-volume-matte-no-overlay-v6'", THREE)
        self.assertNotIn("const wallFinish=", THREE)
        self.assertNotIn("finishSpan=", THREE)
        self.assertNotIn("(c1-c0)*S+.05,.22,.36*S", THREE)
        self.assertNotIn("(r1-r0)*S+.05),material===wallDark", THREE)

    def test_room_signs_are_readable_and_vault_door_is_in_a_portal(self):
        self.assertIn("canvas.width=768;canvas.height=192", THREE)
        self.assertIn("readableScale=Math.max(1.35,scale)", THREE)
        self.assertIn("for(const side of [-1,1]){const jamb=", THREE)
        self.assertIn("const lintel=addRaw(new THREE.BoxGeometry(5.02,.34,.5*S)", THREE)
        self.assertGreaterEqual(THREE.count("W/2-1.55"), 2)
        self.assertGreaterEqual(THREE.count("W/2+1.55"), 2)

    def test_panicking_civilians_use_separate_exit_lanes(self):
        self.assertIn("function _bankPanicSeparation(int,npc)", WORLD)
        self.assertIn("function _setBankPanicRoute(int,npc,speed=3.8)", WORLD)
        self.assertIn("const lanes=[-1.5,-.9,-.3,.3,.9,1.5]", WORLD)
        self.assertIn("sep=_bankPanicSeparation(int,npc)", WORLD)
        self.assertIn("previewBankPanic='seeded-separated-exit-lanes'", WORLD)

if __name__ == "__main__": unittest.main()


