"""World UI must present and restore burned businesses authoritatively."""

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent


class BusinessBurnedRestoreWorldTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.world = (ROOT / "world.html").read_text(encoding="utf-8")

    def test_burned_business_uses_server_restore_contract(self):
        management = self.world.split(
            "function openBusinessManagement(bizId) {", 1)[1].split(
                "async function upgradeBusinessHere", 1)[0]

        self.assertIn("const burned = !!(owned && state.status === 'burned')", management)
        self.assertIn("Math.floor((+biz.price || 0) * 0.12)", management)
        self.assertIn("Бизнес сожжён и не приносит доход", management)
        self.assertIn('id="bmRestore"', management)
        self.assertIn("state.status !== 'burned'", management)
        self.assertIn("/biz/${QP.uid}/restore", management)
        self.assertIn("if (Number.isFinite(+j.cash))", management)
        self.assertIn("if (j.success)", management)
        self.assertIn("status:'ok', blocked_until:0, pending:0", management)
        self.assertIn("_bizLastSync = 0; await syncMyBusinesses();", management)
        self.assertIn(
            "return fetch(`${QP.api.replace(/\\/+$/, '')}/biz/${QP.uid}/list`",
            self.world,
        )

        profile = self.world.split("} else if (_profileTab === 'biz') {", 1)[1].split(
            "// Click outside card closes modal", 1)[0]
        self.assertIn("const burned = val.status === 'burned'", profile)
        self.assertIn("🔥 СОЖЖЁН", profile)
        self.assertIn("Доход остановлен · восстановление", profile)

        self.assertIn("previewOpenBurnedBusiness", self.world)
        self.assertIn("previewburnedbusiness", self.world)


if __name__ == "__main__":
    unittest.main()
