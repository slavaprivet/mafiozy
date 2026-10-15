"""Install the committed player shop on the NPC57 candidate without replacing its city work."""
from pathlib import Path
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "outputs/dsh_living_city_01/game"
BASE = ROOT / "outputs/coordinator31_npc57/game"
TARGET = Path(__file__).resolve().parent / "game"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def install():
    if TARGET.exists():
        raise RuntimeError("Target already exists; preserve previous integration")
    shutil.copytree(BASE, TARGET, ignore=shutil.ignore_patterns(".godot"))
    changed = {}

    def edit(rel, old, new):
        target = TARGET / rel
        before = target.read_text(encoding="utf-8")
        count = before.count(old)
        if count != 1:
            raise RuntimeError(f"{rel}: expected one anchor, found {count}: {old[:80]!r}")
        target.write_text(before.replace(old, new, 1), encoding="utf-8", newline="\n")
        changed[rel] = {"base_sha256": sha(BASE / rel), "integrated_sha256": sha(target)}

    def source_slice(rel, start, end):
        content = (SOURCE / rel).read_text(encoding="utf-8")
        a = content.index(start)
        b = content.index(end, a + len(start))
        return content[a:b]

    for path in (SOURCE / "scripts/shop").rglob("*"):
        if path.is_file() and "tests" not in path.parts and (path.name.startswith("player_") or path.name == "README.md"):
            rel = path.relative_to(SOURCE)
            out = TARGET / rel
            out.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, out)
            changed[rel.as_posix()] = {"source_sha256": sha(path), "integrated_sha256": sha(out)}
    for path in (SOURCE / "scripts/shop/tests").glob("*"):
        if path.is_file():
            rel = path.relative_to(SOURCE)
            out = TARGET / rel
            out.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, out)
            changed[rel.as_posix()] = {"source_sha256": sha(path), "integrated_sha256": sha(out)}
    shutil.copy2(SOURCE / "data/player_shop.json", TARGET / "data/player_shop.json")
    changed["data/player_shop.json"] = {"source_sha256": sha(SOURCE / "data/player_shop.json"), "integrated_sha256": sha(TARGET / "data/player_shop.json")}

    main = "scripts/main.gd"
    edit(main, 'const SimpleHospital = preload("res://scripts/hospital/npc_simple_hospital.gd")\n',
         'const SimpleHospital = preload("res://scripts/hospital/npc_simple_hospital.gd")\n'
         'const PlayerShopCatalog = preload("res://scripts/shop/player_shop_catalog.gd")  # DSH_PLAYERSHOP\n')
    edit(main, 'weapon_host.configure(self, _player)', 'weapon_host.configure(self, _player, player_shop_weapon_options())')
    edit(main, '\tif is_instance_valid(preview_modular30):\n\t\tprint("MODULAR30_NATIVE_BINDING ", preview_modular30.bind_weapons())',
         '\tif player_shop_requested(): install_player_shop()  # DSH_PLAYERSHOP\n'
         '\tif is_instance_valid(preview_modular30):\n\t\tprint("MODULAR30_NATIVE_BINDING ", preview_modular30.bind_weapons())')
    source_main = (SOURCE / main).read_text(encoding="utf-8")
    extension = source_main[source_main.index('# ── DSH_PLAYERSHOP:'):]
    target_main = TARGET / main
    target_main.write_text(target_main.read_text(encoding="utf-8") + "\n\n" + extension, encoding="utf-8", newline="\n")
    changed[main]["integrated_sha256"] = sha(target_main)

    preview = "scripts/weapons/preview_weapons.gd"
    edit(preview, 'func configure(world: Node3D, actor: CharacterBody3D) -> Dictionary:',
         'func configure(world: Node3D, actor: CharacterBody3D, options: Dictionary = {}) -> Dictionary:')
    edit(preview, '\tvar configured: Dictionary = inventory.configure(Fire.new())',
         '\tvar inventory_options: Dictionary = {}\n'
         '\t# DSH_PLAYERSHOP: starter ownership is supplied only when the shop is enabled.\n'
         '\tif options.has("ownedIds"): inventory_options["ownedIds"] = options["ownedIds"]\n'
         '\tvar configured: Dictionary = inventory.configure(Fire.new(), inventory_options)')
    inventory = "scripts/weapons/weapon_inventory.gd"
    reserve = source_slice(inventory, '## DSH_PLAYERSHOP: a box of ammo', 'func snapshot() -> Dictionary:')
    edit(inventory, 'func snapshot() -> Dictionary:', reserve + 'func snapshot() -> Dictionary:')
    health = "scripts/npc_visual/npc_melee_player_health.gd"
    edit(health, '\tvar damage:=1 if blocked else 12\n\tvar before:=_hp\n\t_hp=maxi(0,_hp-damage);_revision+=1;_hit_age=0.0',
         '\tvar damage:=1 if blocked else 12\n'
         '\t# DSH_PLAYERSHOP: worn armor absorbs contact damage before HP.\n'
         '\tvar armor_absorbed:=0\n'
         '\tif _player.has_meta("player_armor_absorb"):\n'
         '\t\tvar provider: Variant=_player.get_meta("player_armor_absorb")\n'
         '\t\tif provider is Callable and (provider as Callable).is_valid():\n'
         '\t\t\tvar vest: Dictionary=(provider as Callable).call(damage)\n'
         '\t\t\tarmor_absorbed=clampi(int(vest.get("absorbed",0)),0,damage)\n'
         '\tvar taken:=maxi(0,damage-armor_absorbed)\n'
         '\tvar before:=_hp\n\t_hp=maxi(0,_hp-taken);_revision+=1;_hit_age=0.0')
    edit(health, '"blocked":blocked,"scope":"local_new_session"}',
         '"blocked":blocked,"armor_absorbed":armor_absorbed,"damage_taken":taken,"scope":"local_new_session"}')
    c4 = "scripts/destruction/palazzo/c4_equipment.gd"
    edit(c4, 'var _charges: Dictionary = {}\n', source_slice(c4, 'var _charges: Dictionary = {}', 'var _hold: Dictionary = {}'))
    edit(c4, '\t_hold.point=current.point; _hold.normal=current.normal\n\t_sequence+=1',
         source_slice(c4, '\t# DSH_PLAYERSHOP: a real backpack is charged', '\t_hold.point=current.point; _hold.normal=current.normal')
         + '\t_hold.point=current.point; _hold.normal=current.normal\n\t_sequence+=1')
    edit(c4, '\tif _mode!="off" and _weapons.fire_state.get("weaponId")=="none":',
         source_slice(c4, '\t# DSH_PLAYERSHOP: the pack count is a peek', '\tif _mode!="off" and _weapons.fire_state.get("weaponId")=="none":')
         + '\tif _mode!="off" and _weapons.fire_state.get("weaponId")=="none":')

    manifest = {"base": str(BASE), "source_commit": "def3f4747f7185f8aa24b4206279e43a7bf51d33", "target": str(TARGET), "changed": changed}
    (TARGET.parent / "INTEGRATION.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")


if __name__ == "__main__":
    install()
