"""Regression contract for readable gang and authoritative owner labels."""

from pathlib import Path


ROOT = Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")
BOT = (ROOT / "mafiozi_bot.py").read_text(encoding="utf-8")


def test_custom_gang_hud_name_is_prominent() -> None:
    assert "custom-gang-status .js-state" in WORLD
    assert "font:900 15px/1.12 Georgia" in WORLD
    assert "classList.remove('custom-gang-status')" in WORLD
    assert "classList.add('custom-gang-status')" in WORLD


def test_converted_business_names_authoritative_owner() -> None:
    assert "[property.ownerName,property.gangName,'ВЛАДЕЛЕЦ'].find" in THREE
    assert "ПОД УПРАВЛЕНИЕМ: ${ownerName}" in THREE
    assert "slice(0,48)" in THREE
    assert "apartmentInfo.owner_name||src.apartmentOwnerName" in WORLD
    assert "_LOCAL_PREVIEW&&_myApartments[apartmentKey]?(QP.name||'Игрок')" in WORLD
    assert 'SELECT name FROM characters WHERE telegram_id=?' in BOT
    assert '"owner_name": owner_name' in BOT
    assert "three_preview.js?v=3d418-authoritative-business-skins&opt=burning-pool-v414+pooled-marker-accounting-v416&facade=depth-roof-sign-v1&building=brick-limestone-glass-depth-v2&building2=concrete-deco-industrial-depth-v1&building3=coffee-barbershop-pizza-storefront-v1&npcgear=police-layer-separation-v1&brick=bank-reference-massing-v2&material=physical-glass-soft-shadow-v1&visual=roads-trees-smoke-v1&road=road-scale-aggregate-mottle-repair-v1&lighting=authoritative-circadian-v1" in WORLD


if __name__ == "__main__":
    test_custom_gang_hud_name_is_prominent()
    test_converted_business_names_authoritative_owner()
    print("owner readable labels regression: ok")
