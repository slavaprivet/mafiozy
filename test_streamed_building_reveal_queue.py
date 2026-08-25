import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parent
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")


def drain_slice(queue, root_cap=2, scan_cap=64):
    roots = []
    scanned = 0
    stale = 0
    while queue and len(roots) < root_cap and scanned < scan_cap:
        root = queue.pop(0)
        scanned += 1
        if not root[1] or root in roots:
            stale += 1
            continue
        roots.append(root)
    return roots, scanned, stale


class StreamedBuildingRevealQueueTests(unittest.TestCase):
    def test_detached_head_cannot_strand_live_shell_and_merged_batch(self):
        stale_a = ("detail-a", False)
        stale_b = ("detail-b", False)
        shell = ("building-shell", True)
        merged = ("batched-static-building-detail", True)
        queue = [stale_a, stale_b, shell, merged]

        roots, scanned, stale = drain_slice(queue)

        self.assertEqual([shell, merged], roots)
        self.assertEqual(4, scanned)
        self.assertEqual(2, stale)
        self.assertEqual([], queue)

    def test_scan_is_bounded_and_empty_live_slice_must_continue(self):
        queue = [(f"stale-{i}", False) for i in range(65)] + [("shell", True)]

        roots, scanned, stale = drain_slice(queue)

        self.assertEqual([], roots)
        self.assertEqual(64, scanned)
        self.assertEqual(64, stale)
        self.assertEqual(("stale-64", False), queue[0])
        self.assertIn("if(!roots.length){if(deferredRevealRoots.length)onIdle(warmDeferredSceneRoots);return;}", THREE)

    def test_source_preserves_reveal_caps_and_streaming_contract(self):
        self.assertIn("const rootCap=mobileRenderProfile?1:2", THREE)
        self.assertIn("scannedRoots<64", THREE)
        self.assertIn("deferredRevealQueue=", THREE)
        self.assertNotIn("deferredRevealRoots.splice(0,mobileRenderProfile?1:2)", THREE)
        self.assertIn("building-reveal-v428", WORLD)
        self.assertIn("evictFarStreamedSectors", THREE)
        self.assertIn("renderer.compileAsync?.(warmupScene,camera)", THREE)


if __name__ == "__main__":
    unittest.main()
