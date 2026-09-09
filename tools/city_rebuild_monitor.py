"""Loopback-only read-only monitor. Serves two allowlisted routes, never repository files."""
from __future__ import annotations
import argparse
import hashlib
import json
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PAGE = ROOT / "tools/city_rebuild_monitor.html"
WORK = ROOT / "assets/maps/city_rebuild_v1"


def read_record(path):
    try:
        raw = path.read_bytes()
        return {"data": json.loads(raw.decode("utf-8-sig")),
                "sha256": hashlib.sha256(raw).hexdigest(),
                "modified": datetime.fromtimestamp(path.stat().st_mtime, timezone.utc).isoformat()}
    except (OSError, ValueError) as exc:
        return {"data": None, "error": type(exc).__name__}


def snapshot(plan, addendum):
    ledger = read_record(ROOT / "docs/city-rebuild/rebuild-ledger.generated.json")
    candidates = []
    for path in WORK.glob("*.json"):
        record = read_record(path)
        data = record["data"]
        if isinstance(data, dict) and "grid" in data and "validation" in data:
            candidates.append({"name": path.name, **record})
    candidates.sort(key=lambda item: item.get("modified", ""), reverse=True)
    modules = []
    for name, title in [("topology.mjs", "Сетка воды и дорог"),
                        ("addendum.mjs", "Уточнение берегов и мостов"),
                        ("gameplay_migration.mjs", "Перенос игровых объектов"),
                        ("decor_placement.mjs", "Расстановка 3D-декора")]:
        path = WORK / name
        modules.append({"title": title, "exists": path.is_file(),
                        "modified": datetime.fromtimestamp(path.stat().st_mtime, timezone.utc).isoformat() if path.is_file() else None})
    return {"observedAt": datetime.now(timezone.utc).isoformat(),
            "mode": "READ_ONLY_REBUILD_MONITOR_NOT_GAME", "plan": read_record(plan),
            "addendum": read_record(addendum), "ledger": ledger,
            "candidate": candidates[0] if candidates else None, "modules": modules,
            "placement": {name: read_record(WORK / filename) for name, filename in
                          [("buildings", "buildings_placement.v1.json"),
                           ("decor", "decor_placement.v1.json")]}}


def asset_path(route):
    """No directory browsing, external paths or traversal, including symlinks."""
    from urllib.parse import unquote
    roots = {"/assets/maps/city_rebuild_v1/": WORK,
             "/assets/rail/city_v3/": ROOT / "assets/rail/city_v3",
             "/assets/decor/civic_park_v2/": ROOT / "assets/decor/civic_park_v2",
             "/assets/buildings/city_v3/": ROOT / "assets/buildings/city_v3"}
    route = unquote(route)
    # Explicit public presentation entry points; never expose saves, server code or DB.
    pages = {"/world.html": "world.html", "/world_walk_host.mjs": "world_walk_host.mjs",
             "/three_preview.js": "three_preview.js", "/character_3d_preview.js": "character_3d_preview.js",
             "/tools/city_rebuild_walk.html": "tools/city_rebuild_walk.html"}
    if route in pages:
        candidate = ROOT / pages[route]
        return candidate if candidate.is_file() else None
    for prefix, directory in roots.items():
        if route.startswith(prefix):
            relative = route[len(prefix):]
            candidate = (directory / relative).resolve()
            if (candidate.is_relative_to(directory.resolve()) and candidate.is_file()
                    and candidate.suffix.lower() in {".mjs", ".js", ".css", ".json", ".glb", ".png", ".jpg", ".webp"}):
                return candidate
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plan", default=WORK / "topology_for_placement.json", type=Path)
    parser.add_argument("--addendum", default=WORK / "topology_for_placement.json", type=Path)
    parser.add_argument("--port", default=18538, type=int)
    args = parser.parse_args()

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            route = self.path.split("?", 1)[0]
            if route == "/":
                payload, mime = PAGE.read_bytes(), "text/html; charset=utf-8"
            elif route == "/walk":
                payload, mime = (ROOT / "tools/city_rebuild_walk.html").read_bytes(), "text/html; charset=utf-8"
            elif route == "/snapshot":
                payload = json.dumps(snapshot(args.plan, args.addendum), ensure_ascii=False).encode("utf-8")
                mime = "application/json; charset=utf-8"
            else:
                path = asset_path(route)
                if path is None:
                    self.send_error(404)
                    return
                payload = path.read_bytes()
                mime = {".html": "text/html; charset=utf-8", ".mjs": "text/javascript", ".js": "text/javascript", ".css": "text/css; charset=utf-8",
                        ".json": "application/json", ".glb": "model/gltf-binary",
                        ".png": "image/png", ".jpg": "image/jpeg", ".webp": "image/webp"}[path.suffix.lower()]
            self.send_response(200)
            self.send_header("Content-Type", mime)
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

        def log_message(self, *_):
            pass

    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    print(f"Read-only rebuild monitor: http://127.0.0.1:{args.port}/", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
