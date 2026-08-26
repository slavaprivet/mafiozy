import asyncio
import json
import math
import os
import subprocess
import unittest
from pathlib import Path
from unittest.mock import AsyncMock, Mock, patch

os.environ.setdefault("BOT_TOKEN", "123456:melee-business-los")

import mafiozi_bot as game


ROOT = Path(__file__).resolve().parent
WORLD_PATH = ROOT / "world.html"
BOT_PATH = ROOT / "mafiozi_bot.py"


def _world_contract():
    source = WORLD_PATH.read_text(encoding="utf-8")
    script = r"""
const fs=require('fs');
const s=fs.readFileSync(process.argv[1],'utf8');
const a=s.slice(s.indexOf('const BUSINESS_INTERIORS ='),s.indexOf('// Authoritative owner wardrobe'));
const b=s.slice(s.indexOf('const BUSINESS_INTERIOR_COLLISION_LAYOUT_VERSION'),s.indexOf('function _businessInteriorCollisionLayoutLegacyV2For'));
const c=s.slice(s.indexOf('const BUSINESS_INTERIOR_COLLISION_V2_ORIGIN_SIGNATURES'),s.indexOf('function _businessInteriorCollisionV2Fingerprint'));
eval(a+'\n'+b+'\n'+c+'\n;globalThis.__contract={build:_buildBusinessInteriorCollisionLayoutLegacyV2,sigs:BUSINESS_INTERIOR_COLLISION_V2_ORIGIN_SIGNATURES};');
const ids=['coffee','carwash','barbershop','pizza','garage','bar','club','warehouse','casino','port'];
const out={};
for(const id of ids){
  const [size,signature]=__contract.sigs[id], [w,h]=size.split('x').map(Number);
  const layout=__contract.build(id,w,h);
  out[id]={size:[w,h],signature,blockers:layout.items.filter(q=>q.solid!==false).map(q=>[q.r,q.c,q.w,q.d])};
}
console.log(JSON.stringify(out));
"""
    completed = subprocess.run(
        ["node", "-e", script, str(WORLD_PATH)], cwd=ROOT,
        text=True, capture_output=True, check=True)
    assert source
    return json.loads(completed.stdout)


def _business_world(biz_id="coffee", shooter_xy=(12.0, 8.0),
                    target_xy=(12.8, 8.0), versions=(2, 2), now=2_004_100_000.0):
    world = game.WorldSim()
    world.add_or_update("101", "Attacker", {})
    world.add_or_update("202", "Target", {})
    attacker = world.players["101"]
    target = world.players["202"]
    for player in (attacker, target):
        player.update(
            x=40.0, y=40.0, dead=False, hp=100, max_hp=100,
            _mode="pvp", _weapon="fists", _stance="stand",
            _business_interior=biz_id, _in_interior=True,
            _interior_kind="business")
    attacker.update(
        _business_private=True,
        _business_collision_v=versions[0],
        _interior_x=shooter_xy[0], _interior_y=shooter_xy[1],
        _melee_charge_t=now - 1.2)
    target.update(
        _business_private=False,
        _business_collision_v=versions[1],
        _interior_x=target_xy[0], _interior_y=target_xy[1])
    world._business_aggro_until[("202", biz_id)] = now + 100
    return world


