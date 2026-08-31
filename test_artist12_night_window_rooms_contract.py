"""Focused contract for coherent, zero-resource ordinary-building night windows."""

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")


FAMILY_GRIDS = {
    "glass": (56, 48),
    "brick": (56, 48),
    "limestone": (64, 56),
    "concrete": (64, 64),
    "deco": (64, 48),
    "industrial": (72, 56),
}


def _module_query() -> dict[str, str]:
    sources = re.findall(
        r'<script\s+type="module"\s+src="(three_preview\.js\?[^\"]+)"\s*></script>',
        WORLD,
    )
    assert len(sources) == 1, "exactly one Three.js module entry is required"
    pairs = [part.split("=", 1) for part in sources[0].split("?", 1)[1].split("&")]
    assert all(len(pair) == 2 and pair[0] and pair[1] for pair in pairs)
    keys = [pair[0] for pair in pairs]
    assert len(keys) == len(set(keys)), "module query keys must remain unique"
    return dict(pairs)


def _is_lit(ix: int, floor: int, seed: int) -> bool:
    room = ix // 2
    return ((room * 17 + floor * 31 + seed * 13) % 9) < 3


def test_facade_mask_groups_neighboring_windows_by_room_and_floor() -> None:
    expected = (
        "const room=Math.floor(ix/2),floor=iy,"
        "lit=((room*17+floor*31+seed*13)%9)<3"
    )
    assert THREE.count(expected) == 1
    assert "const lit=((ix*17+iy*31+seed*13)%9)<3" not in THREE
    assert (
        "renderer.domElement.dataset.buildingWindowLighting="
        "'room-pair-floor-seeded-circadian-v1';"
    ) in THREE


def test_every_family_has_paired_rooms_dark_floors_and_bounded_coverage() -> None:
    for family, (step_x, step_y) in FAMILY_GRIDS.items():
        columns = len(range(20, 488, step_x))
        floors = len(range(24, 488, step_y))
        for seed in (0, 1):
            states = [
                _is_lit(ix, floor, seed)
                for floor in range(floors)
                for ix in range(columns)
            ]
            for floor in range(floors):
                for ix in range(0, columns - 1, 2):
                    assert _is_lit(ix, floor, seed) == _is_lit(ix + 1, floor, seed), (
                        family,
                        seed,
                        floor,
                        ix,
                    )
            assert any(
                not any(_is_lit(ix, floor, seed) for ix in range(columns))
                for floor in range(floors)
            ), (family, seed, "missing coherent dark floor")
            coverage = sum(states) / len(states)
            assert 0.30 <= coverage <= 0.38, (family, seed, coverage)


def test_facade_resources_and_circadian_update_remain_unchanged() -> None:
    texture_build = (
        "for(const family of architectureFamilies){const variants=[];"
        "for(let variant=0;variant<2;variant++){const tx=facadeTexture(family,variant);"
        "variants.push(tx);facades.push(tx);}architectureFacadeTextures.set(family.id,variants);}"
    )
    assert texture_build in THREE
    assert len(FAMILY_GRIDS) * 2 == 12
    assert "cv.width = cv.height = 1536" in THREE
    assert "tx.generateMipmaps = true" in THREE
    assert "tx.minFilter = THREE.LinearMipmapLinearFilter" in THREE
    assert "tx.anisotropy = Math.min(16,renderer.capabilities.getMaxAnisotropy())" in THREE
    assert "FACADE_GRADE_BATCH=32,SHOP_GRADE_BATCH=18" in THREE
    assert (
        "m.emissiveIntensity=THREE.MathUtils.lerp("
        "m.userData.mfzFacadeNightEmissive??.42,"
        "m.userData.mfzFacadeDayEmissive??.04,daylight);"
    ) in THREE
    assert "buildingMaterialBudget='meshes:0,geometries:0,textures:0,draws:0,lights:0,programs:1,frame-allocations:0'" in THREE
    assert THREE.count("buildingWindowLighting") == 1


def test_renderer_query_preserves_current_families_semantically() -> None:
    query = _module_query()
    required_keys = {
        "v", "opt", "facade", "building", "building2", "building3",
        "npcgear", "brick", "material", "visual", "road", "lighting",
        "melee", "interior", "npcstate", "storeglow", "windows",
    }
    assert required_keys <= query.keys()
    assert query["windows"] == "room-pair-floor-circadian-v1"
    assert query["storeglow"] == "signed-circadian-v1"
    assert query["npcstate"] == "npc-state-prune-v429"
    assert any(
        re.fullmatch(r"building-reveal-v\d+", token)
        for token in query["opt"].split("+")
    )
    assert re.fullmatch(r"smart-heavy-forward-kick-v\d+", query["melee"])
    assert re.fullmatch(r"business-red-material-v\d+", query["interior"])


if __name__ == "__main__":
    test_facade_mask_groups_neighboring_windows_by_room_and_floor()
    test_every_family_has_paired_rooms_dark_floors_and_bounded_coverage()
    test_facade_resources_and_circadian_update_remain_unchanged()
    test_renderer_query_preserves_current_families_semantically()
    print("artist12 night-window room contract: ok")
