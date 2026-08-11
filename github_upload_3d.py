"""Atomically publish the 3D world bundle to the mafiozy main branch.

Unlike one-file Contents API uploaders, this creates one Git tree/commit for
``world.html``, ``three_preview.js`` and the optimization memory. Updating the
ref without force makes the operation fail safely if another agent advances
``main`` while the upload is being prepared.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

from github_publish_safe import BRANCH, REPO, publish_files


FILES = (
    "world.html",
    "three_preview.js",
    "docs/ai/OPTIMIZATION_MEMORY.md",
)
ROOT = Path(__file__).resolve().parent

def validate_sources() -> None:
    missing = [relative for relative in FILES if not (ROOT / relative).is_file()]
    if missing:
        raise RuntimeError("missing publish files: " + ", ".join(missing))
    subprocess.run(
        ["node", "--check", str(ROOT / "three_preview.js")], check=True
    )
    try:
        from check_world import check_html_js
    except ImportError:
        return
    if check_html_js(str(ROOT / "world.html")) != 0:
        raise RuntimeError("world.html JavaScript validation failed")


def publish(message: str) -> tuple[str, tuple[str, ...]]:
    validate_sources()
    return publish_files(FILES, message)


if __name__ == "__main__":
    commit_message = " ".join(sys.argv[1:]).strip() or "Update 3D world bundle"
    try:
        commit_sha, changed = publish(commit_message)
    except Exception as error:
        print(f"[!] Upload aborted: {error}")
        raise SystemExit(1)
    print(f"UPLOAD OK: {REPO}@{BRANCH} {commit_sha}")
    print("Verified changed files: " + ", ".join(changed))
