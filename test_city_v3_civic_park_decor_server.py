import unittest
from aiohttp import web
from aiohttp.test_utils import TestClient, TestServer
import _preview_ws_server as server


class CivicDecorServerTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        app = web.Application()
        app.router.add_get('/assets/decor/civic_park_v2/{tail:.*}', server.preview_city_v3_decor_asset)
        self.client = TestClient(TestServer(app))
        await self.client.start_server()

    async def asyncTearDown(self):
        await self.client.close()

    async def test_executable_runtime_and_glb_types(self):
        for path, mime in [('runtime.v1.js', 'text/javascript'), ('registry.v1.json', 'application/json'), ('models/fountain_central_lod0_v2.glb', 'model/gltf-binary')]:
            response = await self.client.get('/assets/decor/civic_park_v2/' + path)
            self.assertEqual(response.status, 200)
            self.assertTrue(response.headers['Content-Type'].startswith(mime))
            self.assertEqual(response.headers['Cache-Control'], 'no-store')
            self.assertEqual(response.headers['X-Content-Type-Options'], 'nosniff')

    async def test_containment_and_source_denial(self):
        for path in ['..%2F..%2F..%2Fworld.html', 'build_static_registry.py', 'test_runtime.mjs', 'missing.glb']:
            response = await self.client.get('/assets/decor/civic_park_v2/' + path)
            self.assertEqual(response.status, 404)
