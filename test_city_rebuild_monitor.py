import unittest
from tools.city_rebuild_monitor import asset_path, ROOT


class MonitorRoutes(unittest.TestCase):
    def test_real_candidate_module(self):
        self.assertEqual(asset_path('/assets/maps/city_rebuild_v1/walk_preview.mjs'),
                         ROOT / 'assets/maps/city_rebuild_v1/walk_preview.mjs')

    def test_does_not_serve_source_or_arbitrary_files(self):
        for path in ['/world.html', '/mafiozi.db', '/tools/city_rebuild_monitor.py',
                     '/assets/maps/city_rebuild_v1/../../../world.html',
                     '/assets/maps/city_rebuild_v1/%2e%2e/%2e%2e/%2e%2e/world.html',
                     '/assets/maps/city_rebuild_v1/../../../../.bot-token',
                     '/assets/maps/city_rebuild_v1/not-existing.glb']:
            with self.subTest(path=path):
                self.assertIsNone(asset_path(path))


if __name__ == '__main__':
    unittest.main()
