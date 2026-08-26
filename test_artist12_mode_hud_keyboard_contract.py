"""Focused contract for Artist12's native keyboard-accessible mode control."""

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")


def _module_query() -> dict[str, str]:
    sources = re.findall(
        r'<script\s+type="module"\s+src="(three_preview\.js\?[^\"]+)"\s*></script>',
        WORLD,
    )
    assert len(sources) == 1, "exactly one Three.js module entry is required"
    pairs = [part.split("=", 1) for part in sources[0].split("?", 1)[1].split("&")]
    assert all(len(pair) == 2 and pair[0] and pair[1] for pair in pairs)
    keys = [pair[0] for pair in pairs]
    assert len(keys) == len(set(keys)), "module query keys must be unique"
    return dict(pairs)


def test_mode_control_is_one_native_non_submitting_button() -> None:
    expected = (
        '<button id="modeHud" type="button" title="Сменить режим">'
        '🔫 PvP <span class="sw">сменить</span></button>'
    )
    assert WORLD.count(expected) == 1
    assert '<div id="modeHud"' not in WORLD
    assert len(re.findall(r'id=["\']modeHud["\']', WORLD)) == 1
    assert 'role="button"' not in expected
    assert 'tabindex=' not in expected


def test_mode_control_has_a_visible_keyboard_focus_indicator() -> None:
    match = re.search(r"#modeHud:focus-visible\s*\{(?P<body>.*?)\}", WORLD, re.S)
    assert match, "modeHud focus-visible rule is missing"
    css = match.group("body")
    assert "outline: 2px solid #ffe1a0" in css
    assert "outline-offset: 2px" in css
    assert "outline: none" not in css


def test_native_activation_reuses_the_existing_click_flow_exactly_once() -> None:
    assert WORLD.count(
        "_modeHudEl.addEventListener('click', () => switchModeFlow());"
    ) == 1
    assert "_modeHudEl.addEventListener('keydown'" not in WORLD
    switch = re.search(
        r"function switchModeFlow\(\)\s*\{(?P<body>.*?)\n\}", WORLD, re.S
    )
    assert switch, "switchModeFlow boundary is missing"
    body = switch.group("body")
    assert "next.searchParams.delete('mode');" in body
    assert "location.replace(next.toString());" in body
    assert "event" not in body and "preventDefault" not in body


def test_refresh_and_authoritative_mount_order_are_preserved() -> None:
    refresh = re.search(
        r"function _refreshModeHud\(\)\s*\{(?P<body>.*?)\n\}", WORLD, re.S
    )
    assert refresh, "mode HUD refresh function is missing"
    body = refresh.group("body")
    assert "🕵 PvE <span class=\"sw\">сменить</span>" in body
    assert "🔫 PvP <span class=\"sw\">сменить</span>" in body
    assert "classList.remove('pvp')" in body
    assert "classList.add('pve')" in body
    assert "classList.remove('pve')" in body
    assert "classList.add('pvp')" in body

    mount = re.search(
        r"function mountLeftCommandHud\(\)\{(?P<body>.*?)\n\}", WORLD, re.S
    )
    assert mount, "left HUD mount function is missing"
    assert (
        "['btnHome','btnNews','hudPlayer','modeHud','missionHudBtn',"
        "'gangRosterHud','jobStatusHud']"
    ) in mount.group("body")
    assert "if(node)dock.appendChild(node);" in mount.group("body")
    assert "_mountNpcSandboxButton();" in mount.group("body")


def test_current_hud_authority_and_renderer_contracts_remain_present() -> None:
    assert "@media (min-width:681px) and (max-width:1440px)" in WORLD
    assert '<div id="errorBanner" role="status" aria-live="polite"' in WORLD
    for marker in (
        "function _selectedBusinessAuthorityDossier(bizId)",
        "_businessOwnerAuthorityReady=false",
        "_businessFamilyAuthorityReady=false",
        "previewOpenBusinessAuthority(ownerKind='missing'",
    ):
        assert marker in WORLD

    query = _module_query()
    required_keys = {
        "v", "opt", "facade", "building", "building2", "building3",
        "npcgear", "brick", "material", "visual", "road", "lighting",
        "melee", "interior", "npcstate",
    }
    assert required_keys <= query.keys()
    assert query["npcstate"] == "npc-state-prune-v429"
    assert any(
        re.fullmatch(r"building-reveal-v\d+", token)
        for token in query["opt"].split("+")
    )
    assert re.fullmatch(r"smart-heavy-forward-kick-v\d+", query["melee"])
    assert re.fullmatch(r"business-red-material-v\d+", query["interior"])


if __name__ == "__main__":
    test_mode_control_is_one_native_non_submitting_button()
    test_mode_control_has_a_visible_keyboard_focus_indicator()
    test_native_activation_reuses_the_existing_click_flow_exactly_once()
    test_refresh_and_authoritative_mount_order_are_preserved()
    test_current_hud_authority_and_renderer_contracts_remain_present()
    print("artist12 mode HUD keyboard contract: ok")
