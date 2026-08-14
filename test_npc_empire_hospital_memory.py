"""Hospital events have one canonical, backward-compatible boss memory."""

import asyncio
import os
import tempfile

import aiosqlite

import npc_empire as ne
from test_npc_empire import _base_db


NOW = 2_000_700_000


def _score(plan: dict, strategy: str) -> float:
    return next(item['score'] for item in plan['scores']
                if item['strategy'] == strategy)


async def run() -> None:
    handle, path = tempfile.mkstemp(prefix='npc_hospital_memory_', suffix='.db')
    os.close(handle)
    try:
        await _base_db(path)
        result = await ne.hospitalize_boss(
            path, 'leila', 'hospital_east', now=NOW)
        assert result['ok'] and result['hospital_until'] == NOW + 60
        async with aiosqlite.connect(path) as db:
            db.row_factory = aiosqlite.Row
            row = await (await db.execute(
                "SELECT leader_id,kind,target_id,summary,created_at "
                "FROM npc_empire_events WHERE leader_id='leila' "
                "ORDER BY id DESC LIMIT 1"
            )).fetchone()
        event = dict(row)
        assert event['kind'] == 'hospitalized'

        card = ne._boss_memory_cards([event], NOW)[0]
        assert card['kind'] == 'hospitalized'
        assert card['tone'] == 'negative' and card['importance'] == 86
        adaptation = ne._boss_adaptation([event], NOW)
        assert adaptation['recent_wounds'] == 1

        # A persisted pre-canonical save produces exactly the same card and
        # wound lesson instead of degrading to a neutral generic event.
        legacy = {**event, 'kind': 'hospital'}
        legacy_card = ne._boss_memory_cards([legacy], NOW)[0]
        assert legacy_card == card
        assert ne._boss_adaptation([legacy], NOW)['recent_wounds'] == 1

        profile = ne.PROFILE_BY_ID['leila']
        empire = {
            'treasury': 12000, 'members': 20, 'strength': 220,
            'status': 'active', 'hospital_until': 0,
        }
        holdings = [{'kind': 'building', 'holding_id': '4,4'}]
        baseline = ne._boss_brain(
            profile, empire, holdings, [], NOW, active_wars=1,
            neutral_buildings=0, affordable_businesses=0)
        learned = ne._boss_brain(
            profile, empire, holdings, [event], NOW, active_wars=1,
            neutral_buildings=0, affordable_businesses=0)
        # The wound raises defence more than retaliation, a measurable shift
        # rather than merely decorative dossier text.
        fortify_delta = _score(learned, 'fortify') - _score(baseline, 'fortify')
        retaliate_delta = _score(learned, 'retaliate') - _score(baseline, 'retaliate')
        assert fortify_delta > retaliate_delta > 0
        assert learned['adaptation']['recent_wounds'] == 1
        print('npc hospital memory: canonical event, legacy alias, importance and defence shift OK')
    finally:
        if os.path.exists(path):
            try:
                os.unlink(path)
            except PermissionError:
                pass


if __name__ == '__main__':
    asyncio.run(run())
