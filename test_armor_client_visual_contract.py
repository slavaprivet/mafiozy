import pathlib
import subprocess
import unittest


ROOT = pathlib.Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")


class ArmorClientVisualContractTests(unittest.TestCase):
    def test_self_visual_reads_only_canonical_combat_state(self):
        self.assertIn("const playerArmor=state.combat_state?.armor||{}", THREE)
        self.assertIn("playerArmor.current", THREE)
        self.assertIn("playerArmor.max", THREE)
        self.assertIn("playerArmor.version", THREE)
        self.assertIn("configureArmorVisual(state.role==='prisoner'?null:playerArmorId", THREE)
        self.assertNotIn("state.armorDurability", THREE)
        self.assertNotIn("state.armorMax", THREE)

    def test_remote_visual_receives_and_renders_canonical_armor(self):
        self.assertIn("combat_state:x.combatState||null", WORLD)
        self.assertIn("remoteArmor=src.combat_state?.armor||{}", THREE)
        self.assertIn("remoteParts.armor", THREE)
        self.assertIn("remoteArmor.version", THREE)

    def test_live_car_explosion_does_not_mutate_body(self):
        self.assertNotIn("myHp = Math.max(1, myHp - 15)", WORLD)
        self.assertIn("if(_LOCAL_PREVIEW)myHp=Math.max(1,myHp-15)", WORLD)

    def test_inventory_describes_armor_first_hp_not_percentage(self):
        self.assertIn("Броня первой поглощает урон", WORLD)
        self.assertIn("armor HP · combat_state.v1", WORLD)
        self.assertNotIn("style.reduction", WORLD)

    def test_passenger_and_visual_a_markers_survive(self):
        self.assertIn("myIsPassenger  = true", WORLD)
        self.assertIn("if (myIsPassenger)", WORLD)
        self.assertIn("3D character v354", THREE)
        self.assertIn("renderer.domElement.dataset.playerBodyProfile", THREE)
        self.assertIn("dynamicCadence", THREE)
        self.assertIn("dataset.visibleGangs", THREE)
        self.assertIn("dataset.gangMatrixUploads", THREE)

    def test_visual_b_contract_after_upstream_integration(self):
        cache_marker = "material=physical-glass-soft-shadow-v1"
        if cache_marker not in WORLD:
            self.skipTest("awaiting known e398df0 Visual B integration")
        self.assertIn("buildingMaterialBudget", THREE)
        self.assertIn("dataset.shadowUpdates", THREE)
        self.assertIn("dataset.memoryGeometries", THREE)
        self.assertIn("dataset.memoryTextures", THREE)

    def test_javascript_syntax(self):
        probe = (
            "const fs=require('fs');"
            "new Function(fs.readFileSync('three_preview.js','utf8'));"
            "const s=fs.readFileSync('world.html','utf8');"
            "for(const m of s.matchAll(/<script(?:\\s[^>]*)?>([\\s\\S]*?)<\\/script>/gi))"
            "new Function(m[1].replace(/^\\s*import\\s[^;]+;?/gm,''));"
        )
        subprocess.run(["node", "-e", probe], cwd=ROOT, check=True)


if __name__ == "__main__":
    unittest.main()
