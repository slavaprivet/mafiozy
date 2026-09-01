from pathlib import Path
from urllib.parse import parse_qs, urlsplit
import re
import unittest


ROOT = Path(__file__).resolve().parent
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")


def function_slice(start_marker: str, end_marker: str) -> str:
    start = THREE.index(start_marker)
    end = THREE.index(end_marker, start)
    return THREE[start:end]


class Artist12BuildingDownpipeContract(unittest.TestCase):
    def test_downpipe_is_two_piece_deterministic_door_clear_detail(self):
        block = function_slice(
            "const addArchitecturalFacadeDepth=",
            "const addSecondBuildingSliceDepth=",
        )
        self.assertIn(
            "const downpipeSide=(familyId==='glass'||familyId==='limestone'||familyId==='deco')?1:-1",
            block,
        )
        self.assertIn("downpipeX=x+downpipeSide*w*.38", block)
        self.assertIn("downpipeH=Math.max(3.6,Math.min(h-1.1,8.8))", block)
        self.assertEqual(block.count("add(downpipeX,"), 1)
        self.assertEqual(block.count("add(downpipeX-downpipeSide*.2,"), 1)
        self.assertIn(".13,downpipeH,identityDark,front+depth+.08", block)
        self.assertIn(".48,.12,identityDark,front+depth+.12", block)
        self.assertNotIn("new THREE.", block)
        self.assertNotIn("requestAnimationFrame", block)
        self.assertNotIn("collision", block.lower())

    def test_profile_and_existing_static_merge_are_preserved(self):
        self.assertIn(
            "buildingDownpipeProfile='ordinary-edge-vertical-outlet-door-clear-static-merged-v1'",
            THREE,
        )
        self.assertIn(
            "if(!architecturalKind){addDistrictCharacter(x,z,w,d,h,districtStyle,buildingSeed);"
            "addProceduralBuildingIdentity(x,z,w,d,h,buildingSeed,districtStyle,architectureFamily.id);}",
            THREE,
        )
        self.assertIn(
            "for(const child of scene.children.slice(detailSceneStart))queueStaticBuildingDetail(child);",
            THREE,
        )
        self.assertIn("mesh.parent?.remove(mesh);mesh.geometry.dispose();", THREE)
        self.assertIn("geometries.forEach(geometry=>geometry.dispose());", THREE)
        self.assertIn(
            "buildingFacadeDepthProfiles='six-family-restraint-single-cornice-door-clear-static-merged-v2'",
            THREE,
        )

    def test_module_query_adds_only_semantic_downpipe_marker(self):
        sources = re.findall(
            r'<script\s+type="module"\s+src="([^"]*three_preview\.js[^"]*)"',
            WORLD,
        )
        self.assertEqual(len(sources), 1)
        query = parse_qs(urlsplit(sources[0]).query, keep_blank_values=True)
        self.assertEqual(query.get("downpipe"), ["ordinary-edge-drain-v1"])
        required = {
            "opt": "building-reveal-v428",
            "storeglow": "signed-circadian-v1",
            "windows": "room-pair-floor-circadian-v1",
            "roofmat": "family-physical-response-v1",
        }
        for key, expected_fragment in required.items():
            self.assertIn(key, query)
            self.assertIn(expected_fragment, query[key][0])

    def test_no_renderer_resource_or_gameplay_path_is_added(self):
        block = function_slice(
            "const addArchitecturalFacadeDepth=",
            "const addSecondBuildingSliceDepth=",
        )
        forbidden = (
            "new THREE.MeshStandardMaterial",
            "new THREE.MeshPhysicalMaterial",
            "new THREE.Texture",
            "new THREE.PointLight",
            "setInterval",
            "setTimeout",
            "addEventListener",
            "userData.building",
            "deferredRevealRoots",
        )
        for token in forbidden:
            self.assertNotIn(token, block)


if __name__ == "__main__":
    unittest.main()