class BusinessInteriorMeleeLosTests(unittest.TestCase):
    def test_server_registry_matches_frozen_world_v2(self):
        contract = _world_contract()
        self.assertEqual(game.BUSINESS_INTERIOR_COLLISION_VERSION, 2)
        self.assertEqual(set(contract), set(game.BUSINESS_INTERIOR_COLLISION_V2))
        for biz_id, expected in contract.items():
            actual = game.BUSINESS_INTERIOR_COLLISION_V2[biz_id]
            self.assertEqual(tuple(expected["size"]), actual["size"], biz_id)
            self.assertEqual(expected["signature"], actual["signature"], biz_id)
            self.assertEqual(
                [tuple(row) for row in expected["blockers"]],
                list(actual["blockers"]), biz_id)

        world_source = WORLD_PATH.read_text(encoding="utf-8")
        self.assertIn(
            "collision_v: _buildingInt.type === 'business'", world_source)
        self.assertIn(
            "? BUSINESS_INTERIOR_COLLISION_LAYOUT_VERSION : undefined",
            world_source)

    def test_clear_same_business_melee_still_applies_damage(self):
        async def scenario():
            now = 2_004_100_000.0
            world = _business_world(now=now)
            damage = {"body": {"dead": False}, "effective_damage": 12,
                      "replayed": False}
            with patch.object(game, "get_melee_event_receipt", AsyncMock(return_value=None)), \
                    patch.object(game, "store_melee_event_receipt", AsyncMock()) as store, \
                    patch.object(game.WorldSim, "apply_authoritative_damage", AsyncMock(return_value=damage)) as apply, \
                    patch.object(game.random, "random", return_value=1.0), \
                    patch.object(game.time, "time", return_value=now):
                hit = await world.apply_player_melee(
                    "101", "202", "business-clear")
            self.assertIsNotNone(hit)
            self.assertEqual(hit["dmg"], 12)
            apply.assert_awaited_once()
            store.assert_awaited_once()

        asyncio.run(scenario())

    def test_frozen_blocker_rejects_heavy_without_receipt_or_damage(self):
        async def scenario():
            now = 2_004_100_010.0
            # Both endpoints straddle the coffee cashier and remain within
            # heavy contact range; the sampled segment crosses frozen V2.
            world = _business_world(
                shooter_xy=(8.0, 2.2), target_xy=(8.0, 3.6), now=now)
            with patch.object(game, "get_melee_event_receipt", AsyncMock(return_value=None)), \
                    patch.object(game, "store_melee_event_receipt", AsyncMock()) as store, \
                    patch.object(game.WorldSim, "apply_authoritative_damage", AsyncMock()) as apply, \
                    patch.object(game.time, "time", return_value=now):
                hit = await world.apply_player_melee(
                    "101", "202", "business-blocked", heavy=True)
            self.assertIsNone(hit)
            apply.assert_not_awaited()
            store.assert_not_awaited()

        asyncio.run(scenario())

    def test_unknown_versions_nonfinite_and_bounds_fail_closed(self):
        async def scenario():
            cases = (
                ("unknown", "not_a_business", (5.0, 5.0), (5.5, 5.0), (2, 2)),
                ("missing-shooter-version", "coffee", (12.0, 8.0), (12.8, 8.0), (None, 2)),
                ("missing-target-version", "coffee", (12.0, 8.0), (12.8, 8.0), (2, None)),
                ("shooter-version", "coffee", (12.0, 8.0), (12.8, 8.0), (0, 2)),
                ("target-version", "coffee", (12.0, 8.0), (12.8, 8.0), (2, 0)),
                ("missing-shooter-x", "coffee", (12.0, 8.0), (12.8, 8.0), (2, 2)),
                ("missing-target-y", "coffee", (12.0, 8.0), (12.8, 8.0), (2, 2)),
                ("shooter-nan", "coffee", (math.nan, 5.0), (5.5, 5.0), (2, 2)),
                ("target-nan", "coffee", (5.0, 5.0), (5.5, math.nan), (2, 2)),
                ("shooter-infinity", "coffee", (math.inf, 5.0), (5.5, 5.0), (2, 2)),
                ("target-infinity", "coffee", (5.0, 5.0), (-math.inf, 5.0), (2, 2)),
                ("negative-bound", "coffee", (-0.1, 5.0), (0.8, 5.0), (2, 2)),
                ("room-bound", "coffee", (60.0, 60.0), (60.5, 60.0), (2, 2)),
                ("blocked-endpoint", "coffee", (8.0, 2.9), (8.0, 3.7), (2, 2)),
            )
            now = 2_004_100_020.0
            for index, (label, biz_id, attacker_xy, target_xy, versions) in enumerate(cases):
                with self.subTest(label=label):
                    world = _business_world(
                        biz_id, attacker_xy, target_xy, versions, now)
                    attacker = world.players["101"]
                    target = world.players["202"]
                    if label == "missing-shooter-version":
                        attacker.pop("_business_collision_v", None)
                    elif label == "missing-target-version":
                        target.pop("_business_collision_v", None)
                    elif label == "missing-shooter-x":
                        attacker.pop("_interior_x", None)
                    elif label == "missing-target-y":
                        target.pop("_interior_y", None)
                    cadence_before = now - 99.0
                    attacker["_melee_attack_t"] = cadence_before
                    with patch.object(game, "get_melee_event_receipt", AsyncMock(return_value=None)) as receipt, \
                            patch.object(game, "store_melee_event_receipt", AsyncMock()) as store, \
                            patch.object(game.WorldSim, "apply_authoritative_damage", AsyncMock()) as apply, \
                            patch.object(game.time, "time", return_value=now):
                        hit = await world.apply_player_melee(
                            "101", "202", f"business-invalid-{index}", heavy=True)
                    self.assertIsNone(hit)
                    receipt.assert_awaited_once()
                    apply.assert_not_awaited()
                    store.assert_not_awaited()
                    self.assertEqual(attacker["_melee_attack_t"], cadence_before)

        asyncio.run(scenario())

    def test_sampler_contract_is_bounded_and_fail_closed(self):
        self.assertLessEqual(game.BUSINESS_INTERIOR_COLLISION_STEP, 0.20)
        self.assertEqual(game.BUSINESS_INTERIOR_COLLISION_PAD, 0.12)
        valid = {
            "_business_collision_v": 2,
            "_interior_x": 12.0,
            "_interior_y": 8.0,
        }
        target = {**valid, "_interior_x": 12.8}
        self.assertTrue(game._business_interior_melee_los_clear(
            "coffee", valid, target))
        self.assertFalse(game._business_interior_melee_los_clear(
            "unknown", valid, target))

    def test_room_and_padded_blocker_edges_are_exact(self):
        def point(x, y):
            return {
                "_business_collision_v": 2,
                "_interior_x": x,
                "_interior_y": y,
            }

        # The server accepts the inclusive .25 room inset and rejects the
        # nearest representable coordinate immediately outside it.
        self.assertTrue(game._business_interior_melee_los_clear(
            "coffee", point(.25, .25), point(.25, .25)))
        self.assertTrue(game._business_interior_melee_los_clear(
            "coffee", point(15.75, 10.75), point(15.75, 10.75)))
        self.assertFalse(game._business_interior_melee_los_clear(
            "coffee", point(math.nextafter(.25, 0.0), .25), point(.25, .25)))
        self.assertFalse(game._business_interior_melee_los_clear(
            "coffee", point(15.75, 10.75),
            point(math.nextafter(15.75, math.inf), 10.75)))

        # Coffee's cashier has c=8, w=6.2.  PAD=.12 makes the left
        # exclusion edge c-w/2-PAD. Binary rounding keeps the exact computed
        # edge fail-closed; the nearest value outside is clear and the nearest
        # value inside is blocked.
        padded_left = 8.0 - 6.2 / 2 - game.BUSINESS_INTERIOR_COLLISION_PAD
        outside = point(math.nextafter(padded_left, -math.inf), 2.9)
        edge = point(padded_left, 2.9)
        inside = point(math.nextafter(padded_left, math.inf), 2.9)
        self.assertTrue(game._business_interior_melee_los_clear(
            "coffee", outside, outside))
        self.assertFalse(game._business_interior_melee_los_clear(
            "coffee", edge, edge))
        self.assertFalse(game._business_interior_melee_los_clear(
            "coffee", inside, inside))

    def test_firearm_authority_slice_has_no_business_melee_los_guard(self):
        source = BOT_PATH.read_text(encoding="utf-8")
        melee_start = source.index("    async def apply_player_melee(")
        firearm_start = source.index("    async def apply_player_shoot(", melee_start)
        firearm_end = source.index("    def _bump_wanted(", firearm_start)
        melee_source = source[melee_start:firearm_start]
        firearm_source = source[firearm_start:firearm_end]
        self.assertIn("_business_interior_melee_los_clear", melee_source)
        self.assertNotIn("_business_interior_melee_los_clear", firearm_source)
        self.assertIn(
            "not (business_defense or business_police_fight) and not _world_los",
            firearm_source)

    def test_runtime_firearm_path_never_invokes_business_melee_guard(self):
        async def scenario():
            now = 2_004_100_030.0
            world = _business_world(now=now)
            # Stop at the existing firearm ownership gate after exercising a
            # valid same-business firearm route. The melee-only helper must
            # never be consulted by this path.
            guard = Mock(side_effect=AssertionError(
                "firearm path invoked melee interior LOS"))
            with patch.object(game, "_business_interior_melee_los_clear", guard), \
                    patch.object(game, "get_weapon_shot_receipt", AsyncMock(return_value=None)), \
                    patch.object(game.WorldSim, "_authorize_weapon_shot", return_value=None), \
                    patch.object(game.time, "time", return_value=now):
                hit = await world.apply_player_shoot(
                    "101", "202", "pistol", "firearm-melee-los-spy")
            self.assertIsNone(hit)
            guard.assert_not_called()

        asyncio.run(scenario())


if __name__ == "__main__":
    unittest.main()
