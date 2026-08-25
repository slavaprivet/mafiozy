import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")


class BridgeHangerInstancingContract(unittest.TestCase):
    def test_exact_static_batch_replaces_per_hanger_meshes(self):
        self.assertIn("bridgeHangerCount=towerEdgeZ.length*19", THREE)
        self.assertIn("new THREE.CylinderGeometry(.045,.045,1,6)", THREE)
        self.assertIn("new THREE.InstancedMesh(bridgeHangerGeometry,bridgeHangerMat,bridgeHangerCount)", THREE)
        self.assertIn("bridgeHangers.setMatrixAt(bridgeHangerIndex++,bridgeHangerMatrix)", THREE)
        self.assertIn("bridgeHangers.computeBoundingBox();bridgeHangers.computeBoundingSphere()", THREE)
        self.assertIn("static-instanced-exact-v426", THREE)
        legacy = re.compile(
            r"new THREE\.CylinderGeometry\(\.045,\.045,height,6\).*?bridgeHangerMat"
        )
        self.assertIsNone(legacy.search(THREE))

    def test_world_requests_the_new_renderer_revision(self):
        self.assertIn("junkyard-light-budget-v425+bridge-hangers-v426", WORLD)


if __name__ == "__main__":
    unittest.main()
