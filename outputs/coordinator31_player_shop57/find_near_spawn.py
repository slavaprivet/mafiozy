"""CPU-only candidate search for the compact shop near the player's authored spawn."""
from pathlib import Path
import json
import math

root = Path(__file__).resolve().parent / "game"
block = json.loads((root / "data/city_block.json").read_text(encoding="utf-8"))
surface = block["surface"]
hero = block["hero"]["spawnLocalM"]
origin = block["originM"]
cell = surface["cellSize"]
venues = json.loads((root / "data/venue_sites29.json").read_text(encoding="utf-8"))["entries"]


def dry(x, z, grass=False):
    col = math.floor((x + origin[0]) / cell) - surface["startCol"]
    row = math.floor((z + origin[2]) / cell) - surface["startRow"]
    if row < 0 or row >= surface["rows"] or col < 0 or col >= surface["cols"]:
        return False
    if surface["masks"]["protectedMask"][row][col] or not surface["masks"]["walkableMask"][row][col]:
        return False
    tile = surface["grid"][row][col]
    return tile == 8 if grass else tile not in (16, 19)


def at(center, yaw, lx, lz):
    return (center[0] + lx * math.cos(yaw) + lz * math.sin(yaw),
            center[1] - lx * math.sin(yaw) + lz * math.cos(yaw))


def admissible(center, yaw, road_distance):
    for lx in range(-5, 6):
        for lz in range(-4, 5):
            if not dry(*at(center, yaw, lx, lz), grass=True):
                return False
    samples = [(x, z) for x in (-3.9, 0, 3.9) for z in (-3.4, 0, 3.4)]
    samples += [(x, 7.1) for x in (-5.2, -4, -2.8, 0, 2.8, 4, 5.2)]
    samples += [(x, d) for d in range(4, math.ceil(road_distance) + 1) for x in (-.5, 0, .5)]
    return all(dry(*at(center, yaw, lx, lz)) for lx, lz in samples)


rows = []
for dx in range(-60, 61, 2):
    for dz in range(-60, 61, 2):
        center = (hero[0] + dx, hero[2] + dz)
        distance = math.hypot(dx, dz)
        if distance < 10 or distance > 60:
            continue
        if any(math.hypot(center[0] - v["position"][0], center[1] - v["position"][2]) < 15 for v in venues):
            continue
        for yaw in (0, math.pi / 2, math.pi, -math.pi / 2):
            for road_distance in (8, 11, 14, 17):
                if admissible(center, yaw, road_distance):
                    rows.append((distance, center, yaw, road_distance))

rows.sort(key=lambda row: row[0])
for row in rows[:1000]:
    print(json.dumps({"distance_m": round(row[0], 2), "position": [round(row[1][0], 3), 0, round(row[1][1], 3)], "yaw": row[2], "road_distance_m": row[3]}, ensure_ascii=False))
