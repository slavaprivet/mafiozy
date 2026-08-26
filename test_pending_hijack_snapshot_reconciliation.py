import json
import pathlib
import subprocess
import textwrap
import unittest


ROOT = pathlib.Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")


def extract_function(source: str, signature: str) -> str:
    start = source.index(signature)
    end = source.index("\n// Когда я сел в машину", start)
    return source[start:end].rstrip()


class PendingHijackSnapshotReconciliationTests(unittest.TestCase):
    def test_pre_ack_snapshot_keeps_single_local_placeholder_until_ack(self):
        apply_snapshot = extract_function(
            WORLD, "function applyQuestCarsSnapshot(arr)"
        )
        script = textwrap.dedent(
            f"""
            const questCars = new Map();
            const QP = {{uid: 'driver-12'}};
            const player = {{r: 80, c: 45, ang: 0}};
            let myDrivingCarId = 'local_hijack_pending';
            let myIsPassenger = false;
            let _exitRequested = false;
            let _vehicleSessionRecoveryPending = true;
            let _recentlyExitedCarId = null;
            let _recentlyExitedCarUntil = 0;
            let _pendingHijackLocalId = 'local_hijack_pending';
            const _normalizeVehiclePaint = value => value || null;
            const _recentlyExitedQuestCarMustStay = () => false;
            globalThis.performance = {{now: () => 1000}};

            questCars.set(_pendingHijackLocalId, {{
              id: _pendingHijackLocalId,
              model: 'corvette_c3',
              paint: '#9a2028',
              owner_uid: QP.uid,
              driver_uid: QP.uid,
              x: 45,
              y: 80,
              ang: 0,
              vx: 0,
              vy: 0,
              state: 'driven',
              civilian: true,
              _pendingServerHijack: true,
            }});

            {apply_snapshot}

            const authoritative = {{
              id: 'civ42',
              model: 'sedan',
              paint: '#111111',
              owner_uid: QP.uid,
              driver_uid: QP.uid,
              passenger_uids: [],
              x: 45,
              y: 80,
              ang: 0,
              vx: 0,
              vy: 0,
              hp: 220,
              max_hp: 220,
              state: 'driven',
              reward: 0,
              wrecked: false,
              civilian: true,
            }};

            applyQuestCarsSnapshot([authoritative]);
            const beforeAck = {{
              ids: [...questCars.keys()],
              driving: myDrivingCarId,
              recoveryPending: _vehicleSessionRecoveryPending,
            }};

            if (_pendingHijackLocalId) questCars.delete(_pendingHijackLocalId);
            _pendingHijackLocalId = null;
            if (!questCars.has(authoritative.id)) questCars.set(authoritative.id, authoritative);
            myDrivingCarId = authoritative.id;
            const afterAck = {{
              ids: [...questCars.keys()],
              driving: myDrivingCarId,
              pendingId: _pendingHijackLocalId,
            }};
            process.stdout.write(JSON.stringify({{beforeAck, afterAck}}));
            """
        )
        proc = subprocess.run(
            ["node", "-"],
            input=script,
            text=True,
            encoding="utf-8",
            capture_output=True,
            cwd=ROOT,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        result = json.loads(proc.stdout)
        self.assertEqual(result["beforeAck"]["ids"], ["local_hijack_pending"])
        self.assertEqual(result["beforeAck"]["driving"], "local_hijack_pending")
        self.assertTrue(result["beforeAck"]["recoveryPending"])
        self.assertEqual(result["afterAck"]["ids"], ["civ42"])
        self.assertEqual(result["afterAck"]["driving"], "civ42")
        self.assertIsNone(result["afterAck"]["pendingId"])

    def test_guard_stays_inside_snapshot_reconciliation_and_constant_time(self):
        block = extract_function(WORLD, "function applyQuestCarsSnapshot(arr)")
        self.assertIn("pendingHijackId", block)
        self.assertIn("pendingHijackServerCar", block)
        self.assertIn("_pendingServerHijack", block)
        self.assertIn("!pendingHijackId", block)
        self.assertIn("_keepPendingHijack", block)
        self.assertNotIn("arr.find(", block)
        self.assertNotIn("arr.filter(c => c.civilian", block)
        self.assertNotIn("setTimeout", block)


if __name__ == "__main__":
    unittest.main()
