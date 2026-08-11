"""Safely publish the committed battle entry files.

The legacy uploader copied battle.html over index.html. Both paths are tracked
independently now, so publishing preserves their committed contents.
"""

from github_publish_safe import BRANCH, REPO, publish_files


try:
    commit_sha, changed = publish_files(
        ("battle.html", "index.html"), "Update battle entry files safely"
    )
except Exception as error:
    print(f"[!] Upload aborted: {error}")
    raise SystemExit(1)

print(f"UPLOAD OK: {REPO}@{BRANCH} {commit_sha}")
print("Verified changed files: " + ", ".join(changed))
