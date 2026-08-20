"""Landmark businesses expose exact family defenders without cloning paid staff."""

import asyncio
import os
import tempfile
from pathlib import Path

import aiosqlite

import npc_empire as ne
from test_npc_empire import _base_db


ROOT = Path(__file__).resolve().parent


async def run() -> None:
    world = (ROOT / 'world.html').read_text(encoding='utf-8')
    bot = (ROOT / 'mafiozi_bot.py').read_text(encoding='utf-8')
    assert "holding_ref = f\"business:{b['id']}\"" in bot
    assert "player_guard_roster_snapshot(db, uid)" in bot
    assert "id=\"bmSecurity\"" in world and "id=\"bmRaidDefense\"" in world
    assert "Штат защищает улицу от обычных банд" in world
    assert "Живые бойцы семьи защищают помещение от рейда босса" in world
    assert "previewOpenLandmarkBusinessDefense" in world
    assert "_stagePreviewPlayerBusinessRaid();_rebuildNpcEmpireFlagSites()" in world
    player_holdings = world.split("const playerHoldings=[...(_playerBuildingProperties||[])]", 1)[1].split(
        "if(_LOCAL_PREVIEW&&_UP.has('previewholdingguards')", 1)[0]
    assert "Math.max(1,Math.min(3,+holding.guard_count||1))" not in player_holdings
    assert "guardHolding.guard_count>0" in player_holdings

    fd, path = tempfile.mkstemp(prefix='landmark_business_defense_', suffix='.db')
    os.close(fd)
    try:
        await _base_db(path)
        now = 2_600_000_000
        async with aiosqlite.connect(path) as db:
            await db.executescript("""
                CREATE TABLE gang_members(
                    id INTEGER PRIMARY KEY,telegram_id INTEGER,current_hp INTEGER);
                CREATE TABLE district_control(
                    telegram_id INTEGER,loc_id TEXT,guard_json TEXT);
            """)
            await db.executemany(
                "INSERT INTO gang_members VALUES(?,101,100)",
                [(member_id,) for member_id in range(1, 7)],
            )
            await db.execute("INSERT INTO district_control VALUES(101,'northside','[1]')")
            # Six paid staff are deliberately present. They must never become
            # six synthetic physical defenders in an NPC-boss interior raid.
            await db.execute(
                "INSERT INTO player_businesses VALUES(101,'coffee',0,0,'ok',0,0,1,6,NULL)"
            )
            await db.execute(
                "INSERT INTO business_property_owners VALUES('coffee',101,'Test',?,0)",
                (now,),
            )
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_relations"
                "(leader_id,telegram_id,score,pact,last_action_at) "
                "VALUES('leila',101,-100,'war',?)", (now,))
            await db.execute(
                "UPDATE npc_empires SET status=CASE WHEN leader_id='leila' THEN 'active' ELSE 'ruined' END,"
                "members=12,strength=360,treasury=50000,next_action_at=?", (now + 10_000,))
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_player_wars"
                "(leader_id,telegram_id,next_attack_at,attacks,last_business_id,last_attack_at) "
                "VALUES('leila',101,?,0,'',0)", (now,))
            await db.commit()

            before = await ne.player_guard_roster_snapshot(db, 101)
        assert before == {'total': 6, 'assigned': 1, 'free': 5, 'by_holding': {}}

        assigned = await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101',
            holding_ref='business:coffee', requested=3, now=now)
        assert assigned == {'ok': True, 'total': 6, 'assigned': 4,
                            'free': 2, 'holding_guards': 3}

        async with aiosqlite.connect(path) as db:
            snapshot = await ne.player_guard_roster_snapshot(db, 101)
        assert snapshot == {
            'total': 6, 'assigned': 4, 'free': 2,
            'by_holding': {'business:coffee': 3},
        }

        state = await ne.state_for(path, 101, now=now)
        raid = state['interior_raids'][0]
        assert raid['target_kind'] == 'business' and raid['apt_key'] == 'business:coffee'
        assert raid['guard_count'] == raid['defender_count'] == 3
        assert raid['guard_roster'] == []
        assert {row['member_id'] for row in raid['defender_roster']} == {2, 3, 4}
        assert await _scalar(path,
            "SELECT guards FROM player_businesses WHERE telegram_id=101 AND biz_id='coffee'") == 6
        print('landmark business defense: paid street staff remain separate; exact living family roster OK')
    finally:
        os.unlink(path)


async def _scalar(path: str, sql: str):
    async with aiosqlite.connect(path) as db:
        row = await (await db.execute(sql)).fetchone()
        return row[0]


if __name__ == '__main__':
    asyncio.run(run())
