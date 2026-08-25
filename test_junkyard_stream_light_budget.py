from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parent
SOURCE = (ROOT / "three_preview.js").read_text(encoding="utf-8")
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")


class JunkyardStreamLightBudgetTests(unittest.TestCase):
    def test_proximity_build_registers_lights_before_the_next_render(self):
        start = SOURCE.index("if(!junkyardVisualBuilt&&t>=junkyardProbeAt")
        end = SOURCE.index("scheduleSectorLoad(+state.r||0,+state.c||0);", start)
        block = SOURCE[start:end]
        self.assertIn("ensureJunkyardVisual", block)
        self.assertIn("registerOutdoorPointLights(scene);", block)
        self.assertIn("updateOutdoorPointLightBudget(t,true);", block)
        self.assertLess(
            block.index("registerOutdoorPointLights(scene);"),
            block.index("updateOutdoorPointLightBudget(t,true);"),
        )
        self.assertIn(
            "junkyardLightBudget='registered-before-first-frame-v425'", block
        )

    def test_world_busts_the_renderer_module_cache_for_the_fix(self):
        self.assertIn("junkyard-light-budget-v425", WORLD)


if __name__ == "__main__":
    unittest.main()
