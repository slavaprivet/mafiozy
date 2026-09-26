#!/usr/bin/env python3
"""Bounded, read-only Walk source baseline; never reads saves, profiles or a DB.

The ZIP is an audit archive, not a runnable build or an accepted Godot migration.
Only explicit source/data inputs and literal local JS imports are followed.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CITY = "assets/maps/city_rebuild_v1/"
EXPECTED_HEAD = "3612fa62f8d3bcb6888c7028ed0791fe0c928085"
EXPECTED = {
    "world.html": "9f5cc5a1a80db37dbf3136ecab66c4cdba2bd679dbea03aa10800ac16d8a95b5",
    CITY + "walk_preview.mjs": "e80ebf4be2d0404ad5b51d4bf28b756a9cba2b486c43c0797de748c37364dd47",
    "outputs/mercenary_hospital_return26.patch": "9382243e83fa9b28ca7466ebbb5b2ea718701d6d2a7bf925c92711c35b471002",
    "outputs/mercenary_vehicle_ready26_candidate.patch": "193a2c42d53345e1945817f7d6a3fb5eced98a0755f5cfdd4c3261ea97112b5b",
}
DATA = [CITY + p for p in (
    "topology_for_placement.json", "buildings_placement.v1.json",
    "decor_placement.v1.json", "detention_native_sites.v1.json",
    "buildings_catalog.v1.json", "decor_catalog.v1.json",
    "infrastructure_catalog.v1.json", "hero_walk.manifest.json",
    "interior_safe_manifest.v1.json", "models/artist_vehicle_pack/manifest.json",
)]
PACKETS = [
    "docs/ai/NPC_SERVICE_WALK23_CHECKPOINT.json",
    "docs/ai/NPC_SERVICE_WALK23_CHECKPOINT.md",
    "docs/ai/NPC_SERVICE_WALK23_CHECKPOINT.patch",
    "outputs/mercenary_hospital_return26.patch",
    "outputs/build_mercenary_hospital_return26.mjs",
    "outputs/test_mercenary_hospital_return26.mjs",
    "outputs/mercenary_hospital_return26_results.json",
    "outputs/MERCENARY_HOSPITAL_RETURN26_PROPOSAL.md",
    "outputs/mercenary_vehicle_ready26_candidate.patch",
    "outputs/mercenary_vehicle_ready26_candidate.mjs",
    "outputs/vehicle_ready26_candidate_manifest.json",
    "outputs/vehicle_ready26_candidate_contract.json",
    "outputs/vehicle_ready_transition26_candidate.json",
    "outputs/VEHICLE_READY26_FOCUSED_HANDOFF.md",
    CITY + "test_civilian_native_fixture.mjs",
]
DOCS = [
    "docs/city-rebuild/WORLD_WALK_GATEWAY_HANDOFF.md",
    "docs/city-rebuild/WORLD_WALK_HEALTH_HANDOFF.md",
    "docs/city-rebuild/WALK_PREVIEW_HANDOFF.md",
    "docs/godot/ASTRA10_PLAN_SUMMARY_20260924.md",
]
# Hash/symbol inventory only: no server source, credentials or DB copied to ZIP.
SERVER = ["mafiozi_bot.py", "npc_empire.py"]
IMPORT = re.compile(r"(?:\b(?:import|export)\s+(?:[^;\n]*?\s+from\s*)?|\bimport\s*\()\s*['\"]([^'\"]+)['\"]")
SCRIPT = re.compile(r"<script\b[^>]*\bsrc\s*=\s*['\"]([^'\"]+)['\"]", re.I)
SYMBOLS = {
    "world.html": ["function buildMap(", "function update(", "window.Mafiozi3DBridge =", "syncWalkPlayer(", "getPlayerState(", "getWorldClock(", "function _residentServiceYield23(", "new WebSocket(", "function _hurtLocal("],
    "world_walk_host.mjs": ["export async function", "MafioziWalkShell", "walk_preview.mjs"],
    CITY + "walk_preview.mjs": ["loadHeroWalker(", "createNpcPopulation(", "createVehicleFleet(", "async function refresh(", "getJsonBytes('topology_for_placement.json'", "createStationaryServiceWalk23(", "createMercenarySafePlacement("],
    CITY + "mercenary_world.js": ["function effect(", "e.kind==='hospitalize'", "e.kind==='discharge'", "window.MafioziMercenaries=api", "localStorage"],
    "mafiozi_bot.py": ["async def get_authoritative_combat_state(", "async def claim_authoritative_weapon_fire(", "async def get_inventory(", "class WorldSim:", "async def _coop_http_app(", "async def _transfer_business_property(", "async def create_custom_gang_db(", "async def _world_run_loop("],
    "npc_empire.py": ["class ", "def ", "async def "],
}


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def git(*args: str, input: bytes | None = None) -> bytes:
    return subprocess.run(["git", *args], cwd=ROOT, input=input, check=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout


def safe_path(rel: str) -> Path:
    path = (ROOT / rel).resolve()
    path.relative_to(ROOT)
    if path.is_symlink() or any(p.lower() in {".git", ".env", "profiles", "userdata"} for p in Path(rel).parts):
        raise ValueError(f"Excluded path: {rel}")
    return path


def read(rel: str) -> bytes:
    path = safe_path(rel)
    if path.suffix.lower() not in {".js", ".mjs", ".html", ".json", ".md", ".patch", ".py", ".css"}:
        raise ValueError(f"Not a source input: {rel}")
    if path.stat().st_size > 8 * 1024 * 1024:
        raise ValueError(f"Source input exceeds 8 MiB bound: {rel}")
    return path.read_bytes()


def resolve_import(source: str, specifier: str) -> str | None:
    clean = specifier.split("?", 1)[0].split("#", 1)[0]
    if clean.startswith(("https:", "http:", "data:", "node:")):
        return None
    if not clean.startswith((".", "/", "assets/")) and not source.endswith(".html"):
        return None  # Bare imports, including Three/addons, remain external.
    path = (ROOT / clean.lstrip("/")) if clean.startswith("/") else (ROOT / source).parent / clean
    try:
        return path.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        return None


def base_blobs(paths: list[str], head: str) -> dict[str, bytes]:
    tracked = set(git("ls-tree", "-r", "--name-only", head).decode("utf-8").splitlines())
    selected = [p for p in paths if p in tracked]
    raw = git("cat-file", "--batch", input="".join(f"{head}:{p}\n" for p in selected).encode("utf-8"))
    result, offset = {}, 0
    for path in selected:
        end = raw.index(b"\n", offset)
        header = raw[offset:end].split()
        if len(header) != 3 or header[1] != b"blob":
            raise ValueError(f"Unexpected Git object: {path}")
        length = int(header[2])
        result[path] = raw[end + 1:end + 1 + length]
        offset = end + 2 + length
    return result


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def verify(out: Path) -> None:
    manifest = json.loads((out / "manifest.json").read_text(encoding="utf-8"))
    archive = out / "source_snapshot.zip"
    if digest(archive.read_bytes()) != manifest["archive"]["sha256"]:
        raise ValueError("Archive SHA mismatch")
    expected_entries = {}
    for row in manifest["files"]:
        expected_entries["working/" + row["path"]] = row["sha256"]
        if row.get("baseSha256"):
            expected_entries["base/" + row["path"]] = row["baseSha256"]
    with zipfile.ZipFile(archive) as bundle:
        if set(bundle.namelist()) != set(expected_entries):
            raise ValueError("Archive member set mismatch")
        for name, sha in expected_entries.items():
            if digest(bundle.read(name)) != sha:
                raise ValueError(f"Archive member mismatch: {name}")
    print(json.dumps({"verified": True, "archiveEntries": len(expected_entries),
                      "archiveSha256": manifest["archive"]["sha256"]}))


def capture(out: Path) -> None:
    if out.exists():
        raise ValueError("Output already exists; use --verify or a new --out. No overwrites.")
    head = git("rev-parse", "HEAD").decode().strip()
    if head != EXPECTED_HEAD:
        raise ValueError(f"Baseline HEAD changed: {head}; review script before recapture.")
    checkpoint = json.loads(read(PACKETS[0]))
    package_paths = [row["path"] for group in ("runtime", "tests") for row in checkpoint[group]]
    roots = ["world.html", "world_walk_host.mjs", "tools/city_rebuild_walk.html", CITY + "walk_preview.mjs", CITY + "mercenary_world.js"]
    files, graph, unresolved = {}, [], []
    queue = list(roots)
    while queue:
        rel = queue.pop(0)
        if rel in files:
            continue
        data = read(rel)
        files[rel] = data
        content = data.decode("utf-8-sig")
        references = [(m.group(1), "module") for m in IMPORT.finditer(content)]
        if rel.endswith(".html"):
            references += [(m.group(1), "html-script") for m in SCRIPT.finditer(content)]
        for specifier, kind in references:
            target = resolve_import(rel, specifier)
            row = {"from": rel, "specifier": specifier, "kind": kind, "target": target}
            if target and Path(target).suffix in {".js", ".mjs"} and safe_path(target).is_file():
                row["status"] = "local-source-captured"
                queue.append(target)
            else:
                row["status"] = "external-or-unresolved-static-reference"
                unresolved.append(row)
            graph.append(row)
        if len(files) > 500 or sum(map(len, files.values())) > 64 * 1024 * 1024:
            raise ValueError("Dependency closure exceeds bounded source snapshot budget")
    runtime_files = set(files)
    for path in sorted(set(DATA + PACKETS + DOCS + package_paths + ["tools/godot/capture_s00.py"])):
        files.setdefault(path, read(path))
    for path, expected in EXPECTED.items():
        if not digest(files[path]).startswith(expected):
            raise ValueError(f"Known WIP/packet changed: {path}")
    checks = []
    for group in ("runtime", "tests"):
        for item in checkpoint[group]:
            actual = digest(files[item["path"]])
            checks.append({"path": item["path"], "group": group, "sha256": actual,
                           "expectedSha256": item["sha256"], "matches": actual == item["sha256"]})
    if not all(x["matches"] for x in checks if x["group"] == "runtime"):
        raise ValueError("Service checkpoint runtime changed; review before capture")
    bases = base_blobs(sorted(files), head)
    records = []
    for path, data in sorted(files.items()):
        row = {"path": path, "bytes": len(data), "sha256": digest(data),
               "normalizedLfSha256": digest(data.replace(b"\r\n", b"\n")),
               "role": "static-runtime-source" if path in runtime_files else "curated-data-doc-test-or-packet",
               "trackedAtHead": path in bases}
        if path in bases:
            row["baseSha256"] = digest(bases[path])
            row["semanticLfDiffersFromHead"] = data.replace(b"\r\n", b"\n") != bases[path].replace(b"\r\n", b"\n")
        records.append(row)
    symbols, server = {}, []
    for path, needles in SYMBOLS.items():
        data = files.get(path) or read(path)
        lines = data.decode("utf-8-sig").splitlines()
        symbols[path] = [{"symbol": needle, "lines": [i + 1 for i, line in enumerate(lines) if needle in line][:30]} for needle in needles]
    for path in SERVER:
        data = read(path)
        server.append({"path": path, "bytes": len(data), "sha256": digest(data), "copied": False, "reason": "source hash/symbol inventory only; server/environment/DB migration separate"})
    top = json.loads(files[DATA[0]])
    # Recheck bytes to reject a mixed snapshot if shared writers changed inputs.
    changed = [p for p, data in files.items() if digest(read(p)) != digest(data)]
    if changed or git("rev-parse", "HEAD").decode().strip() != head:
        raise ValueError(f"Sources changed during capture: {changed}")
    out.mkdir(parents=True)
    archive = out / "source_snapshot.zip"
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as bundle:
        for prefix, collection in (("base", bases), ("working", files)):
            for path, data in sorted(collection.items()):
                entry = zipfile.ZipInfo(f"{prefix}/{path}", date_time=(2000, 1, 1, 0, 0, 0))
                entry.compress_type = zipfile.ZIP_DEFLATED
                entry.external_attr = 0o100644 << 16
                bundle.writestr(entry, data, compresslevel=9)
    manifest = {
        "schema": "mafiozi.godot.s00-source-baseline/v1", "head": head,
        "scope": "bounded static source/data archive; not executable/full map/save/acceptance; lexical source superset includes conditional legacy/editor paths",
        "runtimeSourceCount": len(runtime_files), "files": records,
        "archive": {"path": "source_snapshot.zip", "sha256": digest(archive.read_bytes()), "bytes": archive.stat().st_size},
        "serviceCheckpointChecks": checks, "serverSourcesHashOnly": server,
        "topology": {key: top.get(key) for key in ("schema", "status", "scope", "pendingHostSnapshot", "vehicleReady", "gameplayReady", "productionReady", "map", "coordinateConvention")},
        "topologyNotValidated": top.get("validation", {}).get("notValidated"),
        "hardwareReportedByCoordinator": {"cpu": "Intel Core i9-10900F", "gpu": "NVIDIA GeForce GTX 980", "vramApproxBytes": 4 * 1024**3, "ramBytes": 17113399296, "independentlyProbedHere": False},
        "acceptance": {"godot": False, "live": False, "fps": False, "fullMap": False, "savedProgress": False},
        "exclusions": ["environment/secrets", "databases", "browser storage contents", "profiles/authentication", "full asset/model/texture copies", "computed/dynamic import closure", "live generated transforms/colliders/state"],
        "packetStatus": {"service": "applied WIP; visual/FPS acceptance open", "hospital9382": "CPU proposal only; not applied; LIVE pending", "gun193a": "HOLD, not for application"},
    }
    write_json(out / "manifest.json", manifest)
    write_json(out / "static_dependencies.json", {"method": "lexical literal JS import/export/dynamic-import and HTML script-src scan; not execution", "complete": False, "edges": graph, "externalOrUnresolved": unresolved})
    write_json(out / "source_symbols.json", symbols)
    verify(out)
    print(json.dumps({"capturedFiles": len(files), "baseFiles": len(bases), "runtimeSourceCount": len(runtime_files), "archiveBytes": archive.stat().st_size, "unresolvedStaticReferences": len(unresolved)}))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", default="outputs/godot_s00_20260926_final")
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    out = safe_path(args.out)
    if not out.name.startswith("godot_s00_") or out.parent != ROOT / "outputs":
        raise ValueError("Output must be a direct outputs/godot_s00_* directory")
    verify(out) if args.verify else capture(out)


if __name__ == "__main__":
    main()
