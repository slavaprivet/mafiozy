from pathlib import Path
import re
import unittest


WORLD = Path(__file__).with_name("world.html")


def function_body(source: str, name: str) -> str:
    marker = f"function {name}("
    signature = source.find(marker)
    if signature < 0:
        raise AssertionError(f"missing function {name}")
    start = source.find("{", signature + len(marker))
    if start < 0:
        raise AssertionError(f"missing body for {name}")
    depth = 0
    quote = None
    escaped = False
    for index in range(start, len(source)):
        char = source[index]
        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = None
            continue
        if char in "'\"`":
            quote = char
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return source[start:index + 1]
    raise AssertionError(f"unterminated function {name}")


class ServiceVehicleBridgeRecoveryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = WORLD.read_text(encoding="utf-8")

    def test_all_requested_services_share_one_turn_contract(self):
        self.assertIn(
            "SERVICE_TURN_KINDS=new Set(['ambulance','firetruck','tow','police'])",
            self.source,
        )
        vehicle_step = function_body(self.source, "_vehicleStep")
        self.assertIn("SERVICE_TURN_KINDS.has(v.kind)", vehicle_step)
        self.assertIn("_beginServiceVehicleTurn(v,routeHeading.ang,'rear-waypoint'", vehicle_step)
        self.assertIn("routeHeading.index", vehicle_step)
        self.assertIn("_beginServiceVehicleTurn(v,nextAng,'body-corner'", vehicle_step)

    def test_maneuver_reverses_before_collision_safe_heading_flip(self):
        body = function_body(self.source, "_stepServiceVehicleTurn")
        reverse_move = body.index("v.y=nr;v.x=nc")
        turn_gate = body.index(
            "turn.reverseDistance>=SERVICE_TURN_MIN_REVERSE&&"
            "_serviceVehicleFootprintClear"
        )
        self.assertLess(turn_gate, reverse_move)
        self.assertIn("Math.min(.11,SERVICE_TURN_REVERSE_SPEED*dt)", body)
        self.assertIn("_vehicleRoadPassable(nr,nc)", body)
        self.assertIn("_serviceVehicleFootprintClear(v,nr,nc,reverseAng)", body)
        self.assertIn("_vehicleBlockedByCar(v,nr,nc)", body)
        self.assertNotIn("homeC;v.y=v.homeR", body)

    def test_visible_recovery_is_bounded_and_never_teleports(self):
        body = function_body(self.source, "_stepServiceVehicleTurn")
        self.assertIn("SERVICE_TURN_MAX_MS", body)
        self.assertIn("_setVehicleRoute(v,v.y,v.x", body)
        self.assertIn("serviceTurnRetries", body)
        self.assertNotRegex(body, r"v\.(?:x|y)\s*=\s*v\.(?:homeC|homeR)")
        self.assertNotIn("_teleport", body)

    def test_police_custody_and_tow_payload_follow_every_maneuver_step(self):
        sync = function_body(self.source, "_syncServiceVehicleCargo")
        step = function_body(self.source, "_stepServiceVehicleTurn")
        vehicle_step = function_body(self.source, "_vehicleStep")
        self.assertIn("v.kind==='police'&&v._policePrisonTransport", sync)
        self.assertIn("ar?.playerBoarded", sync)
        self.assertIn("player.r=v.y;player.c=v.x;player.ang=v.ang", sync)
        self.assertIn("v.kind==='tow'&&v._loaded", sync)
        self.assertGreaterEqual(step.count("_syncServiceVehicleCargo(v)"), 4)
        self.assertIn("_syncServiceVehicleCargo(v)", vehicle_step)

    def test_live_fixture_proves_reverse_turn_forward_and_attachment(self):
        self.assertIn("_UP.has('previewserviceturn')", self.source)
        self.assertIn("v.ang=heading.ang+Math.PI", self.source)
        for field in (
            "serviceTurnPhase", "serviceTurnReverse", "serviceTurnCompleted",
            "serviceTurnForwardDot", "custodyAttached",
        ):
            self.assertIn(field, self.source)


if __name__ == "__main__":
    unittest.main()
