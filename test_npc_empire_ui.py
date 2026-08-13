"""Static regression contract for the readable empire dashboard and dossier navigation."""

from pathlib import Path


WORLD = (Path(__file__).resolve().parent / "world.html").read_text(encoding="utf-8")
THREE = (Path(__file__).resolve().parent / "three_preview.js").read_text(encoding="utf-8")
PREVIEW = (Path(__file__).resolve().parent / "_preview_ws_server.py").read_text(encoding="utf-8")
NPC_EMPIRE = (Path(__file__).resolve().parent / "npc_empire.py").read_text(encoding="utf-8")
TUNNEL = (Path(__file__).resolve().parent / "start_with_tunnel.py").read_text(encoding="utf-8")


def run() -> None:
    assert "id='npcEmpireReadableUi'" in WORLD
    assert "КРИМИНАЛЬНАЯ СВОДКА" in WORLD
    assert "ДОМИНИРУЕТ В РАЙОНЕ" in WORLD
    assert "_npcEmpireDistricts.find" in WORLD and "runner_up_id" in WORLD
    assert 'class="dr-influence"' in WORLD and 'class="dr-rival"' in WORLD
    assert "currentDistrict=districtAt(player.r,player.c)" in WORLD
    assert "ui.classList.add('show');" in WORLD
    assert "_districtRepUi.classList.remove('show')" not in WORLD
    assert "/ищу сервер|подключ|недоступ|потеря|не отвеч|не запущ/i" in WORLD
    assert "void Promise.allSettled([loadMyWeapons(), loadInventoryItems()])" in WORLD
    assert "setTimeout(_installNpcEmpireFallbacks,0)" in WORLD
    assert "\n_installNpcEmpireFallbacks();\n" not in WORLD
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
    assert "_empirePlayerWar" in WORLD and "'playerWar'" in WORLD
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
    assert "overwhelming=force>=10" in WORLD and "assignmentWeight=role==='flanker'" in WORLD
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
    assert "3d391-gang-war-ballistics" in WORLD
    assert "_playerBuildingProperties=j.properties;_rebuildNpcEmpireFlagSites();" in WORLD
    assert "npc_empire_hospitalize" in PREVIEW and "hospital_until" in PREVIEW
    assert 'empire-card${inHospital?\' hospitalized\':\'\'}' in WORLD
    assert 'class="ns-hospital-mark"' in WORLD and 'class="ns-hospital-cross"' in WORLD
    assert "hospitalUntil=(+e.hospital_until||0)*1000" in WORLD
    assert "dataset.hospitalizedCount" in WORLD and "_hospitalTimer=setTimeout" in WORLD
    assert "uiMode==='dashboard')openNpcSandboxDashboard()" in WORLD
    assert "Boss dossier v4" in WORLD
    assert 'class="ne-photo-rank"' in WORLD and 'class="ne-photo-plaque"' in WORLD
    assert 'class="ne-family-seal"' in WORLD and "--ea" in WORLD
    assert "min-height:66px" in WORLD and "font-size:14px;line-height:1.25" in WORLD
    assert "ПЕРЕХВАЧЕННЫЙ ПЛАН · СВЕДЕНИЯ ИНФОРМАТОРА" in WORLD
    assert "ne-brain-board" in WORLD and "ne-brain-confidence" in WORLD
    assert "_npcEmpireReadableIntel" in WORLD and "держать позиции" in WORLD
    assert "_npcEmpireHoldingPresentation" in WORLD and "ВЛАДЕНИЯ СЕМЬИ" in WORLD
    assert 'class="ne-holding-grid"' in WORLD and 'class="ne-holdings-summary"' in WORLD
    assert "ДОНЕСЕНИЯ, ОТНОШЕНИЯ И ПРОШЛЫЕ РЕШЕНИЯ" in WORLD
    assert "ne-intel-details" in WORLD and "АРХИВ КРИМИНАЛЬНОЙ РАЗВЕДКИ · СЕКРЕТНО" in WORLD
    assert "empire.brain" in WORLD and "empire.memory" in WORLD
    assert "_boss_brain(" in PREVIEW and "['brain']" in PREVIEW
    assert '"doctrine": npc_empire.boss_doctrine' in PREVIEW
    assert "_empireSquadOrder" in WORLD and "EMPIRE_SQUAD_ORDER_MS=900" in WORLD
    assert "type==='withdraw'" in WORLD and "type==='regroup'" in WORLD
    assert "type==='focus'" in WORLD and "type==='flank'" in WORLD
    assert "dataset.empireSquadOrder" in WORLD and "now-order.announcedAt>5000" in WORLD
    assert "newOwnLosses" in WORLD and "newEnemyLosses" in WORLD and "setback>=4" in WORLD
    assert "setbackRecovery" in WORLD and "now-lastCasualtyAt>=5000" in WORLD
    assert "dataset.empireSquadSetback" in WORLD
    assert "ВЫУЧЕННЫЙ УРОК" in WORLD and "brain.adaptation" in WORLD
    assert "_boss_adaptation(" in NPC_EMPIRE and "'adaptation': adaptation" in NPC_EMPIRE
    assert "BOSS_DOCTRINES" in NPC_EMPIRE and "'doctrine': boss_doctrine" in NPC_EMPIRE
    assert "NPC_EMPIRE_DOCTRINES" in WORLD and "СТИЛЬ ·" in WORLD
    assert "NPC_EMPIRE_MINDSETS" in WORLD and "ТЕРПЕНИЕ ${Math.round" in WORLD
    assert "_empirePlayerSquadOrder" in WORLD and "dataset.empirePlayerOrder" in WORLD
    assert "_empirePlayerCombatThink" in WORLD and "_empireUseSignature" in WORLD
    assert "_npcEmpireAssaultAi" in WORLD and "dataset.empireAssaultPhase" in WORLD
    assert "_empireTacticalRole" in WORLD and "'commander'" in WORLD
    assert "'bodyguard'" in WORLD and "'marksman'" in WORLD
    assert "'flanker'" in WORLD and "'reserve'" in WORLD and "'assault'" in WORLD
    assert "bossThreat" in WORLD and "finisherBias" in WORLD
    assert "role==='reserve'" in WORLD and "role==='bodyguard'" in WORLD
    assert "role==='flanker'" in WORLD and "empireTacticalRole:String" in WORLD
    assert "offlineActivity={kind:'patrol'" in WORLD
    assert "_empireTarget=_empireActivityTarget({activity:npc._empireAction})" in WORLD
    assert "(?!api\\.)" in TUNNEL and "TUNNEL_ATTEMPTS = 3" in TUNNEL
    assert "wait_for_public_api(api_url)" in TUNNEL
    assert "cloudflare-dns.com/dns-query" in TUNNEL and "CREATE_NO_WINDOW" in TUNNEL
    assert "TUNNEL_HEALTH_INTERVAL = 30" in TUNNEL
    assert "Публичный туннель потерян" in TUNNEL and "os.execv(" in TUNNEL
    assert TUNNEL.index("wait_for_public_api(api_url)") < TUNNEL.index("publish_coop_api_json(api_url)", TUNNEL.index("def main"))
    print("npc_empire_ui: 3D cards, dossier, hospital state, attitudes, routes and hostility OK")


if __name__ == "__main__":
    run()
