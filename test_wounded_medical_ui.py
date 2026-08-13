import pathlib
import unittest


WORLD = pathlib.Path(__file__).with_name("world.html").read_text(encoding="utf-8")


class WoundedMedicalUiTests(unittest.TestCase):
    def test_overlay_uses_game_styled_medical_card(self):
        self.assertIn('class="death-card"', WORLD)
        self.assertIn('id="deathEyebrow"', WORLD)
        self.assertIn('class="death-route"', WORLD)
        self.assertIn('ГОРОДСКАЯ МЕДИЦИНСКАЯ СЛУЖБА', WORLD)

    def test_ambulance_phases_drive_card_progress(self):
        self.assertIn("_deathOv.dataset.mode=policeDecision?'police':(rescueComing?'rescue':'dead')", WORLD)
        self.assertIn("_deathOv.dataset.stage=rescueStage", WORLD)
        self.assertIn("?'transit':(_playerEmergencyPatient._carriedByAmbulance?'loading':'dispatch')", WORLD)
        self.assertIn('#deathOverlay[data-stage="loading"]', WORLD)
        self.assertIn('#deathOverlay[data-stage="transit"]', WORLD)

    def test_overlay_is_responsive_and_respects_reduced_motion(self):
        self.assertIn('@media (max-width:560px)', WORLD)
        self.assertIn('@media (prefers-reduced-motion:reduce)', WORLD)


if __name__ == "__main__":
    unittest.main()
