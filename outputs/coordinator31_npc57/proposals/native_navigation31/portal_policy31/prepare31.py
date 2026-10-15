from pathlib import Path
import hashlib
import difflib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
BASE = ROOT / "outputs/coordinator31_release57/game"
CAP = "scripts/venues/npc_venue_capacity29.gd"
REG = "scripts/venues/npc_venue_registry29.gd"
PASS = "scripts/navigation/npc_passage31.gd"


def change(source, old, new):
    assert source.count(old) == 1, old
    return source.replace(old, new)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    original = {rel:(BASE/rel).read_text(encoding="utf-8-sig") for rel in [CAP,REG,PASS]}
    capacity = change(original[CAP], '"slots":{}}', '"slots":{},"concurrent_portal31":false}')
    capacity = change(capacity,
        'func portal_request(key: String, venue: String) -> bool:\n\tif not requests.has(key) or str(requests[key].venue) != venue: return false\n',
        'func set_concurrent_portal31(venue: String, supported: bool) -> void:\n'
        '\tif venues.has(venue): venues[venue].concurrent_portal31 = supported\n\n'
        'func portal_owner31(key: String, venue: String) -> bool:\n'
        '\tif not venues.has(venue) or not requests.has(key) or requests[key].state != "reserved" or str(requests[key].venue) != venue: return false\n'
        '\tvar queue: Array = _portals.get(venue, [])\n'
        '\treturn queue.has(key) if bool(venues[venue].concurrent_portal31) else (not queue.is_empty() and str(queue[0]) == key)\n\n'
        'func portal_request(key: String, venue: String) -> bool:\n'
        '\tif not venues.has(venue) or not requests.has(key) or requests[key].state != "reserved" or str(requests[key].venue) != venue: return false\n')
    capacity = change(capacity, '\treturn not queue.is_empty() and str(queue[0]) == key\n', '\treturn portal_owner31(key, venue)\n')
    passage = change(original[PASS], 'func body_zone(body: CharacterBody3D) -> String:\n',
        '## Capability derives from the same measured, live doorway used by native pairs.\n'
        'func supports_venue31(venue: String) -> bool:\n'
        '\trefresh()\n'
        '\tif not _zones.has(venue): return false\n'
        '\tvar zone: Dictionary = _zones[venue]\n'
        '\tvar owner: Variant = zone.owner.get_ref(); var clone: Variant = zone.clone.get_ref()\n'
        '\treturn is_instance_valid(owner) and is_instance_valid(clone) and not owner.is_queued_for_deletion() and not clone.is_queued_for_deletion() and not bool(clone.get_meta("venue_closed29", false))\n\n'
        'func body_zone(body: CharacterBody3D) -> String:\n')
    registry = change(original[REG], 'const Capacity = preload("npc_venue_capacity29.gd")\n',
        'const Capacity = preload("npc_venue_capacity29.gd")\nconst Passage31 = preload("res://scripts/navigation/npc_passage31.gd")\n')
    registry = change(registry, '\treturn value\n\nfunc owns(',
        '\tvar scene31: Node3D = _scene.get_ref() as Node3D if _scene != null else null\n'
        '\tvar passage31: Node = Passage31.for_scene(scene31)\n'
        '\tledger.set_concurrent_portal31(venue, is_instance_valid(passage31) and passage31.supports_venue31(venue))\n'
        '\treturn value\n\nfunc owns(')
    registry = change(registry,
        '\tvar portal: Array = ledger._portals.get(venue, [])\n\tvar owner: bool = not portal.is_empty() and str(portal[0]) == key\n',
        '\tvar owner: bool = ledger.portal_owner31(key, venue)\n')
    changes = {CAP:capacity,REG:registry,PASS:passage}
    pins = {}
    diff = []
    for rel, source in changes.items():
        target = HERE / "patch" / rel; target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(source,encoding="utf-8",newline="\n")
        pins[rel] = {"base_sha256":sha(BASE/rel),"candidate_sha256":sha(target)}
        diff.extend(difflib.unified_diff(original[rel].splitlines(True),source.splitlines(True),"a/"+rel,"b/"+rel))
    (HERE/"CHANGE.patch").write_text("".join(diff),encoding="utf-8",newline="\n")
    (HERE/"PATCH.json").write_text(json.dumps(pins,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(pins))


if __name__ == "__main__": main()
