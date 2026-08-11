"""Safely publish the committed character creator."""

from github_publish_safe import BRANCH, REPO, publish_files


try:
    commit_sha, changed = publish_files(
        ("creator.html",), "Update character creator safely"
    )
except Exception as error:
    print(f"[!] Upload aborted: {error}")
    raise SystemExit(1)

print(f"UPLOAD OK: {REPO}@{BRANCH} {commit_sha}")
print("Verified changed files: " + ", ".join(changed))
