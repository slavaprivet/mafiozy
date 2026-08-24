from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parent
SOURCE = (ROOT / "three_preview.js").read_text(encoding="utf-8")


def _compact(value: str) -> str:
    return re.sub(r"\s+", "", value)


class ZoomTextureQualityTests(unittest.TestCase):
    def test_architecture_uses_trilinear_mips_and_anisotropy_at_overview_zoom(self):
        facade = SOURCE[SOURCE.index("const facadeTexture") : SOURCE.index("const groundMaterial")]
        self.assertIn("tx.generateMipmaps = true", facade)
        self.assertIn("tx.minFilter = THREE.LinearMipmapLinearFilter", facade)
        self.assertIn("tx.magFilter = THREE.LinearFilter", facade)
        self.assertIn("Math.min(16,renderer.capabilities.getMaxAnisotropy())", _compact(facade))
        self.assertIn("architectureTextureMinification='trilinear-mips-anisotropic-v424'", SOURCE)

    def test_static_architectural_signs_share_the_quality_contract(self):
        compact = _compact(SOURCE)
        for marker in (
            "constlabelSprite=",
            "constapartmentLabelSprite=",
            "constpanel=(text,px,py,pz",
            "constmakeSignTexture=",
            "constsignCv=",
        ):
            start = compact.index(marker)
            window = compact[start : start + 4200]
            self.assertIn("generateMipmaps=true", window, marker)
            self.assertIn("minFilter=THREE.LinearMipmapLinearFilter", window, marker)
            self.assertIn("magFilter=THREE.LinearFilter", window, marker)

    def test_zoom_quality_does_not_raise_global_render_cost_or_reduce_world_detail(self):
        self.assertIn("const baseRenderPixelRatio=Math.min(mobileRenderProfile?1:1.25", SOURCE)
        self.assertIn("renderer.domElement.dataset.renderResolutionPolicy='quality-locked-native-v234'", SOURCE)
        self.assertIn("worldZoom=THREE.MathUtils.clamp(worldZoom+direction*step,.82,1.3)", SOURCE)
        self.assertIn("NPC_CAP", SOURCE)
        self.assertIn("renderer.shadowMap.type = THREE.PCFSoftShadowMap", SOURCE)


if __name__ == "__main__":
    unittest.main()
