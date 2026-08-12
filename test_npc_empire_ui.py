"""Static regression contract for the readable empire dashboard and dossier navigation."""

from pathlib import Path


WORLD = (Path(__file__).resolve().parent / "world.html").read_text(encoding="utf-8")
THREE = (Path(__file__).resolve().parent / "three_preview.js").read_text(encoding="utf-8")
PREVIEW = (Path(__file__).resolve().parent / "_preview_ws_server.py").read_text(encoding="utf-8")
NPC_EMPIRE = (Path(__file__).resolve().parent / "npc_empire.py").read_text(encoding="utf-8")


def run() -> None:
    assert "id='npcEmpireReadableUi'" in WORLD
    assert "font-size:14px" in WORLD
    assert "font-size:15px;line-height:1.55" in WORLD
    assert 'class="ne-rank-grid"' in WORLD
    assert 'data-ne-portrait=' in WORLD
    assert "← К СПИСКУ БОССОВ" in WORLD
    assert "close.classList.add('ne-dossier-close')" in WORLD
    assert "close.setAttribute('aria-label'" in WORLD
    assert "ov.dataset.locked='1'" in WORLD
    assert "back.onclick=openNpcSandboxDashboard" in WORLD
    assert "_npcEmpireAttitude" in WORLD and "НЕГАТИВНО" in WORLD and "ПОЛОЖИТЕЛЬНО" in WORLD
    assert "data-ne-declare-war" in WORLD and "НУЖНО НИЖЕ 0" in WORLD
    assert "data-ne-extra=\"apologize\"" in WORLD and "data-ne-extra=\"compensation\"" in WORLD
    assert "_empirePlayerWar" in WORLD and "_empireSpeak(n,'playerWar'" in WORLD
    assert "activity.target_r" in WORLD and "empireBossMotion" in WORLD
    assert "tile===14||tile===15||tile===17" in WORLD
    assert "ri>0&&ri<MAP_ROWS-1&&ci>0&&ci<MAP_COLS-1&&!isBlockedPed(r,c)" in WORLD
    assert "_visible_activity(" in PREVIEW
    assert "dataset.portraitMode" in WORLD and "2d-fallback" in WORLD
    assert "КАРТА КРИМИНАЛЬНОЙ ВЛАСТИ" in WORLD and "ИМПЕРИИ ГОРОДА" in WORLD
    assert "boss:true" in WORLD and "weapon:empire?.weapon_base" in WORLD
    assert "ne-card.dossier" in WORLD and "classList.add('dossier')" in WORLD
    assert "#leftCommandHud #npcSandboxButton" in WORLD
    assert "mission.insertAdjacentElement('afterend',button)" in WORLD
    assert "_empireBossWorkWaypoint" in WORLD and "_empireNextWorkMoveAt" in WORLD
    assert "_applyEmpireCrewStyle" in WORLD and "empireCrew:!!x._empireCrew" in WORLD
    assert "_empireFieldCombatThink" in WORLD and "_hitEmpireCombatant" in WORLD
    assert "gang_war:'" in WORLD and "_empireEnemyLeaderId" in WORLD
    assert "empire_retreat" in WORLD and "EMPIRE_FIELD_THINK_MS=260" in WORLD
    assert "_empirePressUntil" in WORLD and "_empireTargetLockUntil" in WORLD
    assert "confidence>=1.12" in WORLD and "powerRatio<.68" in WORLD
    assert "EMPIRE_MAX_ESCORTS=20" in WORLD and "EMPIRE_VISIBLE_CREW_CAP=36" in WORLD
    assert "_empireFormationOffset" in WORLD and "2.3999632297" in WORLD
    assert "_empireSeparationVector" in WORLD and "_empireScatterSquad" in WORLD
    assert "_empireSpeak(target,'scatter'" in WORLD
    assert "overwhelming=force>=10" in WORLD and "assigned*(order.type==='focus'?.72:1.35)" in WORLD
    assert "npc.walking?npc.walkPhase:0" in WORLD
    assert "walking:!death.dead&&declaredMoving" in WORLD
    assert '"kind": "gang_war"' in PREVIEW and '"pact": "war"' in PREVIEW
    assert "_UP.has('previewempirewar')" in WORLD
    assert "leftStage=_nearestEmpireWalkPoint(player.r-4" in WORLD
    assert "ne-dossier-command" in WORLD and "КРИМИНАЛЬНОЕ ДОСЬЕ" in WORLD
    assert "card.scrollTop=0" in WORLD and "uiMode='dossier'" in WORLD
    assert "const empireFlags=inside?[]:_npcEmpireFlagSites" in WORLD
    assert "EMPIRE_FLAG_CAP=64" in THREE and "world-roof-visible-flags-v368" in THREE
    assert "src.empireBoss||src.empireCrew" in THREE and "empireMember=empireBoss||empireCrew" in THREE
    assert "empire-family-card-v360" in THREE
    assert "empireCrew?familyPrimary" in THREE and "empireCrew?familyAccent" in THREE
    assert "empireMember&&src.bossColor" in THREE
    assert "empireHqRoofBox.setFromObject(object)" in THREE
    assert "depthTest:false,depthWrite:false" in THREE
    assert "redrawEmpireHqFlag(marker,src)" in THREE
    assert "marker.flagPivot.rotation.y=Math.atan2" in THREE
    assert "empireHqRoofYAt" in THREE and "const roofY=empireHqRoofYAt" in THREE
    assert "_hospitalizeEmpireBoss" in WORLD and "hospitalPatients" in WORLD
    assert "EMPIRE_HOSPITAL_CAP=6" in THREE and "pooled-roof-icons-v363" in THREE
    assert "3d368-visible-empire-flags" in WORLD
    assert "_playerBuildingProperties=j.properties;_rebuildNpcEmpireFlagSites();" in WORLD
    assert "npc_empire_hospitalize" in PREVIEW and "hospital_until" in PREVIEW
    assert 'empire-card${inHospital?\' hospitalized\':\'\'}' in WORLD
    assert 'class="ns-hospital-mark"' in WORLD and 'class="ns-hospital-cross"' in WORLD
    assert "hospitalUntil=(+e.hospital_until||0)*1000" in WORLD
    assert "dataset.hospitalizedCount" in WORLD and "_hospitalTimer=setTimeout" in WORLD
    assert "uiMode==='dashboard')openNpcSandboxDashboard()" in WORLD
    assert "Boss dossier v3" in WORLD
    assert 'class="ne-photo-rank"' in WORLD and 'class="ne-photo-plaque"' in WORLD
    assert 'class="ne-family-seal"' in WORLD and "--ea" in WORLD
    assert "min-height:66px" in WORLD and "font-size:14px;line-height:1.25" in WORLD
    assert "МОЗГ БОССА · ТЕКУЩИЙ ЗАМЫСЕЛ" in WORLD
    assert "ne-brain-board" in WORLD and "ne-brain-confidence" in WORLD
    assert "empire.brain" in WORLD and "empire.memory" in WORLD
    assert "_boss_brain(" in PREVIEW and "['brain']" in PREVIEW
    assert "_empireSquadOrder" in WORLD and "EMPIRE_SQUAD_ORDER_MS=900" in WORLD
    assert "type==='withdraw'" in WORLD and "type==='regroup'" in WORLD
    assert "type==='focus'" in WORLD and "type==='flank'" in WORLD
    assert "dataset.empireSquadOrder" in WORLD and "now-order.announcedAt>5000" in WORLD
    assert "newOwnLosses" in WORLD and "newEnemyLosses" in WORLD and "setback>=4" in WORLD
    assert "setbackRecovery" in WORLD and "now-lastCasualtyAt>=5000" in WORLD
    assert "dataset.empireSquadSetback" in WORLD
    assert "ВЫУЧЕННЫЙ УРОК" in WORLD and "brain.adaptation" in WORLD
    assert "_boss_adaptation(" in NPC_EMPIRE and "'adaptation': adaptation" in NPC_EMPIRE
    print("npc_empire_ui: 3D cards, dossier, hospital state, attitudes, routes and hostility OK")


if __name__ == "__main__":
    run()
