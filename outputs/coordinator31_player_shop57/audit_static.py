"""Record file-only integration evidence. This does not start Godot."""
from pathlib import Path
import hashlib
import json
import struct
from xml.etree import ElementTree
from PIL import Image

root = Path(__file__).resolve().parents[2]
base = root / "outputs/coordinator31_release57/game"
target = Path(__file__).resolve().parent / "game"
source = root / "outputs/dsh_living_city_01/game"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


baseline = {p.relative_to(base).as_posix(): p for p in base.rglob("*") if p.is_file() and ".godot" not in p.parts}
candidate = {p.relative_to(target).as_posix(): p for p in target.rglob("*") if p.is_file() and ".godot" not in p.parts}
missing = sorted(set(baseline) - set(candidate))
changes = {}
for rel, path in candidate.items():
    before = baseline.get(rel)
    if before is None or digest(before) != digest(path):
        donor = source / rel
        changes[rel] = {
            "baseline_sha256": digest(before) if before else None,
            "donor_sha256": digest(donor) if donor.is_file() else None,
            "candidate_sha256": digest(path),
        }

required = [
    "data/player_shop.json",
    "scripts/shop/player_shop_host.gd",
    "scripts/shop/player_shop_catalog.gd",
    "scripts/shop/player_shop_state.gd",
    "scripts/shop/player_shop_panel.gd",
    "scripts/shop/player_shop_inventory.gd",
    "scripts/venues/npc_compact_service_site29.gd",
    "scripts/venues/npc_service_sites_host29.gd",
    "scripts/venues/npc_venue_staff_actor29.gd",
]
checks = {
    "required_files": all((target / rel).is_file() for rel in required),
    "baseline_files_preserved": not missing,
    "weapon_shop_site": "VENUE29-SHOP-002" in (target / "scripts/shop/player_shop_host.gd").read_text(encoding="utf-8"),
    "shop_flag": "--city-player-shop=1" in (target / "scripts/main.gd").read_text(encoding="utf-8"),
    "cashier_behind_counter": "behind_counter" in (target / "scripts/venues/npc_venue_staff_actor29.gd").read_text(encoding="utf-8"),
}
catalog = json.loads((target / "data/player_shop.json").read_text(encoding="utf-8"))
try:
    for item in catalog["weapons"]:
        with Image.open(target / "assets/weapon_thumbnails" / (item["id"] + ".png")) as image:
            image.load()
            assert image.width >= 256 and image.height >= 128
            assert image.getbbox() is not None
    checks["all_weapon_pictures"] = len(catalog["weapons"]) == 14
except (OSError, AssertionError, KeyError):
    checks["all_weapon_pictures"] = False
try:
    for item in catalog["ammo"]:
        icon = target / "assets/shop_icons" / (item["id"] + ".svg")
        assert ElementTree.parse(icon).getroot().attrib.get("viewBox") == "0 0 256 128"
    checks["all_ammo_pictures"] = len(catalog["ammo"]) == 6
except (OSError, AssertionError, KeyError, ElementTree.ParseError):
    checks["all_ammo_pictures"] = False
