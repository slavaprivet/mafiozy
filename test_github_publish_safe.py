import base64
import subprocess
import unittest
from unittest.mock import patch

import github_publish_safe as publisher


def completed(stdout="", returncode=0):
    return subprocess.CompletedProcess(["git"], returncode, stdout, "")


class SafePublisherTests(unittest.TestCase):
    def test_refuses_dirty_target_before_reading_token(self):
        with (
            patch.object(publisher, "_git", return_value=completed(" M world.html\n")),
            patch.object(publisher, "_find_token") as find_token,
        ):
            with self.assertRaisesRegex(RuntimeError, "uncommitted target"):
                publisher.publish_files(("world.html",), "test")
        find_token.assert_not_called()

    def test_refuses_remote_main_outside_local_history(self):
        def fake_git(*args, **kwargs):
            if args[0] == "status":
                return completed()
            if args[0] == "merge-base":
                return completed(returncode=1)
            raise AssertionError(args)

        with (
            patch.object(publisher, "_git", side_effect=fake_git),
            patch.object(publisher, "_find_token", return_value="token"),
            patch.object(
                publisher,
                "_api",
                return_value={"object": {"sha": "remote-sha"}},
            ),
        ):
            with self.assertRaisesRegex(RuntimeError, "fetch and rebase"):
                publisher.publish_files(("world.html",), "test")

    def test_publishes_only_changed_committed_blob_without_force(self):
        calls = []
        committed = b"committed three.js bytes"

        def fake_git(*args, **kwargs):
            if args[0] == "status":
                return completed()
            if args[0] == "merge-base":
                return completed()
            if args[0] == "diff":
                return completed("three_preview.js\n")
            raise AssertionError(args)

        def fake_api(token, method, path, body=None):
            calls.append((method, path, body))
            if path.endswith("/git/ref/heads/main"):
                return {"object": {"sha": "base-sha"}}
            if path.endswith("/git/commits/base-sha"):
                return {"tree": {"sha": "base-tree"}}
            if method == "POST" and path.endswith("/git/blobs"):
                return {"sha": "new-blob"}
            if method == "POST" and path.endswith("/git/trees"):
                return {"sha": "new-tree"}
            if method == "POST" and path.endswith("/git/commits"):
                return {"sha": "new-commit"}
            if method == "PATCH":
                return {}
            if path.endswith("/git/blobs/new-blob"):
                return {"content": base64.b64encode(committed).decode()}
            raise AssertionError((method, path, body))

        with (
            patch.object(publisher, "_git", side_effect=fake_git),
            patch.object(publisher, "_find_token", return_value="token"),
            patch.object(publisher, "_api", side_effect=fake_api),
            patch.object(subprocess, "check_output", return_value=committed) as show,
        ):
            commit, changed = publisher.publish_files(
                ("world.html", "three_preview.js"), "test"
            )

        self.assertEqual(commit, "new-commit")
        self.assertEqual(changed, ("three_preview.js",))
        show.assert_called_once_with(
            ["git", "show", "HEAD:three_preview.js"], cwd=publisher.ROOT
        )
        patch_body = next(body for method, _, body in calls if method == "PATCH")
        self.assertEqual(patch_body, {"sha": "new-commit", "force": False})
        tree_body = next(
            body for method, path, body in calls
            if method == "POST" and path.endswith("/git/trees")
        )
        self.assertEqual([entry["path"] for entry in tree_body["tree"]], ["three_preview.js"])


if __name__ == "__main__":
    unittest.main()
