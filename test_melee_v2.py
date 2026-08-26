import asyncio
import json
import math
import os
import subprocess
from pathlib import Path
from unittest.mock import AsyncMock, patch

os.environ.setdefault("BOT_TOKEN", "123456:melee-v2")

import mafiozi_bot as game


ROOT = Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")


def _arena_world():
    world = game.WorldSim()
    world.add_or_update("101", "One", {})
    world.add_or_update("202", "Two", {})
    x = (world.ARENA_C0 + world.ARENA_C1) / 2
    y = (world.ARENA_R0 + world.ARENA_R1) / 2
    for index, player in enumerate((world.players["101"], world.players["202"])):
        player.update(x=x + index, y=y, dead=False, hp=100, max_hp=100,
                      ang=0 if index == 0 else math.pi,
                      _mode="pvp", _weapon="fists", _stance="stand")
    return world


def test_block_is_hold_only_and_attack_pose_expires():
    assert "addEventListener('pointerup'" in THREE
    assert "bridge?.setMeleeBlock?.(false)" in THREE
    assert "released:blur" in THREE
    assert "released:reconnect" in WORLD
    assert "stateNow-_punchAnim.startAt>=Math.max(1,+_punchAnim.duration||430)" in WORLD
    assert "state.dead||state.prone||state.arrestPhase||state.vehicleEntry" in THREE
    assert "releaseMeleeBlock('mouseup')" in THREE
    assert "releaseMeleeBlock('buttons-mask')" in THREE
    assert "_meleeBlockHeld ? .80 : 1" in WORLD


def test_weapon_grip_survives_melee_mode_switch():
    assert "const poseOneHandedGrip=" in THREE
    assert "poseOneHandedGrip(Math.min(1.9,kickNorm))" in THREE
    assert "releaseMeleeBlock(!isUnarmedPrimary()?'weapon-equipped'" in THREE


def test_prone_is_rejected_at_input_network_and_server():
    assert "function _meleeActionLocked()" in WORLD
    assert "_effectivePlayerStance()==='prone'" in WORLD
    assert "inputData.stance=_effectivePlayerStance()" in WORLD
    assert "str(shooter.get('_stance') or 'stand') == 'prone'" in Path(
        ROOT / "mafiozi_bot.py").read_text(encoding="utf-8")
    world = _arena_world()
    world.players["101"]["_stance"] = "prone"
    assert world._melee_state_locked(world.players["101"])
    assert world._authorize_weapon_shot(world.players["101"], "pistol") is None


def test_side_kick_and_bounded_npc_bruises_contract():
    assert "1.4+extend*1.58" in THREE
    assert "20-percent-high-side-kick-with-foot" in THREE
    assert "meleeKickFoot.visible=true" in THREE
    assert "const setNpcLimbBetween=" in THREE
    assert "pose.meleeKick&&side===pose.meleeKickSide" in THREE
    assert "side=meleePose.leg==='left'?-1:1" in THREE
    assert "single-leg-forward-high-kick-v2" in THREE
    assert "leftKneelShin.visible=rightKneelShin.visible=false" in THREE
    assert "let _meleeKickSide = 1" in WORLD
    assert "melee=smart-heavy-forward-kick-v16" in WORLD
    assert "dataset.meleeImpact=`${attackSeq}:miss:${!impactLineClear?'blocked-line':'no-contact'}`" in WORLD
    assert "n._pendingMeleeImpactAt=now+(n._meleeType==='kick'?165:175)" in WORLD
    assert "if (d > 28 || myDead)" in WORLD
    assert "bruise:makeInstances" in THREE
    assert "NPC_CAP,false" in THREE
    assert "if(bruiseAt&&bruiseAge<60000&&!pose.dead)" in THREE
    assert "else hidePart(npcParts.bruise,i)" in THREE
    assert "const MELEE_BRUISE_LIFETIME_MS=60000" in WORLD
    assert "_meleeBruiseAt=impactNow" in WORLD
    assert "meleeBruiseAt:stateNow-_meleeBruiseAt<MELEE_BRUISE_LIFETIME_MS" in WORLD
    assert "playerMeleeBruise.visible=playerBruiseAt>0&&playerBruiseAge<60000" in THREE
    assert "bruiseAge<60000" in THREE
    assert "new THREE.ExtrudeGeometry(knockoutStarShape" in THREE
    assert "meleeStrike=!dead&&unarmed&&shotAge<470" in THREE
    assert "if(meleeKickSide<0){leftSwing=-1.18*meleePulse" in THREE
    assert "else{rightSwing=-1.18*meleePulse" in THREE


