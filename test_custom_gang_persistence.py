"""Focused migration, concurrency, rollback, deletion and reconnect tests."""

import asyncio
import hashlib
import hmac
import json
import os
import sqlite3
import tempfile
import time
import urllib.parse
from pathlib import Path
from unittest import mock

import aiosqlite
from aiohttp import ClientSession

os.environ.setdefault("BOT_TOKEN", "123456:custom-gang-persistence")
import mafiozi_bot as game


def auth_headers(uid: int) -> dict:
    fields = {
        "auth_date": str(int(time.time())), "query_id": f"persist-{uid}",
        "user": json.dumps({"id": uid, "first_name": "Gang"}, separators=(",", ":")),
    }
    check = "\n".join(f"{key}={fields[key]}" for key in sorted(fields))
    secret = hmac.new(b"WebAppData", os.environ["BOT_TOKEN"].encode(), hashlib.sha256).digest()
    fields["hash"] = hmac.new(secret, check.encode(), hashlib.sha256).hexdigest()
    return {"X-Telegram-Init-Data": urllib.parse.urlencode(fields)}


async def seed(uid: int, name: str, cash: int = 100_000, family: str = "") -> None:
    async with aiosqlite.connect(game.DB_PATH) as db:
        await db.execute(
            "INSERT INTO characters(telegram_id,username,name,class,cash,mafia_family) VALUES(?,?,?,?,?,?)",
            (uid, f"u{uid}", name, "civilian", cash, family),
        )
        await db.execute(
            "INSERT INTO account_characters(account_id,character_id,slot,created_at) VALUES(?,?,1,?)",
            (uid, uid, int(time.time())),
        )
        await db.commit()


async def own_hq(uid: int, key: str) -> None:
    async with aiosqlite.connect(game.DB_PATH) as db:
        await db.execute(
            "INSERT INTO apartments_owned(telegram_id,apt_key,price,bought_at,property_kind) VALUES(?,?,?,?, 'hq')",
            (uid, key, 5000, int(time.time())),
        )
        await db.commit()


