"""Bounded 3D label declutter contracts for dense interior raids."""

from pathlib import Path


ROOT = Path(__file__).resolve().parent


def layout(labels, offsets=(0, 1.15, -1.15, 2.3, -2.3)):
    """Small deterministic mirror of the production priority layout."""
    placed, hidden = [], []
    for item in sorted(labels, key=lambda row: (-row['priority'], row.get('distance', 0))):
        candidates = offsets if item['priority'] >= 80 else offsets[:1]
        for lane in candidates:
            # Orthographic projection turns the production world-space lane
            # offset into roughly this many pixels at the gameplay zoom.
            y = item['y'] - lane * 36
            if not any(abs(item['x'] - old['x']) < 80 and
                       abs(y - old['y']) < 30 for old in placed):
                placed.append({**item, 'y': y, 'lane': lane})
                break
        else:
            if item['priority'] >= 120:
                placed.append({**item, 'y': item['y'], 'lane': 'forced'})
                continue
            hidden.append(item)
    return placed, hidden


def main():
    world = (ROOT / 'world.html').read_text(encoding='utf-8')
    three = (ROOT / 'three_preview.js').read_text(encoding='utf-8')
    memory = (ROOT / 'docs' / 'ai' / 'OPTIMIZATION_MEMORY.md').read_text(
        encoding='utf-8')

    dense = [
        {'id': 'target', 'x': 100, 'y': 100, 'priority': 120},
        {'id': 'live-hp', 'x': 102, 'y': 101, 'priority': 88},
        {'id': 'corpse-a', 'x': 101, 'y': 100, 'priority': 10},
        {'id': 'corpse-b', 'x': 104, 'y': 102, 'priority': 10},
        {'id': 'corpse-c', 'x': 106, 'y': 104, 'priority': 10},
    ]
    placed, hidden = layout(dense)
    assert {'target', 'live-hp'} <= {item['id'] for item in placed}
    assert {item['id'] for item in hidden} == {
        'corpse-a', 'corpse-b', 'corpse-c'}
    assert len(placed) <= len(dense)

    bosses = [
        {'id': f'boss-{i}', 'x': 200, 'y': 180, 'priority': 100,
         'distance': i + 1}
        for i in range(8)
    ]
    placed, hidden = layout(bosses)
    assert [item['id'] for item in placed] == [f'boss-{i}' for i in range(5)]
    assert [item['id'] for item in hidden] == [f'boss-{i}' for i in range(5, 8)]

    focused = {'id': 'focused', 'x': 200, 'y': 180, 'priority': 120,
               'distance': 9}
    placed, hidden = layout([*bosses[:7], focused])
    assert 'focused' in {item['id'] for item in placed}
    assert len(placed) == 5
    assert len(hidden) == 3

    assert 'const npcLabelLayoutCandidates=[]' in three
    assert 'npcLabelLaneOffsets=[0,1.15,-1.15,2.3,-2.3]' in three
    assert 'entry.layoutDistanceSq=dx*dx+dz*dz' in three
    assert 'b.layoutPriority-a.layoutPriority||a.layoutDistanceSq-b.layoutDistanceSq' in three
    assert 'mustKeep=entry.layoutPriority>=120' in three
    assert 'if(!placed&&!mustKeep){entry.sprite.visible=false' in three
    assert 'if(!placed&&!important){entry.sprite.visible=false' not in three
    assert 'deathAge<2600' in three
    assert '(2600-deathAge)/900' in three
    assert "raidCombat?88" in three
    assert 'dataset.npcLabelDeclutter=' in three

    # Raid family identity must travel on every actor into the shared Three
    # bridge; renderer labels, aura and band then consume the same fields.
    assert 'raidFamilyColor:side===\'attacker\'' in world
    assert 'raidFamilyAccent:side===\'attacker\'' in world
    assert 'bossColor:String(n.raidFamilyColor||\'\')' in world
    assert 'bossAccent:String(n.raidFamilyAccent||\'\')' in world
    assert 'family:String(n.raidFamilyName||\'\')' in world

    # HUD nodes are created once and text changes only when its stable
    # signature changes; long venue/owner strings are clipped by CSS.
    assert "hud.innerHTML='<b></b><strong></strong><div></div><small></small>'" in world
    assert 'max-width:calc(100vw - 24px)' in world
    assert 'text-overflow:ellipsis' in world
    assert 'if(hud.dataset.sig!==sig)' in world
    assert "hud.style.display='block'" in world
    assert 'priority declutter' in memory
    print('interior raid labels: priority declutter, fade, family colors, bounded HUD OK')


if __name__ == '__main__':
    main()
