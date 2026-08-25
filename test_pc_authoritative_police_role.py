import json
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")


def extract_function(name: str) -> str:
    start = WORLD.index(f"function {name}(")
    brace = WORLD.index("{", start)
    depth = 0
    quote = None
    escaped = False
    for index in range(brace, len(WORLD)):
        char = WORLD[index]
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
                return WORLD[start:index + 1]
    raise AssertionError(f"unterminated function {name}")


class PcAuthoritativePoliceRoleTests(unittest.TestCase):
    def test_every_admitted_self_snapshot_reconciles_server_role(self):
        snap = WORLD[WORLD.index("} else if (pkt.t === 'snap') {"):
                     WORLD.index("const seen = new Set();")]
        self.assertIn(
            "if(typeof d.me.police==='boolean')"
            "_applyAuthoritativePoliceEmployment(d.me.police);",
            snap,
        )
        self.assertEqual(WORLD.count("_applyAuthoritativePoliceEmployment(d.me.police)"), 1)

    def test_server_true_and_false_override_reload_cache_idempotently(self):
        helper = extract_function("_applyAuthoritativePoliceEmployment")
        script = f"""
let calls={{save:0,uniform:0,restore:0,gang:0,status:0,modal:0,profile:0,weapon:0,picker:0,perks:0}};
let QP={{look:{{skin:4,hair:2,hat:7}}}};
let _policeState={{employed:false,missions:[{{id:'kept'}}],cuffs:2,escort:null,earnedXp:30,civilianLook:null}};
let _profileTab='status',_wepPickOpen=true;
function _disbandGangForPolice(){{calls.gang++;}}
function _applyPoliceUniform(){{calls.uniform++;QP.look={{police:true,hat:2}};}}
function _setPoliceLook(look){{calls.restore++;QP.look={{...look}};}}
function _savePoliceState(){{calls.save++;}}
function _refreshMafiaPerks(){{calls.perks++;}}
function renderJobStatus(){{calls.status++;}}
function renderPoliceModal(){{calls.modal++;}}
function renderProfileTab(){{calls.profile++;}}
function renderWeaponHud(){{calls.weapon++;}}
function renderWeaponPick(){{calls.picker++;}}
{helper}
const joined=_applyAuthoritativePoliceEmployment(true);
const afterJoin={{employed:_policeState.employed,look:QP.look,civilian:_policeState.civilianLook,missions:_policeState.missions.slice(),calls:{{...calls}}}};
const repeated=_applyAuthoritativePoliceEmployment(true);
const afterRepeat={{...calls}};
const resigned=_applyAuthoritativePoliceEmployment(false);
const afterResign={{employed:_policeState.employed,look:QP.look,civilian:_policeState.civilianLook,missions:_policeState.missions.slice(),calls:{{...calls}}}};
process.stdout.write(JSON.stringify({{joined,repeated,resigned,afterJoin,afterRepeat,afterResign}}));
"""
        run = subprocess.run(
            ["node", "-e", script], cwd=ROOT, check=True,
            capture_output=True, text=True, encoding="utf-8",
        )
        result = json.loads(run.stdout)
        self.assertTrue(result["joined"])
        self.assertTrue(result["afterJoin"]["employed"])
        self.assertTrue(result["afterJoin"]["look"]["police"])
        self.assertEqual(result["afterJoin"]["civilian"]["hat"], 7)
        self.assertEqual(result["afterJoin"]["missions"], [{"id": "kept"}])
        self.assertFalse(result["repeated"])
        self.assertEqual(result["afterRepeat"], result["afterJoin"]["calls"])
        self.assertTrue(result["resigned"])
        self.assertFalse(result["afterResign"]["employed"])
        self.assertNotIn("police", result["afterResign"]["look"])
        self.assertEqual(result["afterResign"]["look"]["hat"], 7)
        self.assertIsNone(result["afterResign"]["civilian"])
        self.assertEqual(result["afterResign"]["missions"], [{"id": "kept"}])
        self.assertEqual(result["afterResign"]["calls"]["status"], 2)
        self.assertEqual(result["afterResign"]["calls"]["uniform"], 1)
        self.assertEqual(result["afterResign"]["calls"]["restore"], 1)
        for key in ("save", "status", "modal", "profile", "weapon", "picker", "perks"):
            self.assertEqual(result["afterResign"]["calls"][key], 2, key)

    def test_hud_uniform_and_actions_share_authoritative_employment_flag(self):
        self.assertIn("if(_policeState.employed){const p=_policeProgress();", WORLD)
        self.assertIn("function _applyPoliceUniform(){if(!_policeState.employed)return;", WORLD)
        self.assertIn("if(!_policeState.employed){showToast('Шокер доступен только копу на службе'", WORLD)
        self.assertIn("const role=_policeState.employed?'police'", WORLD)
        self.assertIn("role: prisonBooked ? 'prisoner' : (_policeState?.employed ? 'police'", WORLD)


if __name__ == "__main__":
    unittest.main()