sites_source = (target / "scripts/venues/npc_service_sites_host29.gd").read_text(encoding="utf-8")
checks["shop_near_hero_spawn"] = "placement.position = [22.2, 0.0, 1.0]" in sites_source
inventory_source = (target / "scripts/shop/player_shop_inventory.gd").read_text(encoding="utf-8")
checks["single_intact_vest_policy"] = "for owned_id: String in _armor:" in inventory_source and "_armor.clear()" in inventory_source
throw_source = (target / "scripts/shop/player_throwables.gd").read_text(encoding="utf-8")
checks["throw_controls_and_trajectory"] = all(fragment in throw_source for fragment in [
    "MOUSE_BUTTON_RIGHT", "MOUSE_BUTTON_LEFT", "func _trajectory()", "func _cancel_aim", "backpack.take(_mode,1)",
])
checks["grenade_and_molotov_sale"] = {item["id"] for item in catalog["consumables"]}.issuperset({"c4", "grenade", "molotov"})
checks["area_damage_and_destruction"] = all((target / rel).is_file() for rel in [
    "scripts/destruction/palazzo/c4_building_blast.gd",
    "scripts/npc_visual/npc_local_preview_hit_owner.gd",
    "scripts/npc_visual/npc_melee_player_health.gd",
]) and "func apply_throwable" in (target / "scripts/destruction/palazzo/c4_building_blast.gd").read_text(encoding="utf-8")
city_qa = (target / "scripts/shop/tests/test_shop_city57.gd").read_text(encoding="utf-8")
checks["destruction_qa_prepared"] = "grenade releases physical shop sections" in city_qa and "Molotov releases physical shop sections" in city_qa
checks["area_cover_and_ground_fire"] = "func _fire_surface" in throw_source and "area_occluded" in (target / "scripts/npc_visual/npc_local_preview_hit_owner.gd").read_text(encoding="utf-8")
projectile_source = (target / "scripts/shop/throwable_projectile_pool.gd").read_text(encoding="utf-8")
fire_source = (target / "scripts/shop/throwable_fire_pool.gd").read_text(encoding="utf-8")
launch_source = throw_source.split("func _launch(path: Dictionary)", 1)[1].split("func _impact(", 1)[0]
impact_source = throw_source.split("func _impact(", 1)[1].split("func _fire_surface(", 1)[0]
projectile_acquire = projectile_source.split("func acquire(", 1)[1].split("func visual(", 1)[0]
fire_ignite = fire_source.split("func ignite(", 1)[1].split("func update_field(", 1)[0]
checks["pooled_visuals_no_impact_meshes"] = all(fragment in throw_source for fragment in [
    "_projectile_pool.acquire", "_projectile_pool.release", "_fire_pool.ignite", "_fire_pool.stop_field",
]) and all(".new(" not in block for block in [launch_source, impact_source, projectile_acquire, fire_ignite])
checks["bounded_fire_and_projectiles"] = all(fragment in fire_source for fragment in [
    "const CAPACITY := 6", "const FLAMES := 24", "const SMOKE := 10", "const EMBERS := 12",
    "UPDATE_INTERVAL := 1.0 / 15.0", "shadow_enabled=false",
    "visible_instance_count", "distance_sq<18.0*18.0",
]) and "const CAPACITY := 8" in projectile_source
checks["throw_pose_and_grenade_fuse"] = "set_throw_pose_decorator" in (target / "scripts/preview_player.gd").read_text(encoding="utf-8") and all(fragment in throw_source for fragment in [
    "WINDUP_SECONDS := 0.22", "GRENADE_FUSE := 2.6", "row.velocity=reflected-tangent*.22", "rotate_object_local",
])
glb = (target / "assets/hero.glb").read_bytes()
chunk_size, chunk_type = struct.unpack_from("<II", glb, 12)
hero_nodes = json.loads(glb[20:20 + chunk_size])["nodes"] if glb[:4] == b"glTF" and chunk_type == 0x4E4F534A else []
hero_names = {node.get("name", ""): index for index, node in enumerate(hero_nodes)}
hero_parents = {child: index for index, node in enumerate(hero_nodes) for child in node.get("children", [])}
checks["throw_socket_follows_right_arm"] = all(name in hero_names for name in ["socket_weapon", "hand_r", "forearm_r", "upperarm_r"]) and all(
    hero_parents.get(hero_names[child]) == hero_names[parent] for child, parent in [
        ("socket_weapon", "hand_r"), ("hand_r", "forearm_r"), ("forearm_r", "upperarm_r")
    ]
)
checks["projectile_and_fire_shaders"] = all((target / rel).is_file() for rel in [
    "scripts/shop/throwable_fire.gdshader", "scripts/shop/throwable_scorch.gdshader",
])
player_source = (target / "scripts/preview_player.gd").read_text(encoding="utf-8")
weapons_source = (target / "scripts/weapons/preview_weapons.gd").read_text(encoding="utf-8")
checks["jump_and_dive_keep_mounted_weapon"] = "if is_instance_valid(_weapon_host): source=_weapon_host.decorate(source)" in player_source and all(fragment in weapons_source for fragment in [
    'presentation_aim["airborne"]=true', 'presentation_aim["airBlend"]=1.0',
])
checks["airborne_fire_commits_after_pose"] = all(fragment in weapons_source for fragment in [
    "func _combat_allowed() -> bool:",
    "armed() and _combat_allowed(): _reload = true",
    "armed() and _combat_allowed():",
    "var allowed: bool = _combat_allowed() and not controls_blocked()",
    "_pending_epoch != player._pose_epoch or not _combat_allowed()",
]) and "host._combat_allowed()" in (target / "scripts/weapons/weapon_aim_camera.gd").read_text(encoding="utf-8")
checks["stance_input_collision_camera"] = all(fragment in weapons_source for fragment in [
    "if stance_code in [KEY_C,KEY_CTRL,KEY_Z] and _request_posture(stance_code):",
    "capsule.shape.height=float(_posture_view.height)",
    "player.set_posture_eye_height(float(_posture_view.eyeHeight))",
]) and "func set_posture_eye_height(height: float)" in player_source
checks["pose_runtime_qa_prepared"] = all(fragment in (target / "scripts/shop/tests/test_player_pose57.gd").read_text(encoding="utf-8") for fragment in [
    "Nagan visible while crouching", "Nagan visible while prone", "Nagan visible during ordinary jump", "Nagan visible during Max Payne dive",
    "Nagan fires while crouching", "Nagan fires while prone", "Nagan fires during ordinary jump", "Nagan fires during Max Payne dive",
])
checks["palazzo_style_sections"] = "extends \"res://scripts/destruction/palazzo/palazzo_structural_site.gd\"" in (target / "scripts/venues/npc_compact_service_site29.gd").read_text(encoding="utf-8")
accepted = json.loads((root / "outputs/coordinator31_release57/ASSEMBLY.json").read_text(encoding="utf-8"))
arguments = [arg for arg in accepted["launch_arguments"] if arg != "--city-player-shop=1"] + ["--city-player-shop=1"]
report = {
    "schema": "mafiozi.player-shop57.static-integration/v1",
    "status": "files_integrated_runtime_pending_user_scene",
    "source_commit": "def3f4747f7185f8aa24b4206279e43a7bf51d33",
    "baseline": str(base),
    "candidate": str(target),
    "scene_runs_started": 0,
    "visual_budget": {"pooled_projectiles": 8, "pooled_fire_fields": 6, "maximum_fire_billboards": 276, "maximum_fire_draw_batches": 12, "maximum_molotov_lights": 2, "fire_shader_updates_hz": 15, "trajectory_refresh_hz": 20, "per_throw_node_allocations": 0, "per_impact_visual_node_allocations": 0, "measured_fps": None},
    "launch_arguments_for_later_review": arguments,
    "checks": checks,
    "missing_baseline_files": missing,
    "changed": changes,
}
(target.parent / "INTEGRATION.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps({"checks": checks, "changed_files": len(changes), "missing": len(missing)}, ensure_ascii=False))
if not all(checks.values()):
    raise SystemExit(1)
