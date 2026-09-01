"""Focused contract for family-specific ordinary-building roof response."""

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")


EXPECTED = {
    "glass": (0.22, 0.38, 1.10),
    "brick": (0.88, 0.04, 0.18),
    "limestone": (0.72, 0.08, 0.30),
    "concrete": (0.82, 0.12, 0.25),
    "deco": (0.38, 0.48, 0.78),
    "industrial": (0.62, 0.55, 0.52),
}


def _module_query() -> dict[str, str]:
    sources = re.findall(
        r'<script\s+type="module"\s+src="(three_preview\.js\?[^\"]+)"\s*></script>',
        WORLD,
    )
    assert len(sources) == 1
    pairs = [part.split("=", 1) for part in sources[0].split("?", 1)[1].split("&")]
    assert all(len(pair) == 2 and pair[0] and pair[1] for pair in pairs)
    keys = [pair[0] for pair in pairs]
    assert len(keys) == len(set(keys))
    return dict(pairs)


def _family_entry(family: str) -> str:
    match = re.search(r"\{id:'" + re.escape(family) + r"',(?P<body>[^\n]+)\}", THREE)
    assert match, family
    return match.group("body")


def _number(entry: str, key: str) -> float:
    match = re.search(rf"(?:^|,){re.escape(key)}:(?P<value>\d+(?:\.\d+)?|\.\d+)", entry)
    assert match, (key, entry)
    return float(match.group("value"))


def test_six_families_have_distinct_bounded_roof_response() -> None:
    observed = {}
    for family, expected in EXPECTED.items():
        entry = _family_entry(family)
        values = (
            _number(entry, "roofRoughness"),
            _number(entry, "roofMetalness"),
            _number(entry, "roofEnv"),
        )
        assert values == expected, (family, values)
        assert 0.18 <= values[0] <= 0.90
        assert 0.0 <= values[1] <= 0.60
        assert 0.15 <= values[2] <= 1.10
        observed[family] = values
    assert len(set(observed.values())) == 6
    assert observed["brick"][0] > observed["glass"][0]
    assert observed["brick"][1] < observed["industrial"][1]
    assert observed["deco"][2] > observed["concrete"][2]


def test_existing_roof_clone_receives_only_family_scalars() -> None:
    statement = (
        "const localRoof=roofMat.clone();"
        "localRoof.color.setHex(architectureFamily.roof);"
        "localRoof.roughness=architectureFamily.roofRoughness;"
        "localRoof.metalness=architectureFamily.roofMetalness;"
        "localRoof.envMapIntensity=architectureFamily.roofEnv;"
        "localRoof.userData.mfzOcclusionOpacity=.28;"
    )
    assert THREE.count(statement) == 1
    assert "const roofMat = new THREE.MeshStandardMaterial({color:0x41515d,map:roofTexture" in THREE
    assert "roughnessMap:roofTexture" in THREE
    assert "envMap:cityEnvironment" in THREE
    assert "roofMat.clone()" in statement
    assert "new THREE." not in statement
    assert (
        "renderer.domElement.dataset.buildingRoofMaterialResponse="
        "'glass-reflective|brick-matte|limestone-stone|concrete-matte|"
        "deco-satin|industrial-weathered-metal-v1';"
    ) in THREE


def test_roof_shapes_resources_and_stream_lifecycle_are_preserved() -> None:
    assert "buildingRoofProfiles='glass:terraced,brick:hipped,limestone:classical,concrete:mechanical,deco:tiered,industrial:sawtooth'" in THREE
    assert "addRoofDetails(x,z,w,d,h,roofVariant,architectureFamily.id)" in THREE
    assert "mainBuilding.userData.fadeMaterials=[wall,localRoof]" in THREE
    assert (
        "if(object.geometry&&!persistentStreamResources.has(object.geometry)"
        "&&!object.geometry.userData?.mfzPersistent)geometries.add(object.geometry);"
    ) in THREE
    assert "buildingMaterialBudget='meshes:0,geometries:0,textures:0,draws:0,lights:0,programs:1,frame-allocations:0'" in THREE
    assert "buildingFacadeTextures='source:12,clones:stream-bounded'" in THREE
    assert THREE.count("buildingRoofMaterialResponse") == 1


def test_renderer_query_preserves_current_families_semantically() -> None:
    query = _module_query()
    required_keys = {
        "v", "opt", "facade", "building", "building2", "building3",
        "npcgear", "brick", "material", "visual", "road", "lighting",
        "melee", "interior", "npcstate", "storeglow", "windows", "roofmat",
    }
    assert required_keys <= query.keys()
    assert query["roofmat"] == "family-physical-response-v1"
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
    test_six_families_have_distinct_bounded_roof_response()
    test_existing_roof_clone_receives_only_family_scalars()
    test_roof_shapes_resources_and_stream_lifecycle_are_preserved()
    test_renderer_query_preserves_current_families_semantically()
    print("artist12 roof material response contract: ok")
