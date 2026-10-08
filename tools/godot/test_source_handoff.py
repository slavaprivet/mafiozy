"""Transport boundary tests; does not launch Godot."""
import json
import tempfile
import unittest
import zipfile
from pathlib import Path

from source_handoff import collect, digest, verify


class HandoffTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.game = self.root / "game"
        (self.game / "scenes").mkdir(parents=True)
        (self.game / "project.godot").write_bytes(b'config_version=5\r\n')
        (self.game / "scenes/main_city.tscn").write_bytes(b'[gd_scene format=3]\r\n')
        (self.game / ".godot").mkdir()
        (self.game / ".godot/cache.bin").write_bytes(b"excluded")
        self.spec = {"source_identity": {"kind": "fixture-not-current286"},
                     "owner_declares_dependencies_complete": True,
                     "roots": [{"label": "game", "source": str(self.game), "role": "game", "entry": "scenes/main_city.tscn"}],
                     "expected_pins": {"game/project.godot": digest(b'config_version=5\r\n')}}
        self.plan = self.root / "spec.json"
        self.out = self.root / "source.zip"

    def run_collect(self):
        self.plan.write_text(json.dumps(self.spec), encoding="utf-8")
        return collect(self.plan, self.out)

    def test_roundtrip_preserves_bytes_and_excludes_cache(self):
        result = self.run_collect()
        self.assertEqual(result["files"], 2)
        self.assertFalse(result["godot_acceptance"])
        with zipfile.ZipFile(self.out) as z:
            self.assertEqual(z.read("game/project.godot"), b'config_version=5\r\n')

    def test_exact_base_mismatch(self):
        self.spec["expected_pins"]["game/project.godot"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "pin mismatch"):
            self.run_collect()
        self.assertFalse(self.out.exists())

    def test_missing_scene(self):
        (self.game / "scenes/main_city.tscn").unlink()
        with self.assertRaisesRegex(ValueError, "entry missing"):
            self.run_collect()

    def test_existing_output_preserved(self):
        self.out.write_bytes(b"another owner")
        with self.assertRaises(ValueError):
            self.run_collect()
        self.assertEqual(self.out.read_bytes(), b"another owner")

    def test_secret_refused(self):
        (self.game / ".env").write_text("sensitive", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "credential filename"):
            self.run_collect()

    def test_parent_escape_refused(self):
        self.spec["roots"][0]["files"] = ["../spec.json"]
        with self.assertRaisesRegex(ValueError, "Unsafe relative"):
            self.run_collect()

    def test_tamper_refused(self):
        self.run_collect()
        other = self.root / "tampered.zip"
        with zipfile.ZipFile(self.out) as old, zipfile.ZipFile(other, "w") as new:
            for name in old.namelist():
                new.writestr(name, b"wrong" if name == "game/project.godot" else old.read(name))
        with self.assertRaisesRegex(ValueError, "Size mismatch"):
            verify(other)

    def test_undeclared_member_refused(self):
        self.run_collect()
        with zipfile.ZipFile(self.out, "a") as z:
            z.writestr("extra.txt", "unexpected")
        with self.assertRaisesRegex(ValueError, "membership mismatch"):
            verify(self.out)

    def test_credential_directory_refused(self):
        (self.game / ".aws").mkdir()
        (self.game / ".aws/credentials").write_bytes(b"fixture")
        with self.assertRaisesRegex(ValueError, "credential filename"):
            self.run_collect()

    def test_forbidden_root_refused(self):
        extra = self.root / ".git"
        extra.mkdir()
        (extra / "config").write_bytes(b"fixture")
        self.spec["roots"].append({"source": str(extra), "label": "extra", "role": "support"})
        with self.assertRaisesRegex(ValueError, "Forbidden source"):
            self.run_collect()

    def test_flattened_layout_refused(self):
        extra = self.root / "assets"
        extra.mkdir()
        (extra / "item.bin").write_bytes(b"fixture")
        self.spec["roots"].append({"source": str(extra), "label": "renamed", "role": "support"})
        with self.assertRaisesRegex(ValueError, "relative layout"):
            self.run_collect()

    def test_sibling_layout_preserved(self):
        assets = self.root / "assets"
        assets.mkdir()
        (assets / "item.bin").write_bytes(b"fixture")
        self.spec["roots"].append({"source": str(assets), "label": "assets", "role": "support"})
        result = self.run_collect()
        self.assertEqual(result["files"], 3)
        with zipfile.ZipFile(self.out) as z:
            self.assertEqual(z.read("assets/item.bin"), b"fixture")


if __name__ == "__main__":
    unittest.main()
