import ast
import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parent
BOT_SOURCE = (ROOT / "mafiozi_bot.py").read_text(encoding="utf-8")
WORLD_SOURCE = (ROOT / "world.html").read_text(encoding="utf-8")


class ArmorAuthoritySourceContractTests(unittest.TestCase):
    def test_all_validated_world_damage_producers_are_async_and_centralized(self):
        tree = ast.parse(BOT_SOURCE)
        methods = {
            node.name: node
            for node in ast.walk(tree)
            if isinstance(node, ast.AsyncFunctionDef)
        }
        expected = {
            "_tick_event_async", "_apply_player_shoot_once", "_tick_cops_async",
            "_tick_pending_bot_shots_async", "_tick_aggro_async",
            "_tick_michael_guards_async", "_tick_world_c4_async",
        }
        self.assertTrue(expected <= methods.keys())
        for name in expected:
            segment = ast.get_source_segment(BOT_SOURCE, methods[name]) or ""
            self.assertIn("apply_authoritative_damage", segment, name)
        wrapper = ast.get_source_segment(BOT_SOURCE, methods["apply_player_shoot"]) or ""
        self.assertIn("_player_shot_lock", wrapper)
        self.assertIn("await self._apply_player_shoot_once", wrapper)

    def test_client_named_gang_damage_cannot_write_body(self):
        marker = "elif t == 'gang_dmg':"
        start = BOT_SOURCE.index(marker)
        end = BOT_SOURCE.index("elif ", start + len(marker))
        block = BOT_SOURCE[start:end]
        self.assertNotIn("['hp'] =", block)
        self.assertNotIn("apply_authoritative_damage", block)

    def test_shop_inventory_and_world_socket_have_actor_binding(self):
        self.assertIn("path.startswith('/shop/') or path.startswith('/inv/')", BOT_SOURCE)
        self.assertIn("actor_owns_character", BOT_SOURCE)
        self.assertIn("aio_app.router.add_post('/auth/world/{uid}'", BOT_SOURCE)
        self.assertIn("verify_world_token(req.query.get('world_token', ''), expected_uid=uid)", BOT_SOURCE)

    def test_frozen_combat_state_is_exposed_without_second_armor_state(self):
        self.assertIn("'combat_state':    combat_state", BOT_SOURCE)
        self.assertIn("'combat_state': p.get('_combat_state')", BOT_SOURCE)
        self.assertNotIn("'armor_state'", BOT_SOURCE)

    def test_live_client_has_no_durability_or_break_authority(self):
        self.assertNotIn("break-armor", WORLD_SOURCE)
        self.assertNotIn("localStorage.setItem(ARMOR", WORLD_SOURCE)
        self.assertIn("if(!_LOCAL_PREVIEW)return", WORLD_SOURCE)
        self.assertIn("d.me.combat_state", WORLD_SOURCE)
        self.assertIn("o.combat_state", WORLD_SOURCE)

    def test_every_player_shoot_payload_has_idempotency_key(self):
        for chunk in WORLD_SOURCE.split("t:'player_shoot'")[1:]:
            self.assertIn("shot_id", chunk[:240])
        for chunk in WORLD_SOURCE.split("t: 'player_shoot'")[1:]:
            self.assertIn("shot_id", chunk[:260])

    def test_pvp_replay_reads_durable_receipt_not_missing_body_damage(self):
        start = BOT_SOURCE.index("async def apply_player_shoot")
        end = BOT_SOURCE.index("def _in_pvp_zone", start)
        block = BOT_SOURCE[start:end]
        self.assertIn("get_weapon_shot_receipt", block)
        self.assertIn("saved['damage'].get('raw_damage')", block)
        self.assertNotIn("get('body_damage')", block)


if __name__ == "__main__":
    unittest.main()
