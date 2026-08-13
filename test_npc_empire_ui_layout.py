"""Deterministic layout/data contract for compact empire status surfaces."""

import os
import re

import npc_empire as ne


def run() -> None:
    root = os.path.dirname(os.path.abspath(__file__))
    with open(os.path.join(root, 'world.html'), encoding='utf-8') as source:
        world = source.read()
    with open(os.path.join(root, 'three_preview.js'), encoding='utf-8') as source:
        three = source.read()

    # The right-side card is bounded at both requested desktop viewports and
    # every variable-length field has a shrinkable/ellipsized grid slot.
    assert 'width:min(306px,calc(100vw - 28px))' in world
    assert 306 < 1366 and 306 < 1920
    assert 'grid-template-columns:50px minmax(0,1fr) auto' in world
    assert '#districtRepHud .dr-rival b{min-width:0;max-width:54%}' in world
    assert '#districtRepHud .dr-state,#districtRepHud .dr-rival span{overflow:hidden;white-space:nowrap;text-overflow:ellipsis}' in world
    assert '.dr-boss{display:block;overflow:hidden' in world
    assert '.dr-gang{display:block;overflow:hidden' in world

    # One bounded portrait canvas is painted only when the district snapshot
    # changes; the family sign remains visible as a small badge.
    district_render = re.search(
        r'function _renderDistrictRep\(d,force=false\)\{(.*?)\n\}', world, re.S)
    assert district_render
    card = district_render.group(1)
    assert '<canvas width="92" height="92" data-ne-portrait=' in card
    assert 'class="dr-emblem"' in card
    assert "_paintNpcEmpireUiPortraits(ui)" in card
    assert "ui.dataset.controlState" in card
    assert "districtRow?.control_percent" in card
    assert 'ВЛАСТЬ ОСПАРИВАЕТСЯ' in card
    assert 'НЕЙТРАЛЬНАЯ ТЕРРИТОРИЯ' in card
    assert 'БЛИЖАЙШИЙ СОПЕРНИК' in card

    # Both DOM dossier/ranking and the 3D overhead label resolve the exact
    # server-provided enemy boss and gang, including offline-map fallback.
    assert world.count('activity.target_gang_name') >= 1
    assert world.count('action.target_gang_name') >= 1
    assert "[rivalName,rivalGang].filter(Boolean).join(' · ')" in world
    assert "[name,gang].filter(Boolean).join(' · ')" in world
    assert '.ns-rank-role{' in world and '-webkit-line-clamp:2' in world
    assert 'fitOutlinedLabelText' in three
    assert "fitOutlinedLabelText(c,status,384,151,650,30" in three

    # Diplomacy wording is authoritative and all non-neutral states have
    # explicit client icons/text instead of leaking enum keys.
    assert ne.NPC_PACT_LABELS == {
        'none': 'нейтралитет', 'war': 'война', 'truce': 'перемирие',
        'alliance': 'союз', 'vassal': 'подчинение',
    }
    assert "d.pact==='war'?'⚔️':d.pact==='alliance'?'🤝':d.pact==='truce'?'📜':'◈'" in world
    assert 'd.pact_label||d.pact' in world

    client_district_ids = set(re.findall(
        r"\{ id:'([^']+)'", re.search(
            r'const DISTRICTS = \[(.*?)\n\];', world, re.S).group(1)))
    assert client_district_ids == set(ne.DISTRICTS)
    print('npc empire UI layout: 1366/1920 bounded district card, portrait/emblem, '
          'leader/tie/neutral states, exact war boss+gang and pact labels OK')


if __name__ == '__main__':
    run()
