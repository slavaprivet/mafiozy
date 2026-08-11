"""Safely publish the committed world.html on top of the current main."""

from __future__ import annotations

import datetime
import sys
from pathlib import Path

from check_world import check_html_js
from github_publish_safe import BRANCH, REPO, ROOT, publish_files


WORLD = (ROOT / "world.html").resolve()


def main() -> int:
    requested = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else WORLD
    if requested != WORLD:
        raise RuntimeError(
            "Unsafe source refused: publish the committed world.html from this "
            "repository, not an external or stale copy."
        )

    print("[1/2] Checking JavaScript syntax...")
    if check_html_js(str(WORLD)) != 0:
        print("[!] Syntax check failed; publication cancelled.")
        return 3

    stamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[2/2] Publishing committed world.html atomically to {REPO}:{BRANCH}...")
    commit_sha, changed = publish_files(
        ("world.html",), f"world.html build {stamp}"
    )
    print(f"UPLOAD OK: {commit_sha}")
    print("Published: " + ", ".join(changed))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RuntimeError as exc:
        print(f"[!] {exc}", file=sys.stderr)
        raise SystemExit(2)
