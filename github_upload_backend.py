"""Atomically publish committed backend files without overwriting newer main."""

from __future__ import annotations

import sys

from github_publish_safe import BRANCH, REPO, publish_files


FILES = tuple(sys.argv[1:]) or (
    "weapon_balance.py",
    "mafiozi_bot.py",
    "npc_empire.py",
    "_preview_ws_server.py",
)


if any("::" in value for value in FILES):
    raise SystemExit(
        "remote path remapping is disabled: publish the committed repository path"
    )

message = (
    f"Update shared backend files: {', '.join(FILES)}"
    if len(FILES) > 1
    else f"Update shared backend file: {FILES[0]}"
)
try:
    commit_sha, changed = publish_files(FILES, message)
except Exception as error:
    print(f"[!] Upload aborted: {error}")
    raise SystemExit(1)

print(f"BACKEND UPLOAD OK: {REPO}@{BRANCH} {commit_sha}")
print("Verified changed files: " + ", ".join(changed))
