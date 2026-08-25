from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")


def select_ambient(cars, sticky, preferred, cap=18):
    return sorted(cars, key=lambda car: (
        0 if car["id"] == preferred else 1,
        0 if car["id"] in sticky else 1,
        car["distance2"], car["id"],
    ))[:cap]


class VehicleInteractionAdmissionContract(unittest.TestCase):
    def test_preferred_nonsticky_car_displaces_last_sticky_slot(self):
        sticky = {f"vehicle_sticky_{i}" for i in range(18)}
        cars = [{"id": car_id, "distance2": 100 + i} for i, car_id in enumerate(sorted(sticky))]
        target = {"id": "vehicle_near_interaction", "distance2": 0.25}
        selected = select_ambient(cars + [target], sticky, target["id"])
        self.assertEqual(selected[0]["id"], target["id"])
        self.assertEqual(len(selected), 18)

    def test_preferred_car_is_restored_to_renderer_prefix_after_unshift(self):
        target = {"id": "vehicle_near_interaction"}
        cars = [{"id": "service_police"}] + [{"id": f"vehicle_ambient_{i}"} for i in range(17)] + [target]
        preferred_index = next(i for i, car in enumerate(cars) if car["id"] == target["id"])
        cars.insert(0, cars.pop(preferred_index))
        self.assertLess(cars.index(target), 18)
        self.assertEqual(len(cars[:18]), 18)

    def test_missing_preferred_id_keeps_existing_order(self):
        cars = [{"id": f"vehicle_{i}"} for i in range(20)]
        before = list(cars); preferred = "vehicle_missing"
        preferred_index = next((i for i, car in enumerate(cars) if car["id"] == preferred), -1)
        if preferred_index > 0: cars.insert(0, cars.pop(preferred_index))
        self.assertEqual(cars, before)

    def test_source_wires_interaction_id_without_growing_slot_cap(self):
        self.assertIn("getDynamicEntities(radius = 38, preferredVehicleId = '')", WORLD)
        self.assertIn("preferred=id===preferredId", WORLD)
        self.assertIn("otherId===preferredId", WORLD)
        self.assertIn("cars.findIndex(car=>String(car?.id||'')===preferredId)", WORLD)
        self.assertIn("bridge.getDynamicEntities(65,preferredVehicleId)", THREE)
        self.assertIn("dataset.vehicleAdmission", THREE)
        self.assertIn("const VEHICLE_RENDER_CAP=18", THREE)
        self.assertNotIn("const VEHICLE_RENDER_CAP=30", THREE)


if __name__ == "__main__": unittest.main()
