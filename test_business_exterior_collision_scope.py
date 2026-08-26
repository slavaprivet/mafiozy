import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")


def function_body(marker: str) -> str:
    start = WORLD.index(marker)
    brace = WORLD.index("{", start)
    depth = 0
    quote = None
    escaped = False
    for pos in range(brace, len(WORLD)):
        char = WORLD[pos]
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
                return WORLD[start : pos + 1]
    raise AssertionError(f"unterminated function: {marker}")


class BusinessExteriorCollisionScopeTests(unittest.TestCase):
    def test_all_ten_authored_centres_are_blocked_but_door_corridors_stay_open(self):
        expected = {
            "coffee", "carwash", "barbershop", "pizza", "garage",
            "bar", "club", "warehouse", "casino", "port",
        }
        pois_block = re.search(r"const BUSINESS_POIS = \[(.+?)\n\];", WORLD, re.S)
        self.assertIsNotNone(pois_block)
        pois = re.findall(r"\{ id: '([a-z]+)'.+? r:\s*(\d+), c:\s*(\d+)", pois_block.group(1))
        pois = [(biz_id, int(row), int(col)) for biz_id, row, col in pois]
        self.assertEqual({biz_id for biz_id, _, _ in pois}, expected)
        geometry_block = re.search(
            r"const BUSINESS_EXTERIOR_GEOMETRY_3D = Object\.freeze\(\{(.+?)\n\}\);",
            WORLD,
            re.S,
        )
        self.assertIsNotNone(geometry_block)
        geometry = {
            biz_id: (float(width), float(depth))
            for biz_id, width, depth in re.findall(
                r"([a-z]+):\{w:([\d.]+),d:([\d.]+)", geometry_block.group(1)
            )
        }
        scale = 4.1
        blocked_centres = 0
        open_corridor_samples = 0
        for biz_id, row, col in pois:
            _, depth = geometry[biz_id]
            centre = (row + 0.5, col + 0.5)
            wall = (centre[0] + depth / (scale * 2), centre[1])
            corridor_start = (wall[0] - 0.45, wall[1])
            blocked_centres += abs(centre[0] - centre[0]) <= depth / (scale * 2)
            for step in range(6):
                t = step / 5
                probe = corridor_start[0] + (wall[0] - corridor_start[0]) * t
                inside = abs(probe - centre[0]) <= depth / (scale * 2) + 1e-9
                in_corridor = abs(probe - corridor_start[0]) <= 0.45 + 1e-9
                open_corridor_samples += bool(inside and in_corridor)
        self.assertEqual(blocked_centres, 10, "10/10 visual centres must become solid")
        self.assertEqual(open_corridor_samples, 60, "every authored door corridor must remain open")

    def test_collision_is_pedestrian_only_and_vehicle_passages_are_protected(self):
        ped = function_body("function isBlockedPed")
        car = function_body("function isBlockedCar")
        collision = function_body("function _businessExteriorPedBlocked")
        self.assertIn("_businessExteriorPedBlocked(r,c)", ped)
        self.assertNotIn("_businessExteriorPedBlocked", car)
        self.assertIn("_businessExteriorPedCollisionEnabled", collision)
        for biz_id in ("carwash", "garage", "warehouse"):
            self.assertRegex(WORLD, rf"\{{ id: '{biz_id}'.+?\}}")

    def test_cache_precedes_enable_and_preserves_existing_entrance_resolver(self):
        cache = function_body("function _cacheBusinessExteriorCollisions")
        self.assertLess(cache.index("_businessExteriorPedCollisionEnabled=false"), cache.index("_walkableEstablishmentAnchor(preferred)"))
        self.assertLess(cache.index("_walkableEstablishmentAnchor(preferred)"), cache.index("_businessExteriorPedCollisionEnabled=true"))
        self.assertIn("corridorStart:{r:wall.r-.45,c:wall.c}", cache)
        self.assertIn("corridorHalfWidth:.42", cache)
        self.assertIn("entranceCollisionMismatches", THREE)
        self.assertIn("entranceCollisionSamples", THREE)

    def test_entry_exit_clients_and_preview_share_the_cached_anchor(self):
        entry = function_body("function _currentBuildingEntryTarget")
        clients = function_body("function _updateBizClients")
        exit_body = function_body("function exitBuildingInterior")
        ws_url = function_body("function wsUrl")
        self.assertIn("_businessInteractionAnchor(biz)", entry)
        self.assertGreaterEqual(clients.count("_businessInteractionAnchor(biz)"), 2)
        self.assertIn("bi.type==='business'&&bi.bizId", exit_body)
        self.assertIn("_businessInteractionAnchor(biz)", exit_body)
        self.assertIn("else{\n    player.r = bi.r + 1.5; player.c = bi.c + 0.5;", exit_body)
        self.assertIn("_businessInteractionAnchor(previewBiz)", ws_url)
        self.assertIn("const entrance=_businessInteractionAnchor(previewPoi)", WORLD)

    def test_renderer_distance_and_territory_contracts_are_not_changed(self):
        distance = function_body("function _businessInteractionDistance")
        self.assertIn("return Math.min(", distance)
        self.assertIn("footprintDistance", distance)
        self.assertNotIn("_businessExteriorPedBlocked", distance)
        self.assertIn("three_preview.js?", WORLD)


if __name__ == "__main__":
    unittest.main()
