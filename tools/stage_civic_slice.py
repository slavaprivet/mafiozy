"""Prepare, but NEVER stage, a civic-only candidate from the mixed worktree.

Run after all writers have paused. The default output is a fresh UUID directory
under D:/codex_release/civic_preview_release_20260907. --check-only performs the
same extraction without writing outputs. Originals and Git's index are read-only.

The three mixed tracked files and vehicle surface fixture are patched. New civic files are copied into
candidate/ and listed in manifest.json, not encoded as a giant binary patch.
This is an extraction aid, NOT a completeness or gameplay approval certificate.
"""
from __future__ import annotations

import argparse
import difflib
import hashlib
import json
import re
import subprocess
import uuid
from datetime import datetime, timezone
from pathlib import Path


MIXED = ("world.html", "three_preview.js", "_preview_ws_server.py")
TRACKED_FIXTURES = ("test_vehicle_surface_capability.py",)
RAIL_SYMBOL = re.compile(r"(?:_cityV3Rail|cityV3Rail|CityV3Rail|CITY_V3_RAIL|/assets/rail/)")
CIVIC_WORD = re.compile(r"decor|civic", re.I)


def git(repo: Path, *args: str) -> bytes:
    return subprocess.run(["git", *args], cwd=repo, check=True, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE).stdout


def decoded(raw: bytes) -> str:
    return raw.decode("utf-8").replace("\r\n", "\n")


def sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def unique_index(lines: list[str], predicate, label: str) -> int:
    found = [i for i, line in enumerate(lines) if predicate(line)]
    if len(found) != 1:
        raise ValueError(f"{label}: expected exactly one anchor, found {len(found)}")
    return found[0]


def select_lines(path: str, lines: list[str]) -> set[int]:
    selected: set[int] = set()

    def one(prefix: str) -> int:
        i = unique_index(lines, lambda line: line.strip().startswith(prefix), path + ":" + prefix)
        selected.add(i)
        return i

    def span(start: str, end: str, include_end: bool = False):
        a = unique_index(lines, lambda line: line.strip().startswith(start), path + ":" + start)
        b = unique_index(lines, lambda line: line.strip().startswith(end), path + ":" + end)
        if b <= a:
            raise ValueError(f"{path}: reversed extraction span {start} / {end}")
        selected.update(range(a, b + int(include_end)))

    if path == "world.html":
        one('<script type="importmap">')
        one("const _cityV3DecorBodies=")
        one("const _cityV3DecorPreparedCells=")
        span("// Approved civic decor", "window.Mafiozi3DBridge = Object.freeze({")
        span("getCityV3DecorHost(){", "previewApproachCityV3Decor(focus){", True)
        one("getCityV3DecorGardenLots(){")
        hooks = [i for i, line in enumerate(lines)
                 if line.strip() == "if(_cityV3DecorBlocked(r,c))return true;"]
        expected = {"_serviceVehicleBodyPointBlocked", "isBlocked", "isBlockedCar", "isBlockedPed"}
        owners = set()
        for i in hooks:
            preceding = [line for line in lines[:i] if line.startswith("function ")]
            if not preceding:
                raise ValueError("civic collision hook has no enclosing function")
            owners.add(re.match(r"function (\w+)", preceding[-1]).group(1))
        if len(hooks) != 4 or owners != expected:
            raise ValueError(f"civic collision hooks changed: count={len(hooks)}, owners={owners}")
        selected.update(hooks)
        i = one("if(_cityV3DecorPreparedCells.has(")
        preceding = [line for line in lines[:i] if line.startswith("function ")]
        if not preceding[-1].startswith("function _cityV3SuppressLegacyDoor("):
            raise ValueError("prepared-cell door suppression is in an unexpected function")
    elif path == "three_preview.js":
        one("const cityV3DecorPreviewRequested=")
        span("let cityV3DecorInstance=", "let cityV3BuildingInstance=")
        one("if (!document.body.contains(renderer.domElement)) {disposeCityV3Decor();return;}")
        one("if(fullMaterialsReady)startCityV3Decor();")
        one("cityV3DecorInstance?.update(")
        one("const fixedLampDefs=[],addLampDef=")
    elif path == "_preview_ws_server.py":
        span("CITY_V3_DECOR_ASSET_ROOT = (", "async def preview_city_v3_asset(req):")
        one('app.router.add_get("/assets/decor/civic_park_v2/{tail:.*}",')
    else:
        raise ValueError(f"unsupported mixed file: {path}")
    for i in selected:
        if RAIL_SYMBOL.search(lines[i]):
            raise ValueError(f"rail dependency leaked into selected civic span: {path}:{i+1}")
    return selected


