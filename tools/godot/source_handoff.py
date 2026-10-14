"""Collect explicit source roots without modifying them; verify portable ZIP bytes.

This is transport evidence, never Godot/functional/performance acceptance.
All dependencies outside the game must be declared by its source owner.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import stat
import zipfile
from pathlib import Path, PurePosixPath

SCHEMA = "mafiozi.source-handoff/v1"
SKIP_DIRS = {".git", ".godot", "__pycache__", "node_modules", ".venv", "venv", "cache", "logs"}
SKIP_SUFFIXES = {".log", ".pyc", ".pyo", ".tmp", ".bak"}
SECRET_NAMES = {"secrets.py", "secrets_local.py", "credentials.json", "tokens.txt", "secrets.json"}
SECRET_NAMES |= {".aws", ".azure", "credentials", ".npmrc", ".pypirc", ".netrc", "gh", "gcloud"}
SECRET_BYTES = re.compile(rb"-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----|\bgh[pousr]_[A-Za-z0-9]{30,}|\bgithub_pat_[A-Za-z0-9_]{30,}")


def digest(data):
    return hashlib.sha256(data).hexdigest()


def relative(value):
    p = PurePosixPath(value)
    if not value or "\\" in value or ":" in value or p.is_absolute() or any(x in {".", "..", ""} for x in value.split("/")):
        raise ValueError("Unsafe relative path")
    for part in p.parts:
        if part.endswith((".", " ")) or any(ord(c) < 32 or c in '<>"|?*' for c in part) or re.fullmatch(r"(?i)(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\..*)?", part):
            raise ValueError("Unsafe Windows path component")
    return p.as_posix()


def excluded(parts):
    return any(p.lower() in SKIP_DIRS for p in parts) or Path(parts[-1]).suffix.lower() in SKIP_SUFFIXES


def secret_name(parts):
    for part in parts:
        name = part.lower()
        if name in SECRET_NAMES or name == ".ssh" or name == ".gh-cli-auth" or name == ".env" or name.endswith(".env") or name.startswith(".env.") or name in {".token", ".bot-token"} or ("token" in name and name.endswith(".txt")) or name.endswith((".pem", ".key", ".pfx")):
            return True
    return False


def read_source(path):
    if path.is_symlink() or path.is_junction():
        raise ValueError("Links/junctions are not portable sources")
    data = path.read_bytes()
    if SECRET_BYTES.search(data):
        raise ValueError("Credential-like bytes found; source must be reviewed")
    return data


def inventory(spec):
    files, roots, skipped = {}, [], []
    anchor = None
    for item in spec["roots"]:
        label = relative(item["label"])
        if label.casefold() in {x["label"].casefold() for x in roots}:
            raise ValueError("Root labels must be unique")
        source = Path(item["source"]).resolve(strict=True)
        if excluded(source.parts) or secret_name(source.parts) or excluded(PurePosixPath(label).parts) or secret_name(PurePosixPath(label).parts):
            raise ValueError("Forbidden source root")
        inferred_anchor = source
        for _ in PurePosixPath(label).parts:
            inferred_anchor = inferred_anchor.parent
        if inferred_anchor / Path(label) != source or (anchor is not None and inferred_anchor != anchor):
            raise ValueError("Roots must preserve relative layout beneath one common anchor")
        anchor = inferred_anchor
        if Path(item["source"]).is_symlink() or Path(item["source"]).is_junction():
            raise ValueError("Source root is a link")
        if not source.is_dir():
            raise ValueError("Source root must be a directory")
        entry = relative(item["entry"]) if item.get("entry") else None
        if item["role"] == "game" and (not entry or not (source / "project.godot").is_file()):
            raise ValueError("Game requires project.godot and an explicit entry scene")
        selected = item.get("files")
        candidates = [source / relative(p) for p in selected] if selected is not None else list(source.rglob("*"))
        for path in sorted(candidates):
            rel = path.relative_to(source)
            if excluded(rel.parts):
                if path.is_file():
                    skipped.append(f"{label}/{rel.as_posix()}")
                continue
            if path.is_symlink() or path.is_junction():
                raise ValueError("Source contains a link/junction")
            if not path.resolve().is_relative_to(source) or any(p.is_symlink() or p.is_junction() for p in path.parents if p != source and p.is_relative_to(source)):
                raise ValueError("Source traverses a link/outside root")
            if not path.is_file():
                if selected is not None:
                    raise ValueError("Explicit source file missing")
                continue
            if secret_name(rel.parts):
                raise ValueError("Source contains a credential filename; narrow the root")
            name = relative(f"{label}/{rel.as_posix()}")
            if name in files and files[name] == path:
                continue
            if name.casefold() in {n.casefold() for n in files}:
                raise ValueError("Case-insensitive duplicate path")
            files[name] = path
        if entry and f"{label}/{entry}" not in files:
            raise ValueError("Declared entry missing from payload")
        roots.append({"label": label, "role": item["role"], "entry": entry})
    if not files or not any(r["role"] == "game" for r in roots):
        raise ValueError("A game source is required")
    return files, roots, skipped


def collect(spec_path, output):
    spec = json.loads(spec_path.read_text("utf-8-sig"))
    if not spec.get("owner_declares_dependencies_complete"):
        raise ValueError("Source owner must declare dependency closure; do not guess roots")
    files, roots, skipped = inventory(spec)
    output = output.resolve()
    if output.exists() or any(output.is_relative_to(Path(r["source"]).resolve()) for r in spec["roots"]):
        raise ValueError("Output must be new and outside every source root")
    pins = {}
    for name, path in files.items():
        data = read_source(path)
        pins[name] = {"sha256": digest(data), "size": len(data)}
    for name, expected in spec.get("expected_pins", {}).items():
        if pins.get(relative(name), {}).get("sha256") != expected:
            raise ValueError("Expected source pin mismatch: " + name)
    manifest = {"schema": SCHEMA, "source_identity": spec["source_identity"], "roots": roots,
                "files": pins, "excluded": skipped, "owner_declares_dependencies_complete": True,
                "acceptance": "TRANSPORT_ONLY_NOT_GODOT_ACCEPTANCE"}
    output.parent.mkdir(parents=True, exist_ok=True)
    owned_output = output.open("xb")
    try:
        with owned_output, zipfile.ZipFile(owned_output, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as bundle:
            for name, path in files.items():
                data = read_source(path)
                if digest(data) != pins[name]["sha256"]:
                    raise ValueError("Source changed during collection: " + name)
                bundle.writestr(name, data)
            fresh, _, _ = inventory(spec)
            if fresh.keys() != files.keys() or any(digest(read_source(p)) != pins[n]["sha256"] for n, p in fresh.items()):
                raise ValueError("Source changed during collection; obtain a quiet snapshot")
            bundle.writestr("HANDOFF.json", json.dumps(manifest, ensure_ascii=False, indent=2).encode("utf-8"))
        return verify(output)
    except BaseException:
        # Only this invocation's newly created archive is removed, never source.
        output.unlink(missing_ok=True)
        raise


def verify(archive):
    with zipfile.ZipFile(archive) as bundle:
        entries = bundle.infolist()
        names = [relative(e.filename) for e in entries]
        folded_names = {n.casefold() for n in names}
        if len(folded_names) != len(names):
            raise ValueError("Duplicate archive member")
        if any(str(parent).casefold() in folded_names for name in names for parent in PurePosixPath(name).parents if str(parent) != "."):
            raise ValueError("Archive file/directory collision")
        if any(stat.S_ISLNK(e.external_attr >> 16) or e.flag_bits & 1 for e in entries):
            raise ValueError("Encrypted or linked archive member")
        if "HANDOFF.json" not in names or bundle.getinfo("HANDOFF.json").file_size > 32 * 1024 * 1024:
            raise ValueError("Missing or oversized manifest")
        manifest_bytes = bundle.read("HANDOFF.json")
        if SECRET_BYTES.search(manifest_bytes):
            raise ValueError("Credential-like manifest bytes")
        manifest = json.loads(manifest_bytes)
        if manifest["schema"] != SCHEMA or manifest.get("acceptance") != "TRANSPORT_ONLY_NOT_GODOT_ACCEPTANCE":
            raise ValueError("Unsupported handoff schema")
        pins = manifest["files"]
        roots = manifest["roots"]
        if not roots or not any(r["role"] == "game" for r in roots) or not manifest.get("owner_declares_dependencies_complete"):
            raise ValueError("A declared game root is required")
        labels = [relative(r["label"]) for r in roots]
        if len({x.casefold() for x in labels}) != len(labels):
            raise ValueError("Duplicate root label")
        if any(excluded(PurePosixPath(x).parts) or secret_name(PurePosixPath(x).parts) for x in labels):
            raise ValueError("Forbidden root label")
        if set(names) != set(pins) | {"HANDOFF.json"}:
            raise ValueError("Archive membership mismatch")
        for name, pin in pins.items():
            relative(name)
            if not any(name.startswith(label + "/") for label in labels):
                raise ValueError("Member outside declared roots")
            if excluded(PurePosixPath(name).parts) or secret_name(PurePosixPath(name).parts):
                raise ValueError("Forbidden payload path")
            info = bundle.getinfo(name)
            if info.file_size != pin["size"]:
                raise ValueError("Size mismatch: " + name)
            hasher = hashlib.sha256()
            overlap = b""
            with bundle.open(name) as stream:
                while chunk := stream.read(1024 * 1024):
                    scanned = overlap + chunk
                    if SECRET_BYTES.search(scanned):
                        raise ValueError("Credential-like archive bytes")
                    overlap = scanned[-256:]
                    hasher.update(chunk)
            if hasher.hexdigest() != pin["sha256"]:
                raise ValueError("Hash mismatch: " + name)
        for root in roots:
            label = relative(root["label"])
            if root.get("entry") and f"{label}/{relative(root['entry'])}" not in pins:
                raise ValueError("Entry missing")
            if root["role"] == "game" and (not root.get("entry") or f"{label}/project.godot" not in pins):
                raise ValueError("Game project missing")
    hasher = hashlib.sha256()
    with archive.open("rb") as stream:
        while chunk := stream.read(1024 * 1024):
            hasher.update(chunk)
    return {"status": "TRANSPORT_VERIFIED", "archive_sha256": hasher.hexdigest(),
            "files": len(pins), "bytes": sum(p["size"] for p in pins.values()),
            "source_identity": manifest["source_identity"], "godot_acceptance": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    c = commands.add_parser("collect")
    c.add_argument("--spec", type=Path, required=True)
    c.add_argument("--out", type=Path, required=True)
    v = commands.add_parser("verify")
    v.add_argument("archive", type=Path)
    args = parser.parse_args()
    result = collect(args.spec, args.out) if args.command == "collect" else verify(args.archive)
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
