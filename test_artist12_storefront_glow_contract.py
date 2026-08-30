"""Focused contract for signed-only, circadian storefront glow."""

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")
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


def _shop_plane_statement() -> str:
    match = re.search(
        r"if\(sign&&![^\n]+?shopMaterials\.push\(shopGlow\);[^\n]+?scene\.add\(shop\);\}",
        THREE,
    )
    assert match, "signed storefront plane statement is missing"
    return match.group(0)


def test_shop_plane_requires_an_authored_sign_and_excludes_blackmarket() -> None:
    statement = _shop_plane_statement()
    assert statement.startswith(
        "if(sign&&!String(architecturalKind||'').startsWith('blackmarket'))"
    )
    assert "new THREE.MeshBasicMaterial" in statement
    assert "new THREE.PlaneGeometry(Math.min(w-2,8),2.8)" in statement
    assert statement.count("shopMaterials.push(shopGlow)") == 1
    assert statement.count("scene.add(shop)") == 1
    assert "if(!String(architecturalKind||'').startsWith('blackmarket'))" not in THREE


def test_existing_glow_material_can_follow_circadian_opacity() -> None:
    statement = _shop_plane_statement()
    material = re.search(
        r"new THREE\.MeshBasicMaterial\(\{(?P<body>.*?)\}\)", statement
    )
    assert material
    options = material.group("body")
    assert "transparent:true" in options
    assert "opacity:.74" in options
    assert "depthWrite:false" in options
    assert "sign==='CLUB'?0xff397d" in options
    assert "sign==='CAFE'?0xffa13b:0xffd38a" in options
    assert (
        "m.opacity=(.74+night*.26)*pulse*fault;" in THREE
    ), "existing day/night opacity grading must remain authoritative"
    assert re.search(r"\bSHOP_GRADE_BATCH=18\b", THREE)
    assert (
        "renderer.domElement.dataset.genericStorefrontGlow="
        "'signed-only-circadian-opacity-v1';"
    ) in THREE


def test_no_parallel_storefront_resource_or_update_path_was_added() -> None:
    assert THREE.count("const shopGlow=new THREE.MeshBasicMaterial") == 1
    assert THREE.count("shopMaterials.push(shopGlow)") == 1
    assert THREE.count("const shopCount=Math.min(SHOP_GRADE_BATCH,shopMaterials.length)") == 1
    assert THREE.count("genericStorefrontGlow") == 1
    assert "PointLight" not in _shop_plane_statement()


def test_renderer_query_preserves_current_families_semantically() -> None:
    query = _module_query()
    required_keys = {
        "v", "opt", "facade", "building", "building2", "building3",
        "npcgear", "brick", "material", "visual", "road", "lighting",
        "melee", "interior", "npcstate", "storeglow",
    }
    assert required_keys <= query.keys()
    assert query["storeglow"] == "signed-circadian-v1"
    assert query["npcstate"] == "npc-state-prune-v429"
    assert any(
        re.fullmatch(r"building-reveal-v\d+", token)
        for token in query["opt"].split("+")
    )
    assert re.fullmatch(r"smart-heavy-forward-kick-v\d+", query["melee"])
    assert re.fullmatch(r"business-red-material-v\d+", query["interior"])


if __name__ == "__main__":
    test_shop_plane_requires_an_authored_sign_and_excludes_blackmarket()
    test_existing_glow_material_can_follow_circadian_opacity()
    test_no_parallel_storefront_resource_or_update_path_was_added()
    test_renderer_query_preserves_current_families_semantically()
    print("artist12 storefront glow contract: ok")