def extract(path: str, base: str, working: str) -> tuple[str, dict]:
    # Compare normalized lines, but retain exact HEAD line endings for every
    # unchanged/excluded line. The preview server has mixed LF/CRLF in HEAD.
    old_exact = base.splitlines(keepends=True)
    old = [line.replace("\r\n", "\n") for line in old_exact]
    new = working.splitlines(keepends=True)
    selected = select_lines(path, new)
    output, decisions = [], []
    matcher = difflib.SequenceMatcher(a=old, b=new, autojunk=False)
    for operation, a, b, c, d in matcher.get_opcodes():
        if operation == "equal":
            output.extend(old_exact[a:b])
            continue
        chosen = [i for i in range(c, d) if i in selected]
        # Any newly changed civic line outside our known semantic selections
        # requires a human review and an extractor update.
        unexpected = [i for i in range(c, d) if i not in selected and CIVIC_WORD.search(new[i])]
        if unexpected:
            raise ValueError(f"unclassified civic change: {path}:{unexpected[0]+1}: {new[unexpected[0]].strip()}")
        if operation == "insert":
            output.extend(new[i] for i in chosen)
        elif chosen:
            # Two exact one-line replacements are authorized: renderer cleanup
            # and skipping the existing streetlamp grid inside civic gardens.
            cleanup = (b-a == 1 and d-c == 1
                       and old[a].strip() == "if (!document.body.contains(renderer.domElement)) return;"
                       and new[c].strip() == "if (!document.body.contains(renderer.domElement)) {disposeCityV3Decor();return;}")
            lamps = (b-a == 1 and d-c == 1
                     and old[a].strip().startswith("const fixedLampDefs=[],addLampDef=")
                     and new[c] == old[a].replace("if(snapshotStyleAt(", "if(cityV3DecorGardenAt(r,c)||snapshotStyleAt(", 1))
            if path != "three_preview.js" or len(chosen) != 1 or not (cleanup or lamps):
                raise ValueError(f"new/mixed replacement needs manual review: {path}:{c+1}")
            output.extend(new[c:d])
        else:
            if any(CIVIC_WORD.search(line) for line in old[a:b]):
                raise ValueError(f"deleted/changed existing civic code needs review: {path}:{a+1}")
            output.extend(old_exact[a:b])
        decisions.append({"operation": operation, "headRange": [a+1,b],
                          "workRange": [c+1,d], "selectedWorkLines": [i+1 for i in chosen]})
    candidate = "".join(output)
    if candidate == base:
        raise ValueError(f"no civic changes extracted for {path}")
    for line in difflib.unified_diff(old_exact, candidate.splitlines(keepends=True)):
        if line.startswith("+") and not line.startswith("+++") and RAIL_SYMBOL.search(line):
            raise ValueError(f"rail code in candidate diff for {path}")
    return candidate, {"decisions": decisions, "headSha256": sha(base.encode()),
                       "workNormalizedSha256": sha(working.encode()),
                       "candidateSha256": sha(candidate.encode())}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output-root", type=Path,
                        default=Path("D:/codex_release/civic_preview_release_20260907"))
    parser.add_argument("--check-only", action="store_true")
    parser.add_argument("--refresh-from", type=Path,
                        help="Reuse verified byte-exact mixed files from an earlier output; refresh only civic assets/tests")
    args = parser.parse_args()
    repo = args.repo.resolve()
    head = git(repo, "rev-parse", "HEAD").decode().strip()
    index_before = git(repo, "diff", "--cached", "--binary", "--no-ext-diff")
    original_bytes = {path: (repo/path).read_bytes() for path in (TRACKED_FIXTURES if args.refresh_from else MIXED + TRACKED_FIXTURES)}
    candidates, reports, patch_parts = {}, {}, []
    frozen = None
    if args.refresh_from:
        frozen = json.loads((args.refresh_from/"manifest.json").read_text(encoding="utf-8"))
        if frozen["head"] != head:
            raise ValueError("frozen candidate HEAD differs; review/rebase explicitly")
    for path in MIXED + TRACKED_FIXTURES:
        base = git(repo, "show", f"{head}:{path}").decode("utf-8")
        if path in TRACKED_FIXTURES:
            candidate = original_bytes[path].decode("utf-8")
            report = {"kind": "reviewed-civic-fixture", "headSha256": sha(base.encode()),
                      "candidateSha256": sha(original_bytes[path])}
        elif frozen:
            raw = (args.refresh_from/"candidate"/path).read_bytes()
            report = frozen["mixedFiles"][path]
            if sha(raw) != report["candidateSha256"]:
                raise ValueError(f"frozen candidate hash differs: {path}")
            candidate = raw.decode("utf-8")
        else:
            candidate, report = extract(path, base, decoded(original_bytes[path]))
        candidates[path], reports[path] = candidate.encode("utf-8"), report
        patch_parts.append(f"diff --git a/{path} b/{path}\n" + "".join(difflib.unified_diff(
            base.splitlines(keepends=True), candidate.splitlines(keepends=True),
            fromfile=f"a/{path}", tofile=f"b/{path}", n=3)))
    civic_root = repo/"assets/decor/civic_park_v2"
    if not civic_root.is_dir():
        raise ValueError("civic asset directory is missing")
    additional = sorted([path for path in civic_root.rglob("*")
                         if path.is_file() and "__pycache__" not in path.parts and path.suffix != ".pyc"]
                        + list(repo.glob("test_city_v3_civic_park_decor*.py"))
                        + [repo/"test_city_v3_decor_gameplay.py"])
    if not additional:
        raise ValueError("no civic assets/tests found")
    extras = {path.relative_to(repo).as_posix(): path.read_bytes() for path in additional}
    patch = "".join(patch_parts).encode("utf-8")
    # Freeze check immediately before writing candidate artifacts.
    if head != git(repo, "rev-parse", "HEAD").decode().strip():
        raise ValueError("HEAD changed during extraction; pause writers and retry")
    if index_before != git(repo, "diff", "--cached", "--binary", "--no-ext-diff"):
        raise ValueError("index changed during extraction; pause writers and retry")
    for path, raw in {**original_bytes, **extras}.items():
        if (repo/path).read_bytes() != raw:
            raise ValueError(f"source changed during extraction: {path}; pause writers and retry")
    manifest = {"status": "EXTRACTED_NOT_TESTED_NOT_STAGED", "head": head,
                "createdAt": datetime.now(timezone.utc).isoformat(), "mixedFiles": reports,
                "additionalCivicFiles": {path: {"bytes": len(raw), "sha256": sha(raw)} for path, raw in extras.items()},
                "patchSha256": sha(patch), "indexChangedByThisScript": False,
                "frozenMixedSource": str(args.refresh_from) if args.refresh_from else None,
                "instructions": "Patch covers three tracked mixed files plus the reviewed vehicle surface fixture. candidate/ also contains copied civic assets/tests. Review/test an isolated HEAD tree plus these candidates before staging; no rail or next-building files were copied."}
    if args.check_only:
        print(json.dumps({"status": manifest["status"], "head": head,
                          "mixedFiles": list(candidates), "additionalFiles": len(extras)}, indent=2))
        return 0
    parent = args.output_root.resolve()
    if parent == repo or repo in parent.parents:
        raise ValueError("output must be outside the source repository")
    target = parent/(datetime.now(timezone.utc).strftime("%H%M%S") + "-" + uuid.uuid4().hex[:10])
    target.mkdir(parents=True, exist_ok=False)
    for path, raw in {**candidates, **extras}.items():
        destination = target/"candidate"/path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(raw)
    (target/"civic-only.patch").write_bytes(patch)
    (target/"manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False)+"\n", encoding="utf-8")
    print(str(target))
    print("EXTRACTED ONLY: original files and Git index were not changed; isolated tests still required.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, subprocess.CalledProcessError) as error:
        raise SystemExit(f"Civic extraction refused: {error}")