def test_online_melee_server_owns_damage_cadence_and_critical():
    async def scenario():
        world = _arena_world()
        damage = {"body": {"dead": False}, "replayed": False}
        with patch.object(game, "get_melee_event_receipt", AsyncMock(return_value=None)), \
                patch.object(game, "store_melee_event_receipt", AsyncMock()) as store, \
                patch.object(game.WorldSim, "apply_authoritative_damage", AsyncMock(return_value=damage)) as apply, \
                patch.object(game.random, "random", return_value=1.0), \
                patch.object(game.time, "time", return_value=2_004_000_000.0):
            first = await world.apply_player_melee("101", "202", "attack-1")
            assert first and first["dmg"] == 12 and not first["critical"]
            apply.assert_awaited_once_with(
                "202", "world:melee:101:attack-1", "melee_punch", 12)
            store.assert_awaited_once()
            # Same actor cannot bypass the shared 0.30 second melee cadence by
            # choosing a new attack id or by claiming a client-side critical.
            second = await world.apply_player_melee("101", "202", "attack-2")
            assert second is None

        world.players["101"]["_melee_attack_t"] = 0
        with patch.object(game, "get_melee_event_receipt", AsyncMock(return_value=None)), \
                patch.object(game, "store_melee_event_receipt", AsyncMock()), \
                patch.object(game.WorldSim, "apply_authoritative_damage", AsyncMock(return_value=damage)) as apply, \
                patch.object(game.random, "random", return_value=0.01), \
                patch.object(game.time, "time", return_value=2_004_000_001.0):
            critical = await world.apply_player_melee("101", "202", "attack-3")
            assert critical and critical["melee_type"] == "kick"
            assert critical["dmg"] == 21 and critical["critical"]
            assert apply.await_args.args[-1] == 21

    asyncio.run(scenario())


def test_heavy_melee_requires_hold_and_pierces_block():
    assert "const HEAVY_MELEE_CHARGE_MS = 1200" in WORLD
    assert "meleeChargeTimer=setTimeout" in THREE
    assert "beginMeleeAtPointer(meleeChargePointer,true)" in THREE
    assert "immediate-forward-run" in THREE
    assert "const title='СУПЕР УДАР'" in THREE
    assert "КОПИТСЯ СУПЕРУДАР" not in THREE
    assert "meleeChargeLabel.visible=false" in THREE
    assert "(+meleeChargePose.elapsed||0)>=180" in THREE
    assert "Math.random()>=.28" in WORLD
    assert "(pose.meleeStrike&&!pose.meleeKick)||pose.meleeGuard||pose.meleeCharging" in THREE
    assert "if(meleeGuard||meleePose?.type!=='kick')poseBoxingGuard()" in THREE
    assert "Math.random()<.16" in WORLD
    assert "blockPiercing:heavyAttack" in WORLD
    assert "dashStepDistance=.09,dashSteps=7" in WORLD
    assert "short-forward-run" in WORLD
    assert "},16);" in WORLD and "},0);" in WORLD
    assert "bridge?.setMeleeCharge?.(false);" in THREE

    async def scenario():
        world = _arena_world()
        damage = {"body": {"dead": False}, "effective_damage": 18,
                  "melee_block_pierced": True, "replayed": False}
        now = 2_004_000_010.0
        world.players["101"]["_melee_charge_t"] = now - 1.2
        world.players["202"]["_melee_block"] = True
        with patch.object(game, "get_melee_event_receipt", AsyncMock(return_value=None)), \
                patch.object(game, "store_melee_event_receipt", AsyncMock()), \
                patch.object(game.WorldSim, "apply_authoritative_damage", AsyncMock(return_value=damage)) as apply, \
                patch.object(game.random, "random", return_value=0.1), \
                patch.object(game.time, "time", return_value=now):
            heavy = await world.apply_player_melee(
                "101", "202", "heavy-1", heavy=True)
            assert heavy and heavy["heavy"] and heavy["block_piercing"]
            assert heavy["block_pierced"] and not heavy["blocked"]
            assert heavy["stunned"] and heavy["stun_seconds"] == 2.0
            apply.assert_awaited_once_with(
                "202", "world:melee:101:heavy-1", "melee_heavy", 18)

        world.players["101"]["_melee_attack_t"] = 0
        world.players["101"]["_melee_charge_t"] = now - 0.5
        with patch.object(game, "get_melee_event_receipt", AsyncMock(return_value=None)), \
                patch.object(game.time, "time", return_value=now):
            assert await world.apply_player_melee(
                "101", "202", "heavy-too-early", heavy=True) is None

    asyncio.run(scenario())


