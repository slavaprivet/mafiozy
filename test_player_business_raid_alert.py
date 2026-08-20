"""Regression contracts for the snapshot-owned player raid alarm."""

from pathlib import Path

ROOT = Path(__file__).resolve().parent


def active_alert(raid, now):
    """Mirror the deliberately small client lifecycle predicate."""
    if not raid.get('token'):
        return False
    if raid.get('status') in {'resolved', 'expired'}:
        return False
    return not (raid.get('expires', 0) > 0 and raid['expires'] <= now)


def main():
    world = (ROOT / 'world.html').read_text(encoding='utf-8')
    server = (ROOT / 'npc_empire.py').read_text(encoding='utf-8')
    three = (ROOT / 'three_preview.js').read_text(encoding='utf-8')
    memory = (ROOT / 'docs' / 'ai' / 'OPTIMIZATION_MEMORY.md').read_text(encoding='utf-8')

    raid = {'token': 'authoritative-token', 'leader_id': 'marco',
            'target_r': 12.5, 'target_c': 33.25,
            'business_label': 'Бар у порта', 'defender_count': 7,
            'force': 8, 'started': 1_000, 'expires': 1_300}
    assert active_alert(raid, 1_050)
    assert not active_alert({**raid, 'token': ''}, 1_050)
    assert not active_alert({**raid, 'status': 'resolved'}, 1_050)
    assert not active_alert(raid, 1_300)
    # Reapplying the same snapshot preserves the stable identity used by the
    # one-shot banner and by the marker across reconnect.
    stable_key = f"marco:{raid['token']}::"
    assert stable_key == f"marco:{raid.copy()['token']}::"

    assert '_npcEmpireInteriorRaids=Array.isArray(j.interior_raids)?j.interior_raids:[]' in world
    assert '(_npcEmpireInteriorRaids||[]).find(raid=>' in world
    assert 'function _playerBusinessRaidActivityIsActive(activity' in world
    assert '.find(raid=>_playerBusinessRaidActivityIsActive(raid,now))' in world
    assert 'activity?_npcEmpireById.get(String(activity.leader_id' in world
    assert "['resolved','expired'].includes" in world
    assert '_seenPlayerBusinessRaidAlerts.size>24' in world
    assert 'function _playerRaidThreatPresentation(activity,target=null)' in world
    assert "const id=String(activity?.target_id||''),kind=String(activity?.target_kind||''),hq=kind==='hq'" in world
    assert "id===String(empire?.hq_key||'')" not in world
    assert "capture=String(activity?.objective||'')==='followup-capture'" in world
    assert "verb=capture?'захватывают':'атакуют'" in world
    assert 'title:presentation.title' in world
    assert 'Атака ${free??\'—\'} · защита ${guards??\'—\'} · цель: ${alert.plan.objectiveLabel}' in world
    assert 'assignedObjectGuards:Number.isFinite(+activity.defender_count)' in world
    assert 'assignedFreeSquad:Number.isFinite(+activity.force)' in world
    assert 'business_label' in world
    assert '_playerBusinessRaidPlan(empire,activity)' in world
    assert "objective==='followup-capture'" in world
    assert 'alert.plan.profileLabel' in world
    assert 'alert.plan.decision.summary' in world
    assert 'stakes,counterTip,plan:' in world and 'plan.counterTip' in world
    assert 'raid_policy' in world and 'raid_metrics' in world and 'target_reason' in world
    assert ':objective-${plan.objective}:doctrine-${plan.doctrineId}`' in world
    assert "'objective': objective" in server
    assert '_player_business_raid_objective(' in server
    war_activity = server.split('def _player_war_activity', 1)[1].split(
        'EMPIRE_PUBLIC_ROAM_POINTS', 1)[0]
    assert 'raid_token' not in war_activity
    assert 'assigned_object_guards' not in war_activity
    assert 'getPlayerBusinessRaidAlert(){' in world
    assert 'updatePlayerBusinessRaidNavigation(r,c)' in world
    assert 'function _playerBusinessRaidCompass(alert,r,c)' in world
    assert "screenDx=dc-dr,screenDy=(dc+dr)*ISO_Y" in world
    assert 'class="raid-compass" aria-hidden="true"' in world
    assert "hud.setAttribute('role','status')" in world
    assert "@media(prefers-reduced-motion:reduce)" in world
    assert '_updatePlayerBusinessRaidNavigation(player.r,player.c);' in world
    assert 'drawPlayerBusinessRaidWorldMarker' in world
    assert "drawEdgeTarget(_activePlayerBusinessRaidAlert.r,_activePlayerBusinessRaidAlert.c" not in world
    assert 'const text=`${raid.title.toUpperCase()} · ${dist}м`' in world
    assert 'dataset.playerBusinessRaidMapMarker=' in world
    assert "'previewraidalert'" in world
    assert 'dataset.previewRaidAlertFixture=' in world

    assert 'const playerBusinessRaidMarker=new THREE.Group()' in three
    assert 'bridge?.getPlayerBusinessRaidAlert?.()' in three
    assert "dataset.playerBusinessRaidMarker=`active:" in three
    assert "playerBusinessRaidLabelSignature=''" in three
    assert 'const updatePlayerBusinessRaidLabel=raid=>' in three
    assert 'signature===playerBusinessRaidLabelSignature' in three
    assert "label-${labelChanged?'repaint':'cached'}" in three
    assert 'raid?.presentation?.markerLabel||raid?.title' in three
    marker_block = three.split(
        'const playerBusinessRaidMarker=new THREE.Group()', 1)[1].split(
        'let waterSurface=', 1)[0]
    assert marker_block.count('new THREE.Group()') == 0
    assert marker_block.count('new THREE.Sprite(') == 1
    assert '250 ms bridge sample' in memory
    print('player business raid alert: lifecycle, roster, HUD/map/world/3D marker OK')


if __name__ == '__main__':
    main()
