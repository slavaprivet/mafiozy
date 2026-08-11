"""Safely publish the committed game hub."""

from github_publish_safe import BRANCH, REPO, publish_files


try:
    commit_sha, changed = publish_files(("hub.html",), "Update game hub safely")
except Exception as error:
    print(f"[!] Upload aborted: {error}")
    raise SystemExit(1)

print(f"UPLOAD OK: {REPO}@{BRANCH} {commit_sha}")
print("Verified changed files: " + ", ".join(changed))
