"""Merge-safe GitHub tree publisher for the Mafiozi main branch."""

from __future__ import annotations

import base64
import hashlib
import json
import subprocess
import urllib.error
import urllib.request
from pathlib import Path


REPO = "slavaprivet/mafiozy"
BRANCH = "main"
ROOT = Path(__file__).resolve().parent


def _git(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args], cwd=ROOT, check=check, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )


def _find_token() -> str:
    candidates = [ROOT / ".token", Path.home() / "Desktop" / "Мафиози" / ".token"]
    candidates.extend(parent / ".token" for parent in list(ROOT.parents)[:7])
    for candidate in candidates:
        if candidate.is_file():
            token = candidate.read_text(encoding="utf-8").strip()
            if token:
                return token
    raise RuntimeError(".token not found in the worktree or main project")


def _api(token: str, method: str, path: str, body: dict | None = None) -> dict:
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(
        "https://api.github.com" + path, data=data, method=method,
    )
    request.add_header("Authorization", "Bearer " + token)
    request.add_header("Accept", "application/vnd.github+json")
    request.add_header("X-GitHub-Api-Version", "2022-11-28")
    request.add_header("User-Agent", "mafiozi-merge-safe-publisher")
    if data is not None:
        request.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            payload = response.read()
            return json.loads(payload) if payload else {}
    except urllib.error.HTTPError as error:
        payload = error.read()
        try:
            detail = json.loads(payload)
        except Exception:
            detail = {"message": payload.decode("utf-8", "replace")}
        raise RuntimeError(
            f"GitHub HTTP {error.code}: {detail.get('message', detail)}"
        ) from error


def _repo_paths(files: tuple[str, ...] | list[str]) -> tuple[str, ...]:
    paths: list[str] = []
    for value in files:
        path = (ROOT / value).resolve()
        try:
            relative = path.relative_to(ROOT).as_posix()
        except ValueError as error:
            raise RuntimeError(f"publish path is outside repository: {value}") from error
        if not path.is_file():
            raise RuntimeError(f"missing publish file: {relative}")
        paths.append(relative)
    return tuple(dict.fromkeys(paths))


def publish_files(files: tuple[str, ...] | list[str], message: str) -> tuple[str, tuple[str, ...]]:
    """Publish only committed target-file changes on top of the exact remote HEAD."""
    paths = _repo_paths(files)
    dirty = _git("status", "--porcelain", "--", *paths).stdout.strip()
    if dirty:
        raise RuntimeError(
            "refusing to publish uncommitted target files; commit them first:\n" + dirty
        )

    token = _find_token()
    ref = _api(token, "GET", f"/repos/{REPO}/git/ref/heads/{BRANCH}")
    base_sha = ref["object"]["sha"]
    if _git("merge-base", "--is-ancestor", base_sha, "HEAD", check=False).returncode:
        raise RuntimeError(
            f"remote {BRANCH} {base_sha[:12]} is not in local history; "
            "fetch and rebase before publishing"
        )

    changed_output = _git("diff", "--name-only", f"{base_sha}..HEAD", "--", *paths).stdout
    changed = tuple(line.strip() for line in changed_output.splitlines() if line.strip())
    if not changed:
        raise RuntimeError("none of the requested files changed after remote main")

    base_commit = _api(token, "GET", f"/repos/{REPO}/git/commits/{base_sha}")
    entries: list[dict] = []
    local_hashes: dict[str, str] = {}
    for relative in changed:
        raw = subprocess.check_output(["git", "show", f"HEAD:{relative}"], cwd=ROOT)
        blob = _api(token, "POST", f"/repos/{REPO}/git/blobs", {
            "content": base64.b64encode(raw).decode(), "encoding": "base64",
        })
        entries.append({"path": relative, "mode": "100644", "type": "blob", "sha": blob["sha"]})
        local_hashes[relative] = hashlib.sha256(raw).hexdigest()

    tree = _api(token, "POST", f"/repos/{REPO}/git/trees", {
        "base_tree": base_commit["tree"]["sha"], "tree": entries,
    })
    commit = _api(token, "POST", f"/repos/{REPO}/git/commits", {
        "message": message, "tree": tree["sha"], "parents": [base_sha],
    })
    _api(token, "PATCH", f"/repos/{REPO}/git/refs/heads/{BRANCH}", {
        "sha": commit["sha"], "force": False,
    })

    for entry in entries:
        blob = _api(token, "GET", f"/repos/{REPO}/git/blobs/{entry['sha']}")
        remote = base64.b64decode(blob["content"])
        if hashlib.sha256(remote).hexdigest() != local_hashes[entry["path"]]:
            raise RuntimeError(f"verification failed for {entry['path']}")
    return commit["sha"], changed
