"""Bounded placement when client-local civilian traffic becomes a server car.

This is not a canonical-car move API. Existing cars are never changed here.
Native building/road collision remains the source client's responsibility; the
server only has world bounds and canonical vehicle centres for this operation.
"""
import math


def validate_civilian_hijack_pose(requested, player, cars, cols, rows):
    """Return (validated pose, error); None preserves the older client contract."""
    if requested is None:
        return None, None
    if not isinstance(requested, dict):
        return None, 'invalid_car_pose'
    pose = {}
    for field in ('x', 'y', 'ang'):
        value = requested.get(field)
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            return None, 'invalid_car_pose'
        try:
            value = float(value)
        except (OverflowError, ValueError):
            return None, 'invalid_car_pose'
        if not math.isfinite(value):
            return None, 'invalid_car_pose'
        pose[field] = value
    if not (.5 <= pose['x'] <= cols - .5 and .5 <= pose['y'] <= rows - .5):
        return None, 'car_pose_out_of_bounds'
    if math.hypot(pose['x'] - float(player['x']),
                  pose['y'] - float(player['y'])) > 2.5:
        return None, 'car_pose_too_far'
    # Same conservative 1.2-tile parking clearance used by the server. Include
    # empty cars and wrecks: promotion cannot bypass their identity/locks/seats.
    for car in cars.values():
        try:
            cx, cy = float(car['x']), float(car['y'])
        except (KeyError, TypeError, ValueError, OverflowError):
            continue
        if abs(pose['x'] - cx) < 1.2 and abs(pose['y'] - cy) < 1.2:
            return None, 'car_pose_occupied'
    pose['ang'] = math.remainder(pose['ang'], math.tau)
    return pose, None