async def run() -> None:
    with tempfile.TemporaryDirectory(prefix="mafiozi-gang-persistence-") as retained:
        game.DB_PATH = str(Path(retained) / "legacy.db")
        # Exact legacy shape: init_db must add both columns and all child tables/indexes.
        with sqlite3.connect(game.DB_PATH) as db:
            db.execute("""CREATE TABLE custom_gangs(
                id INTEGER PRIMARY KEY AUTOINCREMENT,leader_uid INTEGER NOT NULL UNIQUE,
                name TEXT NOT NULL COLLATE NOCASE UNIQUE,flag_primary TEXT NOT NULL,
                flag_secondary TEXT NOT NULL,flag_emblem TEXT NOT NULL,
                hq_apt_key TEXT NOT NULL UNIQUE,created_at INTEGER NOT NULL DEFAULT 0)""")
            db.execute("""CREATE TABLE custom_gang_members(
                gang_id INTEGER NOT NULL,telegram_id INTEGER NOT NULL UNIQUE,
                role TEXT NOT NULL DEFAULT 'member',joined_at INTEGER NOT NULL DEFAULT 0,
                invited_by INTEGER DEFAULT NULL,PRIMARY KEY(gang_id,telegram_id))""")
        await game.init_db();await game.ensure_apartment_tables()
        async with aiosqlite.connect(game.DB_PATH) as db:
            columns={row[1] for row in await (await db.execute("PRAGMA table_info(custom_gangs)")).fetchall()}
            tables={row[0] for row in await (await db.execute("SELECT name FROM sqlite_master WHERE type='table'")).fetchall()}
            indexes={row[0] for row in await (await db.execute("SELECT name FROM sqlite_master WHERE type='index'")).fetchall()}
        assert {'treasury','edited_at'} <= columns
        assert {'custom_gang_npcs','custom_gang_audit'} <= tables
        assert {'ux_custom_gang_one_leader','ix_custom_gang_npcs_owner','ix_custom_gang_audit_gang'} <= indexes
        # Re-running migrations must be harmless.
        await game.init_db();await game.ensure_apartment_tables()

        for uid in range(82001,82018):await seed(uid,f"Игрок {uid}")
        await own_hq(82001,"tile:16,16");await own_hq(82002,"tile:26,26")
        flag=game.normalize_custom_gang_flag("#3154a5","#ece5d5","wolf")
        raced=await asyncio.gather(
            game.create_custom_gang_db(82001,"tile:16,16","Единое Имя",flag,[]),
            game.create_custom_gang_db(82002,"tile:26,26","ЕДИНОЕ ИМЯ",flag,[]),
        )
        assert sum(bool(x.get('ok')) for x in raced)==1,raced
        winner=82001 if raced[0].get('ok') else 82002
        loser=82002 if winner==82001 else 82001
        assert (await game.disband_custom_gang_db(winner))['ok']

        created=await game.create_custom_gang_db(82001,"tile:16,16","Надёжные",flag,[82003])
        assert created['ok'];gang_id=created['gang_id']
        joins=await asyncio.gather(*(
            game.join_custom_gang_db(gang_id,uid,82001) for uid in range(82004,82018)
        ))
        gang=await game.get_custom_gang_for_user(82001)
        assert gang['member_count']==game.CUSTOM_GANG_MAX_MEMBERS
        assert sum(bool(x.get('ok')) for x in joins)==game.CUSTOM_GANG_MAX_MEMBERS-2
        joined_uids=[uid for uid,result in zip(range(82004,82018),joins) if result.get('ok')]
        async with aiosqlite.connect(game.DB_PATH) as db:
            leaders=int((await (await db.execute(
                "SELECT COUNT(*) FROM custom_gang_members WHERE gang_id=? AND role='leader'",(gang_id,)
            )).fetchone())[0])
        assert leaders==1

        deposits=await asyncio.gather(*(
            game.custom_gang_treasury_db(uid,100) for uid in (82001,82003,*joined_uids[:2])
        ))
        assert all(x['ok'] for x in deposits)
        gang=await game.get_custom_gang_for_user(82001);assert gang['treasury']==400
        assert (await game.custom_gang_treasury_db(82003,-1))['error']=='leader only'
        assert (await game.custom_gang_treasury_db(82001,1000))['ok']
        edited=await game.edit_custom_gang_db(82001,"Надёжный Союз",flag)
        assert edited['ok']
        assert (await game.edit_custom_gang_db(82001,"Повтор",flag))['error']=='edit cooldown'

        world=game.WorldSim();world.city_gangs.clear();world.gang_nests.clear()
        gang=await game.get_custom_gang_for_user(82003)
        world.players['82003']={'uid':'82003','x':20.0,'y':20.0,'_cash':99_600}
        game.apply_custom_gang_to_player(world.players['82003'],gang)
        bot={'id':'atomic-hire','x':20.5,'y':20.0,'alive':True,'hp':100,'max_hp':100,
             'level':5,'kind':'street','weapon':'smg','look':{'skin':2},'_shot_t':0.0}
        world.city_gangs.append({'id':'hire','faction':'purple','bots':[bot]})
        with mock.patch.object(game,'commit_custom_gang_hire_db',side_effect=RuntimeError('disk')):
            failed=await world.hire_city_gang_bot('82003','atomic-hire')
        assert not failed['ok'] and failed['reason']=='persist_failed' and bot['alive']
        before=int((await game.get_character(82003))['cash'])
        hired=await world.hire_city_gang_bot('82003','atomic-hire')
        assert hired['ok'] and hired['npc'] and not bot['alive']
        assert int((await game.get_character(82003))['cash'])==before-hired['cost']
        replay=await world.hire_city_gang_bot('82003','atomic-hire')
        assert not replay['ok'] and int((await game.get_character(82003))['cash'])==before-hired['cost']

        reconnected=await game.get_custom_gang_for_user(82003)
        live={};game.apply_custom_gang_to_player(live,reconnected)
        payload=game.custom_gang_player_payload(live)
        assert payload['npcs'][0]['source_bot_id']=='atomic-hire'
        assert (await game.kick_custom_gang_member_db(82001,82003))['ok']
        async with aiosqlite.connect(game.DB_PATH) as db:
            left=int((await (await db.execute("SELECT COUNT(*) FROM custom_gang_npcs WHERE owner_uid=82003")).fetchone())[0])
        assert left==0

        try:await game.delete_account_profile(82001,82001)
        except ValueError as exc:assert str(exc)=='custom_gang_leader'
        else:raise AssertionError('leader profile deletion was not blocked')
        target=int(next(m['telegram_id'] for m in (await game.get_custom_gang_for_user(82001))['members'] if m['role']=='member'))
        assert (await game.transfer_custom_gang_leadership_db(82001,target))['ok']
        assert await game.delete_account_profile(82001,82001)
        assert await game.get_custom_gang_for_user(82001) is None

        game._WORLD=game.WorldSim();os.environ['PORT']='18762'
        runner=await game._coop_http_app();base='http://127.0.0.1:18762'
        async with ClientSession() as session:
            async with session.get(f"{base}/custom-gang/{target}/state") as response:
                assert response.status==401
            async with session.get(f"{base}/custom-gang/{target}/state",headers=auth_headers(82002)) as response:
                assert response.status==401
            async with session.get(f"{base}/custom-gang/{target}/state",headers=auth_headers(target)) as response:
                assert response.status==200 and (await response.json())['ok']
        await runner.cleanup();await asyncio.sleep(.05)

        source=(Path(__file__).parent/'world.html').read_text(encoding='utf-8')
        assert '_apiRequest(`${QP.api.replace' in source
        assert 'function _mergeServerGangNpcs' in source and '/npcs/sync' in source
        print('OK: migration, idempotency, uniqueness, capacity, concurrency, rollback, deletion, auth and reconnect')


if __name__=='__main__':asyncio.run(run())
