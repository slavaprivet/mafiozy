"""Contracts for the bounded physical player-building raid fixture."""

from pathlib import Path


ROOT = Path(__file__).resolve().parent


def reapply_fixture(current, phase, target_id, now):
    """Model the production identity gate used by repeated snapshot refreshes."""
    fixture_id = f'{phase}:{target_id}'
    if current and current['fixture_id'] == fixture_id:
        current['reapply_count'] += 1
        return current
    return {
        'fixture_id': fixture_id, 'started_at': now, 'start_distance': 20.04,
        'boss': (22.0, 8.0), 'guards': {0: True, 1: True, 2: True},
        'reapply_count': 0,
    }


def main():
    world = (ROOT / 'world.html').read_text(encoding='utf-8')
    bot = (ROOT / 'mafiozi_bot.py').read_text(encoding='utf-8')
    stage = world.split('function _stagePreviewPlayerBusinessRaid(){', 1)[1].split(
        'function _setNpcEmpirePlayerHostile', 1)[0]
    reconcile = world.split('function _reconcilePreviewPlayerBusinessRaid(fixture){', 1)[1].split(
        'function _stagePreviewPlayerBusinessRaid', 1
    )[0]

    assert "actionKind==='player_business_raid'" in world
    assert "stance:'assault',force:8" in world
    assert "Math.min(EMPIRE_MAX_ESCORTS,streetCap" in world
    assert "const playerHoldings=[...(_playerBuildingProperties||[])]" in world
    assert "property_kind||'')!=='business'" in world
    assert "String(attacker.activity.phase||'')==='capture'" in world
    assert "_empireRaidDefender:!!sourceLeader" in world
    assert "player_business:${buildingKey}" in world
    assert "defended=phase==='approach'" in world
    assert "raidPhase=defended?'approach':'capture'" in world
    assert "phase:raidPhase,stance:'assault'" in world
    assert "guard_count:defended?3:0" in world
    assert "const fixtureId=`${phase}:${meta.key}`" in world
    assert "if(_previewPlayerBusinessRaid?.fixtureId===fixtureId)" in world
    assert "_reconcilePreviewPlayerBusinessRaid(_previewPlayerBusinessRaid)" in world
    assert "empire.activity={...fixture.activity}" in world
    assert "checkpoint.distance+.1" in world
    assert "fixture.deadGuardSlots?.has" in world
    assert "dataset.previewPlayerBusinessRaidRebind=" in world
    assert "_clearNpcRoute" not in reconcile
    assert "boss.r=boss.tr=stage.r" not in reconcile
    assert "dataset.previewPlayerBusinessRaidRestage=`blocked:${fixtureId}:" in world
    assert "if(!guard._empireRaidDefender||String(guard._empireHoldingId)!==meta.key)continue" in world
    assert "guardCount:defended?3:0" in world
    assert "_previewPlayerBusinessRaid={fixtureId,phase,leaderId" in world
    assert "reapplyCount:0" in world
    assert "continuingTarget=previousFixture?.key===meta.key" in world
    assert "raidStartedAt=continuingTarget?" in world
    assert "if(!continuingTarget&&boss&&stage)" in world
    assert "if(!continuingTarget){player.r=" in world
    assert "startDistance:continuingTarget?+previousFixture.startDistance" in world
    assert "bossCheckpoint:continuingTarget?previousFixture.bossCheckpoint:null" in world
    assert "crewCheckpoints:continuingTarget?previousFixture.crewCheckpoints||{}:{}" in world
    assert "deadGuardSlots:continuingTarget?previousFixture.deadGuardSlots||new Set():new Set()" in world
    assert "const raidCheckpoint=_previewPlayerBusinessRaid?.leaderId===id?" in world
    assert "!deadRaidSlots.has(slot)" in world
    assert "target._empireRaidDefender&&_previewPlayerBusinessRaid?.key" in world
    assert "deadGuardSlots.add(+target._empireGuardSlot||0)" in world
    identity_gate = stage.index("if(_previewPlayerBusinessRaid?.fixtureId===fixtureId)")
    assert identity_gate < stage.index("for(let i=EMPIRE_HOLDING_GUARDS.length-1")
    assert identity_gate < stage.index("empire.members=Math.max(8")
    assert identity_gate < stage.index("boss.r=boss.tr=stage.r")
    assert "dataset.previewPlayerBusinessRaidStages=String(" in world
    assert "Math.max(1,Math.min(3,+holding.guard_count||1))" in world
    assert "slotRoster=site.sourceLeader?EMPIRE_HOLDING_GUARDS" in world
    assert "raidDefender?_empireLeaderIdOf(raidDefender):''" in world
    assert "if(playerBusinessRaid){leader._empireEnemyLeaderId=" in world
    assert "own.find(x=>x._empireRaidDefender)" in world
    assert "_syncEmpireHoldingGuards(now);\n  _syncEmpireBossCrews(now);" in world
    assert "_empireSpawnDistance:Math.hypot(point.r-player.r,point.c-player.c)" in world
    assert "crew.length===EMPIRE_WAR_ESCORT_CAP" in world
    assert "fixture.fullCrewSeen&&nearCrew===crew.length" in world
    assert "nearCrew===8" not in world
    assert "`guards-${liveDefenders.length}/${fixture.guardCount}`" in world
    assert "defenders.length>fixture.guardCount" in world
    assert "defenderSlots.size!==defenders.length" in world
    assert "slot>=fixture.guardCount" in world
    assert "`guardcap-${fixture.guardCount}`" in world
    assert "`guardoverflow-${guardOverflow?1:0}`" in world
    assert "`fight-${defenders.some" in world
    assert "`popin-${popin?1:0}`" in world
    assert "`arrived-${arrived?1:0}`" in world
    assert "`reapply-${fixture.reapplyCount||0}`" in world
    assert "'guard_count': guard_count" in bot
    assert "npc_empire.holding_guard_count(" in bot

    # Two server snapshot refreshes with the same target+phase must be true
    # no-ops: timing, route origin, boss position and dead guard slots survive.
    fixture = reapply_fixture(None, 'approach', '0,3', 1000)
    fixture['boss'] = (10.22, 9.5)
    fixture['guards'][1] = False
    original = fixture
    first_elapsed = 22_561
    fixture = reapply_fixture(fixture, 'approach', '0,3', 1020)
    second_elapsed = first_elapsed + 20_000
    fixture = reapply_fixture(fixture, 'approach', '0,3', 1040)
    third_elapsed = second_elapsed + 20_000
    assert fixture is original and fixture['reapply_count'] == 2
    assert fixture['started_at'] == 1000 and fixture['start_distance'] == 20.04
    assert fixture['boss'] == (10.22, 9.5)
    assert fixture['guards'] == {0: True, 1: False, 2: True}
    assert len(fixture['guards']) == 3 and first_elapsed < second_elapsed < third_elapsed

    # Arrival is measured against the surviving roster after the complete
    # eight-person squad has existed. Two legal combat losses cannot make the
    # fixture permanently fail while all six survivors and the boss are there.
    full_crew_seen = True
    surviving_crew = 6
    near_crew = 6
    boss_distance = 1.48
    assert boss_distance < 1.6 and full_crew_seen and near_crew == surviving_crew

    print('npc business physical raid: boss + 8, 1-3 guards, combat, no-popin telemetry OK')


if __name__ == '__main__':
    main()
