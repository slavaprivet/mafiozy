"""Static contract for the PC-first inventory presentation layer."""

from pathlib import Path


ROOT = Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")


def block(start: str, end: str) -> str:
    begin = WORLD.index(start)
    return WORLD[begin:WORLD.index(end, begin)]


def run() -> None:
    authority = block(
        "const INVENTORY_ARMOR_UI_CONTRACT=", "let _armorBreakPending")
    assert "'combat_state.v1'" in authority
    assert "snapshot.combat_state" in authority
    assert "combat.armor" in authority
    for field in ("raw?.id", "raw?.instance_id", "raw?.current",
                  "raw?.max", "raw?.version", "raw?.broken"):
        assert field in authority
    assert "snapshot.armor_state" not in authority
    assert "raw?.item_id" not in authority
    assert "raw?.hp" not in authority and "raw?.max_hp" not in authority
    assert "source:'absent'" in authority
    assert "ARMOR_STYLES[equipped]?equipped:''" in authority

    preview = block("function _seedPreviewInventory()", "async function loadInventoryItems()")
    for exact in (
        "combat_state:{body:{current:100,max:100,dead:false}",
        "armor:{id:_equippedArmor,instance_id:'preview:tactical-vest:1'",
        "current:previewHp,max:previewMax,version:1,broken:false",
        "combat_version:1",
    ):
        assert exact in preview

    inventory = block("function renderProfileTab()", "} else if (_profileTab === 'status')")
    for marker in (
        "inventory-command", "inventory-armor-command",
        "Авторитетная защита · combat_state.v1", "armor HP",
        "inventory-category-nav", "inventory-tag rarity-",
        "inventory-price", "Сервер не передал состояние брони",
    ):
        assert marker in WORLD
    assert "_armorDurability(" not in inventory
    assert "_inventoryArmorCondition" in inventory
    assert "_equipArmorFromInventory" in inventory
    assert "_unequipArmorFromInventory" in inventory

    shop = block("function _renderShopItems()", "function _drawShopWeaponPreviews()")
    assert "_inventoryUiTags" in shop and "shop-price" in shop
    assert "_shopPurchasesPending" in shop and "_shopItemOwned" in shop

    css = block(".inventory-command {", "#profileModal .stat-block")
    assert "repeat(3,minmax(0,1fr))" in css
    assert "new THREE." not in authority + inventory + shop
    assert "requestAnimationFrame" not in authority + inventory + shop

    mobile = block("@media (max-width: 640px)", "#michaelModal .card")
    assert ".inventory-command { grid-template-columns:1fr; }" in mobile
    assert ".inventory-category-nav button { flex:0 0 auto;min-height:40px; }" in mobile
    assert ".inventory-btn{min-height:40px}" in mobile
    assert "@media (max-width:390px)" in mobile
    assert "@media(max-width:420px)" in WORLD
    assert "dataset.inventoryPreviewSurface=surface" in WORLD
    assert "_UP.get('previewinventory')==='shop'?'shop':'profile'" in WORLD
    assert "body:has(#shopOverlay.open) #districtRepHud,body:has(#profileModal.show) #districtRepHud" in WORLD


if __name__ == "__main__":
    run()
    print("inventory PC UI: combat_state.v1 authority, cards, store and mobile fallback OK")
