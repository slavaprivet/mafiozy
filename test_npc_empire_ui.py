"""Static regression contract for the readable empire dashboard and dossier navigation."""

from pathlib import Path


WORLD = (Path(__file__).resolve().parent / "world.html").read_text(encoding="utf-8")
THREE = (Path(__file__).resolve().parent / "three_preview.js").read_text(encoding="utf-8")
PREVIEW = (Path(__file__).resolve().parent / "_preview_ws_server.py").read_text(encoding="utf-8")


def run() -> None:
    assert "id='npcEmpireReadableUi'" in WORLD
    assert "font-size:14px" in WORLD
    assert "font-size:15px;line-height:1.55" in WORLD
    assert 'class="ne-rank-grid"' in WORLD
    assert 'data-ne-portrait=' in WORLD
    assert "← К СПИСКУ БОССОВ" in WORLD
    assert "ov.querySelector('.ne-x')?.remove()" in WORLD
    assert "ov.dataset.locked='1'" in WORLD
    assert "back.onclick=openNpcSandboxDashboard" in WORLD
    assert "_npcEmpireAttitude" in WORLD and "НЕГАТИВНО" in WORLD and "ПОЛОЖИТЕЛЬНО" in WORLD
    assert "data-ne-declare-war" in WORLD and "НУЖНО НИЖЕ 0" in WORLD
    assert "data-ne-extra=\"apologize\"" in WORLD and "data-ne-extra=\"compensation\"" in WORLD
    assert "_empirePlayerWar" in WORLD and "Мы с тобой воюем!" in WORLD
    assert "activity.target_r" in WORLD and "empireBossMotion" in WORLD
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
    assert '"kind": "gang_war"' in PREVIEW and '"pact": "war"' in PREVIEW
    assert "_UP.has('previewempirewar')" in WORLD
    assert "leftStage=_nearestEmpireWalkPoint(player.r-4" in WORLD
    assert "const empireHqs=inside?[]:_npcEmpires.filter" in WORLD
    assert "EMPIRE_HQ_CAP=19" in THREE and "server-owned-ring-flag-gang-label-v357" in THREE
    assert "src.empireBoss||src.empireCrew" in THREE and "empireMember=empireBoss||empireCrew" in THREE
    print("npc_empire_ui: 3D cards, dossier, empire plaque, attitudes, routes and hostility OK")


if __name__ == "__main__":
    run()
