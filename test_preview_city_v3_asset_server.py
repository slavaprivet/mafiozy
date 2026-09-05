import unittest

from aiohttp import web
from aiohttp.test_utils import TestClient, TestServer

import _preview_ws_server as preview_server


class CityV3PreviewAssetServerTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        app = web.Application()
        app.router.add_get(
            "/assets/buildings/city_v3/{tail:.*}",
            preview_server.preview_city_v3_asset,
        )
        app.router.add_get(
            "/preview/three_preview.js",
            preview_server.preview_three_module,
        )
        self.client = TestClient(TestServer(app))
        await self.client.start_server()

    async def asyncTearDown(self):
        await self.client.close()

    async def test_registry_and_glb_are_served_with_browser_safe_types(self):
        registry = await self.client.get(
            "/assets/buildings/city_v3/accepted_v1/registry.v1.js"
        )
        self.assertEqual(registry.status, 200)
        self.assertEqual(registry.headers.get("Cache-Control"), "no-store")
        self.assertEqual(registry.headers.get("X-Content-Type-Options"), "nosniff")
        self.assertTrue(
            registry.headers.get("Content-Type", "").startswith("text/javascript")
        )
        self.assertIn("loadCityV3AcceptedCandidates", await registry.text())

        glb = await self.client.get(
            "/assets/buildings/city_v3/accepted_v1/pawnshop/v1/"
            "pawnshop.1a95f97569d9.glb"
        )
        self.assertEqual(glb.status, 200)
        self.assertEqual(glb.headers.get("Content-Type"), "model/gltf-binary")
        self.assertEqual((await glb.read())[:4], b"glTF")

    async def test_route_rejects_traversal_unknown_types_and_missing_files(self):
        for path in (
            "/assets/buildings/city_v3/..%2F..%2F..%2Fworld.html",
            "/assets/buildings/city_v3/registry.v1.py",
            "/assets/buildings/city_v3/missing.glb",
        ):
            with self.subTest(path=path):
                response = await self.client.get(path)
                self.assertEqual(response.status, 404)

    async def test_live_renderer_module_is_never_served_stale(self):
        response = await self.client.get("/preview/three_preview.js")
        self.assertEqual(response.status, 200)
        self.assertEqual(response.headers.get("Cache-Control"), "no-store")
        self.assertEqual(response.headers.get("X-Content-Type-Options"), "nosniff")
        self.assertTrue(
            response.headers.get("Content-Type", "").startswith("text/javascript")
        )
        self.assertIn("cityV3BuildingPreviewRequested", await response.text())


if __name__ == "__main__":
    unittest.main()
