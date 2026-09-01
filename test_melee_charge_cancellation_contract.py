"""Contracts for cancelling stale heavy-melee charge across weapon/reconnect."""

import json
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")
BOT = (ROOT / "mafiozi_bot.py").read_text(encoding="utf-8")


class MeleeChargeCancellationContractTests(unittest.TestCase):
    def test_transient_reset_clears_guard_charge_pose_and_witnesses_reason(self):
        start = WORLD.index("function _resetMeleeTransientState(")
        end = WORLD.index("\n}", start) + 2
        helper = WORLD[start:end]
        script = f"""
let _meleeBlockHeld=true;
let _meleeChargeStartedAt=1234;
let _punchAnim={{seq:7}};
const document={{documentElement:{{dataset:{{}}}}}};
{helper}
_resetMeleeTransientState('probe');
console.log(JSON.stringify({{
  block:_meleeBlockHeld,
  charge:_meleeChargeStartedAt,
  pose:_punchAnim,
  blockWitness:document.documentElement.dataset.meleeBlock,
  chargeWitness:document.documentElement.dataset.meleeCharge
}}));
"""
        result = subprocess.run(
            ["node", "-e", script], cwd=ROOT, check=True,
            capture_output=True, text=True,
        )
        self.assertEqual(json.loads(result.stdout), {
            "block": False,
            "charge": 0,
            "pose": None,
            "blockWitness": "released:probe",
            "chargeWitness": "released:probe",
        })

    def test_both_socket_boundaries_reset_before_new_melee_state(self):
        open_start = WORLD.index("socket.onopen = () => {")
        open_end = WORLD.index("socket.onmessage", open_start)
        open_slice = WORLD[open_start:open_end]
        close_start = WORLD.index("socket.onclose = () => {", open_end)
        close_end = WORLD.index("\n  };", close_start)
        close_slice = WORLD[close_start:close_end]
        self.assertIn("_resetMeleeTransientState('reconnect-open');", open_slice)
        self.assertIn("_resetMeleeTransientState('reconnect-close');", close_slice)
        self.assertLess(
            close_slice.index("_resetMeleeTransientState('reconnect-close');"),
            close_slice.index("const wasConnected = wsConnected;"),
        )

    def test_armed_or_locked_state_cancels_charge_before_input(self):
        update_guard = (
            "if(_meleeChargeStartedAt&&(_isArmed()||_meleeActionLocked()))"
            "_setMeleeCharge(false);"
        )
        input_guard = (
            "if(_meleeChargeStartedAt&&(_meleeActionLocked()||_isArmed()))"
            "_setMeleeCharge(false);"
        )
        self.assertIn(update_guard, WORLD)
        self.assertIn(input_guard, WORLD)
        send_start = WORLD.index("function sendInput(force = false)")
        send_end = WORLD.index("\n}", send_start)
        send_slice = WORLD[send_start:send_end]
        self.assertLess(
            send_slice.index(input_guard), send_slice.index("ws.send(JSON.stringify")
        )

    def test_firearm_and_server_melee_authority_are_out_of_scope(self):
        fire_start = WORLD.index("function fire(angle = null)")
        fire_end = WORLD.index("// ── Удар кулаком", fire_start)
        self.assertNotIn("_resetMeleeTransientState", WORLD[fire_start:fire_end])
        self.assertNotIn("_resetMeleeTransientState", BOT)
        self.assertIn("async def apply_player_melee(self, uid: str", BOT)
        self.assertIn("async def apply_player_shoot(self, uid: str", BOT)


if __name__ == "__main__":
    unittest.main()
