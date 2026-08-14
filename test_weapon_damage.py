import asyncio
import json
from pathlib import Path

from aiohttp.test_utils import TestClient, TestServer

import _preview_ws_server as game


async def recv_aggro_hit(ws, bot_id, timeout=2):
    async def loop():
        while True:
            msg = await ws.receive()
            data = json.loads(msg.data)
            event = data.get("d", {})
            if (data.get("t") == "event"
                    and event.get("kind") == "aggro_hit"
                    and event.get("bot_id") == bot_id):
                return event
    return await asyncio.wait_for(loop(), timeout)


async def main():
    world = Path(__file__).with_name("world.html").read_text(encoding="utf-8")
    bot_source = Path(__file__).with_name("mafiozi_bot.py").read_text(encoding="utf-8")
    assert "return QP.weapon || null;" in world
    assert "weapon: currentWeapon || 'fists'" in world
    assert "id: 'blackmarket_bellini'" in world
    assert "id: 'blackmarket_moretti'" in world
    assert "issuedByFamily:true" in world
    assert "Этот рынок обслуживает только семью" in world
    assert "family_pistol = key == 'pistol'" in bot_source
    assert "p_ref['_weapon_classes'] = {'pistol'} |" not in bot_source
    assert "CITY_GANG_MAX           = 4" in bot_source
    assert "'npc_gang_fight':True" in bot_source
    assert "**({'suit':'#f3efe5'} if faction == 'yellow' else {})" in bot_source
    assert "function _playWorldNpcWeaponShot(d,onArrival=null)" in world
    assert "spawnBullet(sR,sC,+d.ty,+d.tx,{hit:!d.miss,fromNpc:true,weapon,speed:requestedSpeed})" in world
    assert "_playWorldNpcWeaponShot(d,()=>_applyIntergangBallisticArrival(d))" in world
    assert "damagedProps.values()" not in world, (
        "fire() references a removed collection and aborts before spawnBullet"
    )
    assert "const k = Math.max(0.35, power || 1) * 0.95;" in world
    assert "const kb = 0.09;" in world
    assert "const kb = 0.07;" in world
    assert "Math.min(0.82, baseBulletScale * 0.58)" in world
    assert "Math.min(0.72, baseTrailScale * 0.62)" in world
    assert "rawThreatChat.startsWith('Горю!')" in world
    assert "ВОССТАНОВЛЕНИЕ ${Math.floor(secs/60)}" not in world
    assert "function _igniteInteriorCharacter(n,sourceR,sourceC)" in world
    assert "_hitInteriorNpc(n,0,0,6,'molotov_fire',true)" in world
    assert "drawBurningCharacter(p.x,p.y,nn.id||nn.name||'interior_npc'" in world
    assert "scale*1.35*dt" in world
    assert "moveScale*1.3*dt" in world
    assert "kind === 'business_defense_shot'" in world
    assert "function _markBusinessOperational(businessId, cooldownUntil = 0)" in world
    assert "function _idleBusinessGuardPose(biz, index" in world
    assert "const _businessDefenseChat = new Map()" in world
    assert "? (liveNest ? (liveNest.guards || []) : [])" in world
    assert "function _spawnMajorManager(d = {})" in world
    assert "casino ? 7.65 : 4" in world
    assert "first snapshot can reconcile against that temporary spawn" in world
    assert "socket.onopen = () =>" in world and "sendInput(true);" in world
    assert "casinoOwner.c=casinoOwner.tc=26.35" in world
    assert "const businessOwnerNpc = bi.type === 'business'" in world
    assert "businessOwnerNpc?`👑 ${nn.name}`:nn.name" in world
    assert "kind:'curtain'" in world, "VIP balcony wall must render as a curtain"
    assert "const isCurtain=wall.kind==='curtain'" in world
    assert "function _sendAggroWeaponHit(targetId, weapon)" in world
    assert "sendInput(true);" in world and "_sendAggroWeaponHit(chosenAggro.id" in world
    assert "suit:'#f3efe5'" in world, "yellow gang must use white luxury suits"
    assert "Семья Карло Беллини" in world and "Семья Витторио Моретти" in world
    assert "mafia_family" in world, "client must send mafia family to the server"
    assert "const BURJ_POS = { r: 36, c: 36 }" in world
    assert "{ id: 'mansion', r: 136, c: 16" in world
    assert "function _peacefulInteriorGunLock" in world
    assert "strokeText('ЖЁЛТАЯ БАНДА'" not in world
    assert "(_majorInteriorObjectId && direct.majorGuard)" in world
    assert "_majorRaidLocal?.combatStarted ? _findGangCompanionTarget(m)" in world
    assert "function _majorGuardCombatTarget(bi,n)" in world
    assert "function _hurtGangMemberInInterior(member,damage" in world
    assert "if (!_majorInteriorObjectId && Math.random() < 0.25)" in world
    burn_bot = {
        "id": "burn-test", "x": 10.0, "y": 10.0,
        "hp": 20, "alive": True, "burn_until": 110.0,
        "burn_tick_at": 100.0, "fire_flee_until": 0.0,
        "threat": "Горю! Врассыпную!", "threat_until": 105.0,
    }
    game.preview_tick_fire_flee(burn_bot, 101.0, 0.1)
    assert burn_bot["hp"] == 14, burn_bot
    game.preview_tick_fire_flee(burn_bot, 111.0, 0.1)
    assert burn_bot["burning"] is False and burn_bot["threat"] == "", burn_bot
    open_x, open_y = 24.0, 24.0
    defense_id = "defense-test"
    game.preview_businesses["defense-owner"] = {
        defense_id: {"guards": 1, "level": 1},
    }
    game.preview_business_nests[defense_id] = {
        "id": "preview_defense_test", "business_id": defense_id,
        "faction": "yellow", "r": open_y, "c": open_x,
        "state": "guard", "expires_at": 9999999999.0,
        "owner_uid": "defense-owner",
        "bots": [{
            "id": "defense-raider", "x": open_x + 6.0, "y": open_y,
            "ang": 0.0, "hp": 200, "max_hp": 200, "alive": True,
            "weapon": "pistol_heavy", "look": {},
        }],
        "guards": [{
            "id": "defense-guard", "x": open_x, "y": open_y,
            "ang": 0.0, "hp": 200, "max_hp": 200, "alive": True,
            "weapon": "pistol",
        }],
    }
    defense_events = game.tick_preview_business_raiders(1000.0, 1 / 15)
    defense_nest = game.preview_business_nests[defense_id]
    assert any(e.get("kind") == "business_defense_shot"
               for e in defense_events), defense_events
    assert defense_nest["guards"][0]["act"] == "walk", defense_nest["guards"][0]
    assert defense_nest["bots"][0]["act"] == "walk", defense_nest["bots"][0]
    defense_nest["bots"][0]["hp"] = 1
    defense_nest["guards"][0]["_shot_t"] = 0
    clear_events = game.tick_preview_business_raiders(1002.0, 1 / 15)
    assert defense_id not in game.preview_business_nests
    assert any(e.get("kind") == "gang_nest_cleared"
               and e.get("business_id") == defense_id
               for e in clear_events), clear_events
    game.preview_businesses.pop("defense-owner", None)
    game.players.clear()
    for bot_id in game.PREVIEW_STREET_GANG_HP:
        game.PREVIEW_STREET_GANG_HP[bot_id] = 100

    server = TestServer(game.app)
    client = TestClient(server)
    await client.start_server()
    ws = await client.ws_connect("/world/sim?uid=weapon-test")
    await ws.receive()

    weapons = {
        "pistol": 24, "nagan": 32, "revolver": 86,
        "pistol_heavy": 72, "pistol_gold": 48,
        "shotgun": 76, "smg": 15, "tommy_gun": 24,
        "golden_tommy": 24, "rifle": 42, "sniper": 132,
        "rpg": 160, "tt_pistol": 24, "deagle": 72,
        "sawn_off": 76, "uzi": 15, "ak74": 42,
    }
    bot_id = "cgbot_preview_street_0_0"
    stable_a = next(
        bot for _, _, bots in game.preview_street_gang_bots(1000)
        for bot in bots if bot["id"] == bot_id
    )
    stable_b = next(
        bot for _, _, bots in game.preview_street_gang_bots(1001)
        for bot in bots if bot["id"] == bot_id
    )
    assert stable_a["level"] == stable_b["level"]
    assert stable_a["max_hp"] == stable_b["max_hp"]
    for weapon, expected_damage in weapons.items():
        game.PREVIEW_STREET_GANG_HP[bot_id] = 220
        target = next(
            bot for _, _, bots in game.preview_street_gang_bots()
            for bot in bots if bot["id"] == bot_id
        )
        assert target["look"]["suit"] == "#f3efe5", target["look"]
        await ws.send_json({"t":"input", "d":{
            "x":target["x"], "y":target["y"] + 1,
            "ang":0, "mafia":True, "police":False, "gang":[],
        }})
        await asyncio.sleep(.02)
        await ws.send_json({"t":"aggro_shoot", "d":{
            "target":bot_id, "weapon":weapon,
        }})
        hit = await recv_aggro_hit(ws, bot_id)
        assert hit["damage"] == expected_damage, (weapon, hit)
        assert hit["hp"] == 220 - expected_damage, (weapon, hit)

    # Последний убитый захватчик бизнеса должен не только исчезнуть из
    # snapshot, но и немедленно прислать клиенту освобождение бизнеса.
    business_id = "coffee"
    business_bot_id = "preview_test_coffee_raider"
    game.preview_business_nests[business_id] = {
        "id":"preview_test_coffee_nest", "business_id":business_id,
        "faction":"yellow", "r":33.0, "c":13.0, "state":"hostile",
        "expires_at":9999999999.0, "target_uid":"weapon-test",
        "hostile_until":9999999999.0, "owner_uid":"weapon-test",
        "combat_at":9999999999.0, "guards":[],
        "bots":[{
            "id":business_bot_id, "x":13.0, "y":33.0,
            "hp":10, "max_hp":10, "alive":True, "level":1,
            "weapon":"pistol", "kind":"aggro_grunt", "look":{},
        }],
    }
    await ws.send_json({"t":"input", "d":{
        "x":13.0, "y":34.0, "ang":0,
        "mafia":True, "police":False, "gang":[],
    }})
    await asyncio.sleep(.02)
    await ws.send_json({"t":"aggro_shoot", "d":{
        "target":business_bot_id, "weapon":"pistol",
    }})
    await recv_aggro_hit(ws, business_bot_id)
    cleared = None
    while cleared is None:
        msg = await asyncio.wait_for(ws.receive(), 2)
        data = json.loads(msg.data)
        event = data.get("d", {})
        if data.get("t") == "event" and event.get("kind") == "gang_nest_cleared":
            cleared = event
    assert cleared["business_id"] == business_id, cleared
    assert business_id not in game.preview_business_nests

    await ws.close()
    await client.close()
    print("WEAPON_DAMAGE_E2E_OK")


asyncio.run(main())
