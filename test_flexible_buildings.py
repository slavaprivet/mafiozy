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


def test_ownership_preserves_full_building_geometry_and_changes_only_skin() -> None:
    assert "const EMPIRE_FLAG_CAP=64" in THREE
    assert "applyEmpireBuildingSkin" in THREE
    assert "restoreEmpireBuildingSkin" in THREE
    assert "empireSkinMaterialsAt" in THREE
    assert "marker.facade.visible=false" in THREE
    assert "preserved-original-3d-skin-only-v390" in THREE


def test_converted_interiors_have_current_design_profile() -> None:
    assert "purpose-v3:${kind}:${operation||'headquarters'}" in THREE
    assert "visible hydraulic lift" in THREE
    assert "TorusGeometry(1.25,.16,10,32)" in THREE
    assert "neonArch" in THREE
    assert "Public entrance treatment" in THREE
    assert "purpose-v2:${Math.round(now/1000)}" in WORLD


def test_vacant_building_purchase_uses_e_and_hq_is_first() -> None:
    assert "_DIRECT_OWNER_UID" in WORLD and "? '453201199' : ''" in WORLD
    assert "_gtaActionKind === 'apt_buy'" in WORLD
    assert "kind:'interior',id:`apt-buy:" in WORLD
    assert "if(near.kind==='interior')" in WORLD
    assert "matchMedia('(pointer:fine)').matches?'none':'block'" in WORLD
    assert "innerHTML=hqCard+Object.entries(PLAYER_BUILDING_OPERATIONS)" in WORLD
    assert "data-hq-locked" in WORLD and "pbcDenied" in WORLD
    assert "Штаб уже имеется. Продайте здание" in WORLD


def test_business_picker_is_a_visual_income_gallery() -> None:
    picker = WORLD[WORLD.index("function _playerBuildingChoiceModal"):WORLD.index("function openNpcAnnexBuildingChoice")]
    assert "_playerBuildingChoiceVisual" in picker
    assert 'class="pbc-business-visual pbc-visual-${id}"' in picker
    assert "pbc-mini-facade" in picker and "pbc-mini-sign" in picker
    assert "pbc-visual-beer_bar" in picker and "pbc-visual-strip_club" in picker
    assert "pbc-visual-gun_shop" in picker and "pbc-visual-print_shop" in picker
    assert "ДОХОД ЗДАНИЯ В МИНУТУ" in picker
    assert "Окупаемость" not in picker and "returnMinutes" not in picker


def test_building_purchase_requires_yes_no_confirmation_and_closes_panels() -> None:
    picker = WORLD[WORLD.index("let _playerBuildingChoiceMode"):WORLD.index("function openNpcAnnexBuildingChoice")]
    purchase = WORLD[WORLD.index("async function _buyCurrentApartment"):WORLD.index("function showApartmentUpgradeMenu")]
    assert "openPlayerBuildingPurchaseConfirmation" in picker
    assert "data-pbc-confirm-no" in picker and "data-pbc-confirm-yes" in picker
    assert "НЕТ, ВЕРНУТЬСЯ" in picker and "ДА, КУПИТЬ ЗА" in picker
    assert "_pendingPlayerBuildingPurchase" in picker
    assert "_closePlayerBuildingPurchaseUi();" in picker
    assert "closeApartmentControlPanel()" in purchase
    assert "openApartmentControlPanel();" not in purchase
    assert "openCustomGangModal();" not in purchase


def test_interior_camera_zoom_is_bounded_and_restores_world_zoom() -> None:
    assert "interiorZoom=1.08" in THREE
    assert "THREE.MathUtils.clamp(interiorZoom+direction*step,.55,1.9)" in THREE
    assert "dataset.interiorZoom=interiorZoom.toFixed(2)" in THREE
    assert "camera.zoom=worldZoom" in THREE


if __name__ == "__main__":
    tests = [value for name, value in sorted(globals().items()) if name.startswith("test_")]
    for test in tests:
        test()
    print(f"flexible building contract: {len(tests)} checks passed")
