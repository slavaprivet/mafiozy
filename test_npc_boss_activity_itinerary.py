"""Focused contract for reload-stable, visibly moving peaceful boss itineraries."""

import importlib
import math

import npc_empire as ne


def _row(profile, **changes):
    result = {
        "hq_key": profile.hq_key,
        "hospital_until": 0,
        "hospital_id": "",
        "pending_recruits": 0,
        "recruit_started_at": 0,
        "recruit_ready_at": 0,
        "last_recruit_count": 0,
        "last_recruit_at": 0,
    }
    result.update(changes)
    return result


def _distance(left, right):
    return math.hypot(
        float(left["target_r"]) - float(right["target_r"]),
        float(left["target_c"]) - float(right["target_c"]),
    )


def run():
    passed = []

    routes = {profile.leader_id: [
        ne._visible_activity_itinerary_target(profile, slot) for slot in range(24)]
        for profile in ne.PROFILES}
    assert len(routes) == 19
    assert all(len(route) == 24 for route in routes.values())
    passed.append("all-19-have-city-itineraries")

    for route in routes.values():
        for left, right in zip(route, route[1:]):
            assert left["target_id"] != right["target_id"]
            assert left["route_sector"] != right["route_sector"]
            assert _distance(left, right) >= ne.VISIBLE_ACTIVITY_MIN_TARGET_SHIFT
    passed.append("every-adjacent-sector-separated")

    for profile in ne.PROFILES:
        row = _row(profile)
        outputs = [ne._visible_activity(
            profile, row, [], slot * ne.VISIBLE_ACTIVITY_SECONDS, {})
            for slot in range(200)]
        for slot, (left, right) in enumerate(zip(outputs, outputs[1:]), 1):
            assert left["target_id"] != right["target_id"], (profile.leader_id, slot)
            assert _distance(left, right) >= ne.VISIBLE_ACTIVITY_MIN_TARGET_SHIFT
    passed.append("nineteen-times-200-adjacent-safe")

    profile = ne.PROFILE_BY_ID["leila"]
    now = 12345 * ne.VISIBLE_ACTIVITY_SECONDS + 31
    first = ne._visible_activity(profile, _row(profile), [], now, {})
    second = ne._visible_activity(profile, _row(profile), [], now, {})
    assert first == second
    passed.append("same-slot-deterministic")

    reloaded = importlib.reload(ne)
    after_reload = reloaded._visible_activity(
        reloaded.PROFILE_BY_ID["leila"], _row(reloaded.PROFILE_BY_ID["leila"]),
        [], now, {})
    assert after_reload == first
    passed.append("import-reload-stable")

    route_before = [reloaded._visible_activity_itinerary_target(
        reloaded.PROFILE_BY_ID["leila"], slot) for slot in range(24)]
    route_after = [reloaded._visible_activity_itinerary_target(
        reloaded.PROFILE_BY_ID["leila"], slot) for slot in range(24)]
    assert route_before == route_after
    assert all("activity" not in column.lower() for column in (
        "treasury", "members", "strength", "next_action_at"))
    passed.append("route-independent-of-mutable-state")

    for slot in range(25):
        timestamp = slot * reloaded.VISIBLE_ACTIVITY_SECONDS + 74
        activity = reloaded._visible_activity(
            reloaded.PROFILE_BY_ID["marco"], _row(reloaded.PROFILE_BY_ID["marco"]),
            [], timestamp, {})
        assert activity["created_at"] == slot * reloaded.VISIBLE_ACTIVITY_SECONDS
        assert activity["phase"] == "travel"
    assert reloaded.VISIBLE_ACTIVITY_SECONDS == 75
    passed.append("cadence-and-created-at-preserved")

    original_candidate = reloaded._visible_activity_candidate
    try:
        for kind in ("hospital", "recruit", "defend", "invest", "attack", "recover"):
            protected = {
                "kind": kind, "target_id": f"protected:{kind}",
                "target_r": 10, "target_c": 10, "phase": "protected",
                "created_at": 777, "token": f"token:{kind}",
            }
            reloaded._visible_activity_candidate = lambda *args, value=protected, **kwargs: dict(value)
            actual = reloaded._visible_activity(
                reloaded.PROFILE_BY_ID["leila"], _row(reloaded.PROFILE_BY_ID["leila"]),
                [], now, {})
            assert actual == protected
    finally:
        reloaded._visible_activity_candidate = original_candidate
    passed.append("protected-actions-byte-preserved")

    pools = {item["route_sector"] for item in route_before}
    assert pools == {"west", "east", "south"}
    assert reloaded.VISIBLE_ACTIVITY_ROUTE_SECTORS == 3
    passed.append("bounded-three-sector-route")

    business_stop = next((slot, item) for slot, item in enumerate(route_before)
                         if item["target_kind"] == "business")
    slot, target = business_stop
    holding = {"holding_id": target["target_id"], "kind": "business"}
    at_business = reloaded._visible_activity(
        reloaded.PROFILE_BY_ID["leila"], _row(reloaded.PROFILE_BY_ID["leila"]),
        [holding], slot * reloaded.VISIBLE_ACTIVITY_SECONDS, {})
    assert at_business["kind"] == "collect"
    assert at_business["target_id"] == target["target_id"]
    passed.append("owned-business-stop-remains-semantic")

    sample = reloaded._visible_activity(
        reloaded.PROFILE_BY_ID["leila"], _row(reloaded.PROFILE_BY_ID["leila"]),
        [], now, {})
    assert sample["target_reason"] == "activity-itinerary"
    assert sample["route_length"] == 3
    assert sample["route_stop"] == now // reloaded.VISIBLE_ACTIVITY_SECONDS
    assert sample["route_sector"] in {"west", "east", "south"}
    assert sample["replaces_kind"] in {"return_hq", "inspect", "patrol", "collect"}
    passed.append("truthful-route-telemetry")

    world = open("world.html", encoding="utf-8").read()
    assert "dataset.empireBossActivityVariety" in world
    assert "==='activity-itinerary'" in world
    assert "empireBossMotionAll" in world
    assert "dataset.livePlayerMotion" in world
    passed.append("world-telemetry-witness")

    assert len(passed) == 12, passed
    print("boss activity itinerary: 12/12 gates OK — " + ", ".join(passed))


if __name__ == "__main__":
    run()
