import pathlib
import unittest


ROOT = pathlib.Path(__file__).parent
BOT = (ROOT / "mafiozi_bot.py").read_text(encoding="utf-8")
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")


class OwnedPropertyRespawnTests(unittest.TestCase):
    def test_client_only_renders_owned_businesses_and_server_holdings(self):
        self.assertIn("for (const id of myOwnedBiz)", WORLD)
        self.assertIn("for (const h of myRespawnHoldings)", WORLD)
        self.assertNotIn("it.owned ? '' : '🔒 КУПИ'", WORLD)

    def test_building_id_is_not_truncated_by_websocket_handler(self):
        self.assertIn("building:<apt_key>", BOT)
        self.assertIn("or 'hospital')[:64]", BOT)

    def test_server_rechecks_ownership_and_finds_passable_spawn(self):
        self.assertIn("def _respawn_point_owned", BOT)
        self.assertIn("apt_key in (\n                player.get('_owned_apartments')", BOT)
        self.assertIn("def _safe_respawn_near", BOT)
        self.assertIn("_world_bot_passable(x, y, radius=0.38)", BOT)
        self.assertNotIn("p['x'] = bx + random.uniform(-0.6, 0.6)", BOT)

    def test_status_refreshes_building_ownership_from_database(self):
        self.assertIn("owned_buildings = await get_apartments_owned(int(uid))", BOT)
        self.assertIn("'holdings': holdings", BOT)


if __name__ == "__main__":
    unittest.main()
