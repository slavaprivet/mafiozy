import pathlib
import unittest
from unittest.mock import patch

from mafiozi_bot import WorldSim


ROOT = pathlib.Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")


class PlayerAmbulanceClientTests(unittest.TestCase):
    def test_player_uses_stretcher_and_old_timer_is_suspended(self):
        body_crew = WORLD[WORLD.index("function _ambulanceNeedsBodyCrew"):WORLD.index("function _startAmbulanceBodyCrew")]
        self.assertNotIn("!patient._playerPatient", body_crew)
        self.assertIn("if(!_playerEmergencyPatient)myDeathLeft -= dt;", WORLD)
        self.assertIn("_setPlayerEmergencyTransport(true)", WORLD)
        self.assertIn("_completePlayerAmbulanceRecovery(patient,v,now,mode)", WORLD)
        self.assertIn("previewplayerambulance", WORLD)

    def test_rescue_overlay_has_no_fake_respawn_countdown(self):
        self.assertIn("deathCntLabel", WORLD)
        self.assertIn("Медицинская эвакуация", WORLD)
        self.assertIn("Тебя везут в больницу", WORLD)

    def test_carried_player_is_hidden_from_both_renderers(self):
        self.assertIn("medicalEvacuated:!!(_playerEmergencyPatient", WORLD)
        self.assertIn("!state.medicalEvacuated", THREE)


class PlayerAmbulanceServerTests(unittest.TestCase):
    def setUp(self):
        self.world = WorldSim.__new__(WorldSim)
        self.world.players = {
            "7": {
                "dead": True,
                "hp": 0,
                "max_hp": 120,
                "x": 80.0,
                "y": 80.0,
                "_respawn_at": 1018.0,
            }
        }

    def test_transport_holds_respawn_then_hospital_revive_clears_it(self):
        with patch("mafiozi_bot.time.time", return_value=1000.0):
            reply = self.world.emergency_transport("7", True)
        self.assertTrue(reply["ok"])
        self.assertEqual(self.world.players["7"]["_respawn_at"], 1180.0)

        with patch("mafiozi_bot.time.time", return_value=1020.0):
            self.world.tick_respawn(0.05)
        self.assertTrue(self.world.players["7"]["dead"])

        reply = self.world.emergency_revive("7", "hospital_east", 124.5, 44.5)
        player = self.world.players["7"]
        self.assertTrue(reply["ok"])
        self.assertFalse(player["dead"])
        self.assertEqual(player["hp"], 48)
        self.assertEqual((player["x"], player["y"]), (124.5, 44.5))
        self.assertNotIn("_respawn_at", player)
        self.assertNotIn("_emergency_transport_until", player)

    def test_cancelled_transport_restores_short_safe_fallback(self):
        with patch("mafiozi_bot.time.time", return_value=1000.0):
            self.world.emergency_transport("7", True)
            reply = self.world.emergency_transport("7", False)
        self.assertTrue(reply["ok"])
        self.assertEqual(self.world.players["7"]["_respawn_at"], 1005.0)


if __name__ == "__main__":
    unittest.main()
