"""Atomically publish the 3D world bundle to the mafiozy main branch.

Unlike one-file Contents API uploaders, this creates one Git tree/commit for
``world.html``, ``three_preview.js`` and the optimization memory. Updating the
ref without force makes the operation fail safely if another agent advances
``main`` while the upload is being prepared.
"""

from __future__ import annotations

import base64
import hashlib
import json
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path


REPO = "slavaprivet/mafiozy"
BRANCH = "main"
FILES = (
    "world.html",
    "three_preview.js",
    "docs/ai/OPTIMIZATION_MEMORY.md",
)
ROOT = Path(__file__).resolve().parent


def find_token() -> str:
    directory = ROOT
    for _ in range(7):
        candidate = directory / ".token"
        if candidate.exists():
            token = candidate.read_text(encoding="utf-8").strip()
            if token:
                return token
        directory = directory.parent
    raise RuntimeError(".token not found in the worktree or parent project")


TOKEN = find_token()


def api(method: str, path: str, body: dict | None = None) -> tuple[dict, int]:
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(
        "https://api.github.com" + path, data=data, method=method
    )
    request.add_header("Authorization", "Bearer " + TOKEN)
    request.add_header("Accept", "application/vnd.github+json")
    request.add_header("X-GitHub-Api-Version", "2022-11-28")
    request.add_header("User-Agent", "mafiozi-atomic-3d-uploader")
    if data is not None:
        request.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            payload = response.read()
            return (json.loads(payload) if payload else {}), response.status
    except urllib.error.HTTPError as error:
        payload = error.read()
        try:
            detail = json.loads(payload)
        except Exception:
            detail = {"message": payload.decode("utf-8", "replace")}
        raise RuntimeError(
            f"GitHub HTTP {error.code}: {detail.get('message', detail)}"
        ) from error


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


def publish(message: str) -> str:
    validate_sources()
    ref, _ = api("GET", f"/repos/{REPO}/git/ref/heads/{BRANCH}")
    base_sha = ref["object"]["sha"]
    ancestry = subprocess.run(
        ["git", "merge-base", "--is-ancestor", base_sha, "HEAD"],
        cwd=ROOT,
        check=False,
    )
    if ancestry.returncode != 0:
        raise RuntimeError(
            f"remote {BRANCH} {base_sha[:12]} is not in local history; "
            "fetch/rebase before publishing"
        )
    base_commit, _ = api("GET", f"/repos/{REPO}/git/commits/{base_sha}")
    entries: list[dict] = []
    local_hashes: dict[str, str] = {}

    for relative in FILES:
        raw = (ROOT / relative).read_bytes()
        blob, _ = api(
            "POST",
            f"/repos/{REPO}/git/blobs",
            {"content": base64.b64encode(raw).decode(), "encoding": "base64"},
        )
        entries.append(
            {"path": relative, "mode": "100644", "type": "blob", "sha": blob["sha"]}
        )
        local_hashes[relative] = hashlib.sha256(raw).hexdigest()

    tree, _ = api(
        "POST",
        f"/repos/{REPO}/git/trees",
        {"base_tree": base_commit["tree"]["sha"], "tree": entries},
    )
    commit, _ = api(
        "POST",
        f"/repos/{REPO}/git/commits",
        {"message": message, "tree": tree["sha"], "parents": [base_sha]},
    )
    api(
        "PATCH",
        f"/repos/{REPO}/git/refs/heads/{BRANCH}",
        {"sha": commit["sha"], "force": False},
    )

    for entry in entries:
        blob, _ = api("GET", f"/repos/{REPO}/git/blobs/{entry['sha']}")
        remote = base64.b64decode(blob["content"])
        if hashlib.sha256(remote).hexdigest() != local_hashes[entry["path"]]:
            raise RuntimeError(f"verification failed for {entry['path']}")
    return commit["sha"]


if __name__ == "__main__":
    commit_message = " ".join(sys.argv[1:]).strip() or "Update 3D world bundle"
    try:
        commit_sha = publish(commit_message)
    except Exception as error:
        print(f"[!] Upload aborted: {error}")
        raise SystemExit(1)
    print(f"UPLOAD OK: {REPO}@{BRANCH} {commit_sha}")
    print("Verified: " + ", ".join(FILES))
