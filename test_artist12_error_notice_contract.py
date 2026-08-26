"""Focused contract for Artist12's compact, non-blocking error notice."""

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")


def _error_banner_css() -> str:
    match = re.search(r"#errorBanner\s*\{(?P<body>.*?)\}", WORLD, re.S)
    assert match, "#errorBanner CSS block is missing"
    return match.group("body")


def _module_query() -> dict[str, str]:
    sources = re.findall(
        r'<script\s+type="module"\s+src="(three_preview\.js\?[^\"]+)"\s*></script>',
        WORLD,
    )
    assert len(sources) == 1, "exactly one Three.js module entry is required"
    parts = sources[0].split("?", 1)[1].split("&")
    pairs = [part.split("=", 1) for part in parts]
    assert all(len(pair) == 2 and pair[0] and pair[1] for pair in pairs)
    keys = [pair[0] for pair in pairs]
    assert len(keys) == len(set(keys)), "module query keys must be unique"
    return dict(pairs)


def test_notice_is_bounded_to_the_safe_top_right_corner() -> None:
    css = _error_banner_css()
    assert "right: max(14px, env(safe-area-inset-right, 0px))" in css
    assert "top: max(60px, calc(env(safe-area-inset-top, 0px) + 52px))" in css
    assert "width: min(360px, calc(100vw - 28px))" in css
    assert "max-width: calc(100vw - 28px)" in css
    assert "text-align: left" in css
    assert "overflow-wrap: anywhere" in css
    assert "pointer-events: none" in css
    assert "display: none" in css
    assert not re.search(r"(?:^|;)\s*left\s*:", css)


def test_notice_is_accessible_without_changing_error_behavior() -> None:
    assert (
        '<div id="errorBanner" role="status" aria-live="polite" '
        'aria-atomic="true"></div>'
    ) in WORLD
    match = re.search(
        r"function setError\(msg\)\s*\{(?P<body>.*?)\n\}\nfunction setConnecting",
        WORLD,
        re.S,
    )
    assert match, "setError function boundary is missing"
    body = match.group("body")
    assert "if (msg) { el.textContent = msg; el.style.display = 'block'; }" in body
    assert "else el.style.display = 'none';" in body
    for forbidden in ("setTimeout", "innerHTML", ".remove("):
        assert forbidden not in body


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
    test_notice_is_bounded_to_the_safe_top_right_corner()
    test_notice_is_accessible_without_changing_error_behavior()
    test_current_renderer_query_families_are_preserved_semantically()
    print("artist12 error notice contract: ok")