def test_grounded_online_target_is_always_kicked_by_server():
    async def scenario():
        world = _arena_world()
        world.players["202"]["_stance"] = "prone"
        damage = {"body": {"dead": False}, "replayed": False}
        with patch.object(game, "get_melee_event_receipt", AsyncMock(return_value=None)), \
                patch.object(game, "store_melee_event_receipt", AsyncMock()), \
                patch.object(game.WorldSim, "apply_authoritative_damage", AsyncMock(return_value=damage)) as apply, \
                patch.object(game.random, "random", return_value=1.0), \
                patch.object(game.time, "time", return_value=2_004_000_002.0):
            hit = await world.apply_player_melee("101", "202", "grounded-1")
            assert hit and hit["grounded_target"] and hit["melee_type"] == "kick"
            assert hit["critical"] and hit["raw_dmg"] == 21
            apply.assert_awaited_once_with(
                "202", "world:melee:101:grounded-1", "melee_kick", 21)

    asyncio.run(scenario())


def test_civilian_fight_roll_is_stable_twenty_percent():
    assert "_civilianFightDecision=Math.random()<.20?'fight':'flee'" in WORLD
    assert "if(npc._civilianFightDecision==='flee')" in WORLD
    assert "previewCivilianFightAttempts" in WORLD
    assert "proneTarget=_meleeTargetIsProne(tgt)" in WORLD
    assert "contactRange=heavyAttack?1.68:n._meleeType==='kick'?1.48:1.24" in WORLD
    assert "const impactDistance=Math.hypot(player.r-n.r,player.c-n.c)" in WORLD
    assert "const heavyAttack=n._npcHeavyAttack===true" in WORLD
    assert "_planNpcRouteTo(n,player.r,player.c,npcPassableForSnitch,1.2,900,'melee-chase')" in WORLD
    assert "_npcAdvanceRoute(n,dt,chaseSpeed,npcPassableForSnitch)" in WORLD
    assert "if(n._routeKind==='melee-chase')_clearNpcRoute(n)" in WORLD


def test_heavy_target_assist_and_knockout_fx_are_bounded():
    assert "const acquireRange=heavy?2.42:PUNCH_RANGE,acquireDot=heavy?.45:.72" in WORLD
    assert "if(!tgt&&heavy)tgt=_findNearestMeleeTarget" in WORLD
    assert "const liveTarget=tgt?.getPos?.()" in WORLD
    assert "if(!tgt&&!heavy)tgt=_findNearestMeleeTarget(null,1.38)" in WORLD
    assert "npc._meleeStunnedUntil=npc._meleeStunnedAt+2000" in WORLD
    assert "⭐ НОКАУТ ⭐" in WORLD
    assert "npcStunStars=makeInstances" in THREE
    assert "NPC_CAP*4,false" in THREE
    assert "dataset.npcMeleeStunStars" in THREE
    assert "name:fxNow<(+x._meleeStunnedUntil||0)?'⭐ НОКАУТ ⭐'" in WORLD
    assert "priority-screen-declutter-casualty-readable-v407" in THREE
    assert "!npcIsDead(src)||src.meleeStunned" in THREE
    assert "knockout-fallen-stars" in THREE
    assert "new THREE.ExtrudeGeometry(knockoutStarShape" in THREE
    assert "fillText('НОКАУТ',192,36)" in THREE
    assert "playerAnim.knockoutYaw" in THREE
    assert "playerStunFx.position.set(player.position.x,4.65,player.position.z)" in THREE
    assert "if(!mouseAimActive||animationActionLocked)return" in THREE


