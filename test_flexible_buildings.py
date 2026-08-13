"""Regression contract for selectable generic-building purposes.

Run directly with ``python test_flexible_buildings.py``.  The checks are kept
dependency-free so the publication workflow can execute them on every update.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")
BOT = (ROOT / "mafiozi_bot.py").read_text(encoding="utf-8")
EMPIRE = (ROOT / "npc_empire.py").read_text(encoding="utf-8")

OPERATIONS = {
    "beer_bar",
    "pawnshop",
    "bookmaker",
    "strip_club",
    "gun_shop",
    "chop_shop",
    "poker_club",
    "print_shop",
}


def test_all_operation_types_cross_the_server_and_render_contract() -> None:
    for operation in OPERATIONS:
        assert f"{operation}:{{name:" in WORLD
        assert operation in THREE
        assert operation in BOT or operation in EMPIRE


def test_npc_and_player_buildings_share_the_interior_purpose_resolver() -> None:
    resolver = WORLD[WORLD.index("function _buildingPropertyAt"):WORLD.index("function drawOwnedApartmentWorldMarkers")]
    assert "_playerBuildingProperties" in resolver
    assert "for(const empire of (_npcEmpires||[]))" in resolver
    assert "npc_owned:true" in resolver
    assert "property_kind:isHq?'hq':'business'" in resolver
    assert "operation_type" in resolver


def test_visual_qa_fixture_is_local_only_and_covers_npc_owners() -> None:
    fixture = WORLD[WORLD.index("previewEnterBuildingPurpose"):WORLD.index("previewApproachMajor")]
    assert "if(!_LOCAL_PREVIEW)" in fixture
    assert "ownerKind==='npc'" in fixture
    assert "previewClearBuildingPurpose" in fixture
    assert "buildingPurposeFixture" in fixture


def test_facades_stay_bounded_and_have_mounted_signage() -> None:
    assert "const EMPIRE_FLAG_CAP=64" in THREE
    assert "facadeSign=new THREE.Mesh" in THREE
    assert "map:texture" in THREE
    assert "profileMeshes.beer_bar" in THREE
    assert "profileMeshes.print_shop" in THREE


def test_converted_interiors_have_current_design_profile() -> None:
    assert "purpose-v2:${kind}:${operation||'headquarters'}" in THREE
    assert "visible hydraulic lift" in THREE
    assert "TorusGeometry(1.25,.16,10,32)" in THREE
    assert "neonArch" in THREE
    assert "Public entrance treatment" in THREE
    assert "purpose-v2:${Math.round(now/1000)}" in WORLD


if __name__ == "__main__":
    tests = [value for name, value in sorted(globals().items()) if name.startswith("test_")]
    for test in tests:
        test()
    print(f"flexible building contract: {len(tests)} checks passed")
