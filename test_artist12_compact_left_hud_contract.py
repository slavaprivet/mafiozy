"""Focused contract for Artist12's content-preserving compact left HUD."""

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")
MEDIA_QUERY = (
    "@media (min-width:681px) and (max-width:1440px), "
    "(min-width:681px) and (max-height:820px)"
)


def _compact_css() -> str:
    assert WORLD.count(MEDIA_QUERY) == 1
    tail = WORLD.split(MEDIA_QUERY, 1)[1]
    css, sentinel, _ = tail.partition("#policeModal")
    assert sentinel, "compact rule must remain directly before #policeModal"
    return css


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


def test_compact_rule_follows_the_final_cinematic_mobile_cascade() -> None:
    compact_at = WORLD.index(MEDIA_QUERY)
    assert compact_at > WORLD.index("/* Cinematic polish pass:")
    assert compact_at > WORLD.rindex("@media(max-width:680px){#leftCommandHud")
    between = WORLD[compact_at:WORLD.index("#policeModal", compact_at)]
    assert between.rstrip().endswith("}")


def test_compact_rule_preserves_content_while_reclaiming_screen_space() -> None:
    css = _compact_css()
    expected = (
        "#leftCommandHud{width:244px;padding:6px;gap:5px}",
        "#leftCommandHud #btnHome,#leftCommandHud #btnNews{height:33px;line-height:31px}",
        "#leftCommandHud #hudPlayer{padding:7px;gap:8px}",
        "#leftCommandHud #hudPlayer .hud-ava{width:58px;height:58px}",
        "#leftCommandHud #hudPlayer #hudAvatar{width:54px;height:54px}",
        "#leftCommandHud #modeHud,#leftCommandHud #missionHudBtn{min-height:32px}",
        "#leftCommandHud #gangRosterHud,#leftCommandHud #jobStatusHud{padding:7px 8px}",
    )
    for declaration in expected:
        assert declaration in css
    for forbidden in ("display", "visibility", "order", "overflow", "max-height", "transform"):
        assert not re.search(rf"(?:^|[;{{])\s*{forbidden}\s*:", css)


def test_breakpoint_truth_table_has_no_desktop_or_mobile_regression() -> None:
    def compact(width: int, height: int) -> bool:
        return width >= 681 and (width <= 1440 or height <= 820)

    assert not compact(680, 820)  # existing mobile cascade owns this viewport
    assert compact(681, 821)
    assert compact(1280, 720)
    assert compact(1366, 768)
    assert compact(1440, 821)
    assert compact(1441, 820)
    assert not compact(1441, 821)
    assert not compact(1920, 1080)


def test_authoritative_hud_nodes_keep_their_single_mount_order() -> None:
    match = re.search(
        r"function mountLeftCommandHud\(\)\{(?P<body>.*?)\n\}", WORLD, re.S
    )
    assert match, "left HUD mount function is missing"
    body = match.group("body")
    assert (
        "['btnHome','btnNews','hudPlayer','modeHud','missionHudBtn',"
        "'gangRosterHud','jobStatusHud']"
    ) in body
    assert "if(node)dock.appendChild(node);" in body
    assert "_mountNpcSandboxButton();" in body
    for node_id in (
        "leftCommandHud", "btnHome", "btnNews", "hudPlayer", "modeHud",
        "missionHudBtn", "gangRosterHud", "jobStatusHud",
    ):
        assert len(re.findall(rf'id=["\']{node_id}["\']', WORLD)) == 1


def test_current_renderer_query_families_are_preserved_semantically() -> None:
    query = _module_query()
    required_keys = {
        "v", "opt", "facade", "building", "building2", "building3",
        "npcgear", "brick", "material", "visual", "road", "lighting",
        "melee", "interior",
    }
    assert required_keys <= query.keys()
    opt_tokens = query["opt"].split("+")
    assert any(re.fullmatch(r"building-reveal-v\d+", token) for token in opt_tokens)
    for family in (
        "burning-pool-v", "pooled-marker-accounting-v", "junkyard-light-budget-v",
        "bridge-hangers-v", "vehicle-admission-v",
    ):
        assert any(token.startswith(family) for token in opt_tokens)
    assert re.fullmatch(r"smart-heavy-forward-kick-v\d+", query["melee"])
    assert re.fullmatch(r"business-red-material-v\d+", query["interior"])


if __name__ == "__main__":
    test_compact_rule_follows_the_final_cinematic_mobile_cascade()
    test_compact_rule_preserves_content_while_reclaiming_screen_space()
    test_breakpoint_truth_table_has_no_desktop_or_mobile_regression()
    test_authoritative_hud_nodes_keep_their_single_mount_order()
    test_current_renderer_query_families_are_preserved_semantically()
    print("artist12 compact left HUD contract: ok")
