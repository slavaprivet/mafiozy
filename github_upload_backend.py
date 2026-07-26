"""Upload authoritative world backend files through the GitHub Contents API."""
import base64
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
TOKEN_PATH = os.path.join(HERE, ".token")
REPO = "slavaprivet/mafiozy"
BRANCH = "main"
FILES = ("mafiozi_bot.py", "_preview_ws_server.py")


def request(method, path, body=None):
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request("https://api.github.com" + path, data=data, method=method)
    req.add_header("Authorization", "token " + TOKEN)
    req.add_header("Accept", "application/vnd.github.v3+json")
    req.add_header("User-Agent", "mafiozi-backend-uploader")
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=45) as response:
            return json.loads(response.read()), response.status
    except urllib.error.HTTPError as exc:
        return json.loads(exc.read()), exc.code


with open(TOKEN_PATH, "r", encoding="utf-8") as token_file:
    TOKEN = token_file.read().strip()
if not TOKEN.startswith("ghp_"):
    raise SystemExit("Invalid .token")

uploaded = []
for filename in FILES:
    path = os.path.join(HERE, filename)
    with open(path, "rb") as source:
        raw = source.read()
    local_hash = hashlib.sha256(raw).hexdigest()
    remote, status = request("GET", f"/repos/{REPO}/contents/{filename}?ref={BRANCH}")
    if status not in (200, 404):
        raise SystemExit(f"GET {filename}: HTTP {status}: {remote.get('message')}")
    payload = {
        "message": f"Update shared world backend: {filename}",
        "content": base64.b64encode(raw).decode("ascii"),
        "branch": BRANCH,
    }
    if status == 200:
        payload["sha"] = remote["sha"]
    result, put_status = request("PUT", f"/repos/{REPO}/contents/{filename}", payload)
    if put_status not in (200, 201):
        raise SystemExit(f"PUT {filename}: HTTP {put_status}: {result.get('message')}")
    uploaded.append((filename, result["content"]["sha"], result["commit"]["sha"], local_hash))
    print(f"UPLOAD {filename}: HTTP {put_status}, commit {result['commit']['sha'][:12]}")

time.sleep(2)
for filename, blob_sha, commit_sha, local_hash in uploaded:
    remote, status = request("GET", f"/repos/{REPO}/git/blobs/{blob_sha}")
    if status != 200:
        raise SystemExit(f"VERIFY {filename}: HTTP {status}")
    decoded = base64.b64decode(remote.get("content", ""))
    if hashlib.sha256(decoded).hexdigest() != local_hash:
        raise SystemExit(f"VERIFY {filename}: SHA-256 mismatch")
    print(f"VERIFY {filename}: OK blob {blob_sha[:12]} commit {commit_sha[:12]}")

print("BACKEND UPLOAD OK")
