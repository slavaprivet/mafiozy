import pathlib
import re
import unittest


ROOT = pathlib.Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")
BOT = (ROOT / "mafiozi_bot.py").read_text(encoding="utf-8")
PREVIEW = (ROOT / "_preview_ws_server.py").read_text(encoding="utf-8")


class BankBagStateContractTests(unittest.TestCase):
    def test_interior_drop_uses_exact_player_position(self):
        block = WORLD.split("if (_bankInt && _bankInt.myBag) {", 1)[1].split("if (typeof updateZoneBtn", 1)[0]
        self.assertNotIn("player.r +", block)
        self.assertNotIn("player.c +", block)
        self.assertIn("const dropR = player.r;", block)
        self.assertIn("const dropC = player.c;", block)

    def test_client_preserves_one_stable_id_and_waits_for_server(self):
        self.assertIn("function _stableBankBagId", WORLD)
        self.assertNotIn("const worldBagId='bag_'+String(QP.uid||'p')+'_'+Date.now()", WORLD)
        pickup = re.search(r"function pickupDroppedBag\(bagId\) \{(.+?)\n\}", WORLD, re.S).group(1)
        self.assertIn("t:'bank_bag_pickup'", pickup)
        self.assertNotIn("_vaultDroppedBags.splice(idx, 1)", pickup)
        self.assertIn("_acceptAuthoritativeBankBagPickup", WORLD)
        self.assertIn("_acceptAuthoritativeBankBagDrop", WORLD)

    def test_vehicle_roundtrip_preserves_distinct_bag_ids(self):
        load = WORLD.split("function loadBagIntoVan(preferredCar) {", 1)[1].split(
            "function unloadBagFromCar", 1)[0]
        unload = WORLD.split("function unloadBagFromCar", 1)[1].split(
            "function deliverBagsToBusinesses", 1)[0]
        self.assertIn("loadedBag.id = _stableBankBagId", load)
        self.assertIn("_bankBagIds", load)
        self.assertIn("_bankVanBagIds", load)
        self.assertIn("let recoveredId = bagIds.pop()", unload)
        self.assertIn("id: recoveredId", unload)

    def test_reconnect_replays_or_reconciles_pending_drop(self):
        connect = WORLD.split("async function wsConnect() {", 1)[1].split(
            "function wsSend", 1)[0]
        self.assertIn("if (_bankBagDropPending)", connect)
        self.assertIn("bag_id:pending.id", connect)
        self.assertIn("const canonical = d.dropped_bags.find", connect)
        self.assertIn("_acceptAuthoritativeBankBagDrop({", connect)

    def test_server_pickup_is_atomic_and_owner_bound(self):
        handler = BOT.split("elif t == 'bank_bag_pickup':", 1)[1].split("elif t == 'bank_rob_apartment_deliver':", 1)[0]
        self.assertIn("world.bank_bags.pop(bag_id, None)", handler)
        self.assertIn("not_owner", handler)
        self.assertIn("no_active_robbery", handler)
        self.assertIn("too_far", handler)
        self.assertIn("'bag_id': bag_id", handler)

    def test_drop_is_idempotent_position_checked_and_acknowledged(self):
        handler = BOT.split("elif t == 'bank_bag_drop':", 1)[1].split("elif t == 'ping':", 1)[0]
        self.assertIn("replay_ok", handler)
        self.assertIn("4.0 ** 2", handler)
        self.assertIn("if state and carried_ok", handler)
        self.assertIn("state['carried'] = 0", handler)
        self.assertIn("'kind': 'bank_bag_drop_reply'", handler)
        self.assertNotIn("requested_id in world.bank_bags", handler)

    def test_disconnect_materializes_same_carried_id(self):
        remove = BOT.split("def remove(self, uid: str) -> None:", 1)[1].split("def _clear_police_downed", 1)[0]
        self.assertIn("for bank_id, loot in list((p.get('_bank_rob') or {}).items())", remove)
        self.assertIn("bag_id not in self.bank_bags", remove)
        self.assertIn("loot['carried'] = 0", remove)

    def test_preview_matches_authoritative_contract(self):
        self.assertIn('elif t == "bank_bag_pickup":', PREVIEW)
        self.assertIn('p = players.setdefault(uid, {})', PREVIEW)
        self.assertIn('"kind":"bank_bag_pickup_reply"', PREVIEW)
        self.assertIn('"kind":"bank_bag_drop_reply"', PREVIEW)
        self.assertIn('"x":drop_x, "y":drop_y', PREVIEW)
        self.assertIn('if bag_id not in preview_bank_bags:', PREVIEW)


if __name__ == "__main__":
    unittest.main()
