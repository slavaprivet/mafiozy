"""Durable melee receipt replay must be offline-safe and requester-only."""

import asyncio
import json
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

import mafiozi_bot as game


ROOT = Path(__file__).resolve().parent
BOT = (ROOT / "mafiozi_bot.py").read_text(encoding="utf-8")
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")


def _receipt(target_uid="202", combat_state=None):
    state = combat_state or {
        "body": {"current": 76, "max": 100, "dead": False},
        "armor": {"id": None, "current": 0, "max": 0, "broken": False},
        "combat_version": 4,
    }
    return {
        "ok": True,
        "kind": "pvp_melee",
        "attack_id": "receipt-1",
        "shooter_uid": "101",
        "target_uid": target_uid,
        "dmg": 12,
        "combat_state": state,
        "replayed": True,
    }


class _FakeWs:
    def __init__(self):
        self.sent = []

    async def send_str(self, value):
        self.sent.append(value)


class MeleeReceiptReplayContractTests(unittest.TestCase):
    def _world(self):
        world = game.WorldSim()
        world.add_or_update("101", "Shooter", {})
        world.add_or_update("202", "Target", {})
        shooter = world.players["101"]
        shooter["_melee_charge_t"] = 123.5
        shooter["_melee_attack_t"] = 456.5
        return world

    def test_matching_receipt_survives_target_disconnect_without_side_effects(self):
        async def scenario():
            world = self._world()
            world.players.pop("202")
            shooter = world.players["101"]
            prior = _receipt()
            charge_before = shooter["_melee_charge_t"]
            cadence_before = shooter["_melee_attack_t"]
            with patch.object(game, "get_melee_event_receipt",
                              AsyncMock(return_value=prior)) as receipt, \
                    patch.object(game, "get_authoritative_combat_state",
                                 AsyncMock()) as state, \
                    patch.object(game.WorldSim, "apply_authoritative_damage",
                                 AsyncMock()) as damage, \
                    patch.object(game, "store_melee_event_receipt",
                                 AsyncMock()) as store:
                result = await world.apply_player_melee(
                    "101", "202", "receipt-1")
            self.assertTrue(result["replayed"])
            self.assertEqual(result["combat_state"], prior["combat_state"])
            receipt.assert_awaited_once_with(101, "receipt-1")
            state.assert_not_awaited()
            damage.assert_not_awaited()
            store.assert_not_awaited()
            self.assertEqual(shooter["_melee_charge_t"], charge_before)
            self.assertEqual(shooter["_melee_attack_t"], cadence_before)

        asyncio.run(scenario())

    def test_live_replay_refreshes_state_but_never_reapplies_damage(self):
        async def scenario():
            world = self._world()
            current = {
                "body": {"current": 64, "max": 100, "dead": False},
                "armor": {"id": "vest", "current": 8, "max": 20,
                          "broken": False},
                "combat_version": 5,
            }
            with patch.object(game, "get_melee_event_receipt",
                              AsyncMock(return_value=_receipt())), \
                    patch.object(game, "get_authoritative_combat_state",
                                 AsyncMock(return_value=current)) as state, \
                    patch.object(game.WorldSim, "_mirror_combat_state",
                                 return_value=True) as mirror, \
                    patch.object(game.WorldSim, "apply_authoritative_damage",
                                 AsyncMock()) as damage:
                result = await world.apply_player_melee(
                    "101", "202", "receipt-1")
            self.assertEqual(result["combat_state"], current)
            state.assert_awaited_once_with(202)
            mirror.assert_called_once_with(world.players["202"], current)
            damage.assert_not_awaited()

        asyncio.run(scenario())

    def test_conflict_precedes_target_presence_and_new_missing_target_rejects(self):
        async def scenario():
            world = self._world()
            world.players.pop("202")
            world.players.pop("101", None)
            # A connected attacker remains mandatory even for a replay.
            with patch.object(game, "get_melee_event_receipt",
                              AsyncMock()) as receipt:
                self.assertIsNone(await world.apply_player_melee(
                    "101", "202", "receipt-1"))
            receipt.assert_not_awaited()

            world.add_or_update("101", "Shooter", {})
            with patch.object(game, "get_melee_event_receipt",
                              AsyncMock(return_value=_receipt())):
                conflict = await world.apply_player_melee(
                    "101", "303", "receipt-1")
            self.assertEqual(conflict["error"], "attack_conflict")

            with patch.object(game, "get_melee_event_receipt",
                              AsyncMock(return_value=None)), \
                    patch.object(game.WorldSim, "apply_authoritative_damage",
                                 AsyncMock()) as damage:
                missing = await world.apply_player_melee(
                    "101", "303", "new-missing")
            self.assertIsNone(missing)
            damage.assert_not_awaited()

        asyncio.run(scenario())

    def test_runtime_delivery_is_requester_only_for_replay_and_broadcast_for_fresh(self):
        async def scenario():
            requester, target, observer = _FakeWs(), _FakeWs(), _FakeWs()
            world = SimpleNamespace(connections={
                "101": requester, "202": target, "303": observer,
            })
            replay = _receipt()
            await game._deliver_world_melee_packet(world, requester, replay)
            self.assertEqual(len(requester.sent), 1)
            self.assertEqual(target.sent, [])
            self.assertEqual(observer.sent, [])
            self.assertTrue(json.loads(requester.sent[0])["d"]["replayed"])

            requester.sent.clear()
            fresh = {**replay, "attack_id": "fresh-1", "replayed": False}
            await game._deliver_world_melee_packet(world, requester, fresh)
            self.assertEqual([len(ws.sent) for ws in
                              (requester, target, observer)], [1, 1, 1])

        asyncio.run(scenario())

    def test_marker_and_firearm_scope_exclusion(self):
        marker = (
            '<meta name="mafiozy-melee-receipt-replay-contract" '
            'content="requester-only-v1">'
        )
        self.assertEqual(WORLD.count(marker), 1)
        firearm_start = BOT.index("    async def apply_player_shoot(")
        firearm_end = BOT.index("    def _bump_wanted(", firearm_start)
        firearm_slice = BOT[firearm_start:firearm_end]
        self.assertNotIn("_deliver_world_melee_packet", firearm_slice)
        self.assertNotIn("get_melee_event_receipt", firearm_slice)


if __name__ == "__main__":
    unittest.main()