def test_block_reduces_only_unarmed_melee_to_ten_percent():
    async def scenario():
        world = game.WorldSim()
        world.add_or_update("target", "Target", {})
        target = world.players["target"]
        target.update(dead=False, hp=100, max_hp=100, _melee_block=True)
        token = game._SYNC_WORLD_HARNESS.set(True)
        try:
            melee = await world.apply_authoritative_damage(
                "target", "melee:block", "melee_punch", 12)
            assert melee["melee_blocked"]
            assert melee["body"]["damage"] == 1
            target.update(dead=False, hp=100, max_hp=100)
            bullet = await world.apply_authoritative_damage(
                "target", "bullet:block", "bullet", 12)
            assert not bullet.get("melee_blocked")
            assert bullet["body"]["damage"] == 12
            target.update(dead=False, hp=100, max_hp=100)
            heavy = await world.apply_authoritative_damage(
                "target", "heavy:block", "melee_heavy", 18)
            assert heavy["melee_block_pierced"]
            assert not heavy.get("melee_blocked")
            assert heavy["body"]["damage"] == 18
            target.update(dead=False, hp=100, max_hp=100)
            back = await world.apply_authoritative_damage(
                "target", "back:block", "melee_back_punch", 12)
            assert back["melee_block_pierced"]
            assert back["melee_block_bypass"] == "back"
            assert not back.get("melee_blocked")
            assert back["body"]["damage"] == 12
        finally:
            game._SYNC_WORLD_HARNESS.reset(token)

    asyncio.run(scenario())


def test_online_back_attack_is_classified_before_block_resolution():
    async def scenario():
        world = _arena_world()
        # Attacker 101 stands west of 202. Facing east turns the target's back
        # toward that incoming strike; the server must own this classification.
        world.players["202"].update(ang=0, _melee_block=True)
        damage = {"body": {"dead": False}, "effective_damage": 12,
                  "melee_block_pierced": True,
                  "melee_block_bypass": "back", "replayed": False}
        with patch.object(game, "get_melee_event_receipt", AsyncMock(return_value=None)), \
                patch.object(game, "store_melee_event_receipt", AsyncMock()), \
                patch.object(game.WorldSim, "apply_authoritative_damage",
                             AsyncMock(return_value=damage)) as apply, \
                patch.object(game.random, "random", return_value=1.0), \
                patch.object(game.time, "time", return_value=2_004_000_020.0):
            hit = await world.apply_player_melee("101", "202", "back-1")
            assert hit and hit["back_attack"] and hit["block_pierced"]
            assert not hit["blocked"] and hit["dmg"] == 12
            apply.assert_awaited_once_with(
                "202", "world:melee:101:back-1", "melee_back_punch", 12)

    asyncio.run(scenario())


def test_local_melee_requires_clear_line_at_impact_in_both_directions():
    assert "function _meleeLineClear(r0,c0,r1,c1)" in WORLD
    assert "if(_bankInt)" in WORLD
    assert "if(_buildingInt)return _majorInteriorLineClear" in WORLD
    assert "return _policeWorldLineClear(r0,c0,r1,c1)" in WORLD
    assert "impactLineClear=!!impactPos&&_meleeLineClear(player.r,player.c" in WORLD
    assert "impactDistance>contactRange||!impactLineClear" in WORLD
    assert "impactLineClear=_meleeLineClear(n.r,n.c,player.r,player.c)" in WORLD
    assert "impactDistance<=contactRange&&impactLineClear" in WORLD
    assert "'blocked-line':'no-contact'" in WORLD

    start = WORLD.index("function _meleeLineClear(r0,c0,r1,c1)")
    source = WORLD[start:WORLD.index("function _npcConsiderMeleeBlock", start)]
    script = f"""
let _bankInt=null,_buildingInt=null;
let policeResult=false,interiorResult=false,bankBlocked=false;
const _policeWorldLineClear=()=>policeResult;
const _majorInteriorLineClear=()=>interiorResult;
const _isBlockedInterior=()=>bankBlocked;
{source}
const result=[];
result.push(_meleeLineClear(0,0,1,1));
policeResult=true;result.push(_meleeLineClear(0,0,1,1));
_buildingInt={{H:8,W:8}};result.push(_meleeLineClear(1,1,2,2));
interiorResult=true;result.push(_meleeLineClear(1,1,2,2));
_buildingInt=null;_bankInt={{H:8,W:8}};bankBlocked=true;
result.push(_meleeLineClear(1,1,2,2));
bankBlocked=false;result.push(_meleeLineClear(1,1,2,2));
console.log(JSON.stringify(result));
"""
    completed = subprocess.run(
        ["node", "-e", script], cwd=ROOT, text=True,
        capture_output=True, check=True)
    assert json.loads(completed.stdout) == [False, True, False, True, False, True]


if __name__ == "__main__":
    tests = [value for name, value in sorted(globals().items())
             if name.startswith("test_") and callable(value)]
    for test in tests:
        test()
    print(f"melee v2: ok ({len(tests)} checks)")
