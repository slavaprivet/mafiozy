"""Static regression contract for the bounded NPC life system.

This test intentionally does not import or start the Telegram bot.  It verifies
the browser-side contract shared by ``world.html`` and ``three_preview.js`` and
keeps a tiny deterministic reference model for event priority/cooldown checks.
It is a contract test, not a second implementation of the NPC AI.
"""

from __future__ import annotations

import ast
import operator
import re
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parent
WORLD_PATH = ROOT / "world.html"
PREVIEW_PATH = ROOT / "three_preview.js"


def _read(path: Path) -> str:
    assert path.is_file(), f"required source file is missing: {path}"
    return path.read_text(encoding="utf-8")


WORLD = _read(WORLD_PATH)
PREVIEW = _read(PREVIEW_PATH)


def _require(source: str, pattern: str, message: str, flags: int = 0) -> None:
    assert re.search(pattern, source, flags), message


_ARITHMETIC = {
    ast.Add: operator.add,
    ast.Sub: operator.sub,
    ast.Mult: operator.mul,
    ast.Div: operator.truediv,
    ast.FloorDiv: operator.floordiv,
}


def _constant_expression(name: str, source: str = WORLD) -> str:
    match = re.search(
        rf"\b(?:const|let)\s+{re.escape(name)}\s*=\s*([^,;]+)", source
    )
    assert match, f"missing numeric NPC contract constant {name}"
    return match.group(1).strip().replace("_", "")


def _safe_number(expression: str) -> float:
    """Evaluate only numeric literals and simple arithmetic from a JS const."""

    def visit(node: ast.AST) -> float:
        if isinstance(node, ast.Expression):
            return visit(node.body)
        if isinstance(node, ast.Constant) and isinstance(node.value, (int, float)):
            return float(node.value)
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, (ast.UAdd, ast.USub)):
            value = visit(node.operand)
            return value if isinstance(node.op, ast.UAdd) else -value
        if isinstance(node, ast.BinOp) and type(node.op) in _ARITHMETIC:
            return _ARITHMETIC[type(node.op)](visit(node.left), visit(node.right))
        raise AssertionError(f"{expression!r} is not a simple numeric constant")

    return visit(ast.parse(expression, mode="eval"))


def _number(name: str, source: str = WORLD) -> float:
    return _safe_number(_constant_expression(name, source))


def _declaration_window(name: str, source: str = WORLD, size: int = 2600) -> str:
    match = re.search(rf"\b(?:const|let)\s+{re.escape(name)}\s*=", source)
    assert match, f"missing NPC contract declaration {name}"
    return source[match.start() : match.start() + size]


def _declaration_expression(name: str, source: str = WORLD) -> str:
    match = re.search(
        rf"\b(?:const|let)\s+{re.escape(name)}\s*=\s*(.*?);",
        source,
        re.S,
    )
    assert match, f"missing NPC contract declaration {name}"
    return match.group(1)


def _quoted_values(name: str, source: str = WORLD) -> set[str]:
    window = _declaration_expression(name, source)
    return {
        value.lower()
        for _, value in re.findall(r"(['\"])([a-zA-Z][a-zA-Z0-9_-]*)\1", window)
    }


def _priority_map() -> dict[str, int]:
    window = _declaration_expression("NPC_LIFE_EVENT_PRIORITY")
    result: dict[str, int] = {}
    for key, value in re.findall(
        r"(?:['\"])?([a-zA-Z][a-zA-Z0-9_-]*)(?:['\"])?\s*:\s*(\d+)", window
    ):
        result[key.lower()] = int(value)
    return result


def test_limits_and_memory_contract() -> None:
    memory_max = _number("NPC_MEMORY_MAX")
    memory_ttl = _number("NPC_MEMORY_TTL_MS")
    group_max = _number("NPC_GROUP_MAX")
    speech_max = _number("NPC_SPEECH_MAX")
    cooldown = _number("NPC_STATE_COOLDOWN_MS")

    assert 2 <= memory_max <= 16, "NPC memory must be useful but strictly bounded"
    assert 15_000 <= memory_ttl <= 15 * 60_000, "NPC memory TTL must be finite and practical"
    assert 2 <= group_max <= 6, "social groups must remain small enough for mobile rendering"
    assert 1 <= speech_max <= 10, "simultaneous NPC speech must have a strict screen budget"
    assert 250 <= cooldown <= 5_000, "state cooldown must prevent oscillation without freezing AI"

    life_block = _life_block()
    _require(life_block, r"\b(?:expiresAt|expires_at|expireAt|until)\b", "NPC memories need an expiry timestamp")
    _require(life_block, r"\.filter\s*\(|\.splice\s*\(|\.slice\s*\(", "NPC memories need explicit pruning")
    _require(life_block, r"NPC_MEMORY_MAX", "memory pruning must consume NPC_MEMORY_MAX")
    _require(life_block, r"NPC_MEMORY_TTL_MS", "memory creation/pruning must consume NPC_MEMORY_TTL_MS")
    _require(life_block, r"NPC_GROUP_MAX", "group construction must consume NPC_GROUP_MAX")
    _require(life_block, r"NPC_SPEECH_MAX", "speech arbitration must consume NPC_SPEECH_MAX")


def test_states_transitions_and_priorities() -> None:
    states = _quoted_values("NPC_LIFE_STATES")
    required = {"idle", "routine", "social", "panic", "help", "surrender"}
    assert required <= states, f"NPC_LIFE_STATES lacks: {sorted(required - states)}"
    assert len(states) <= 12, "NPC state machine is too broad to audit reliably"

    transitions = _declaration_window("NPC_LIFE_TRANSITIONS", size=4200).lower()
    for state in required:
        assert re.search(rf"['\"]{state}['\"]", transitions), (
            f"NPC_LIFE_TRANSITIONS must explicitly cover {state!r}"
        )
    _require(WORLD, r"NPC_STATE_COOLDOWN_MS", "state transitions must use the shared cooldown")
    _require(WORLD, r"NPC_LIFE_STATES\.(?:has|includes)|NPC_LIFE_STATES\s*\.\s*(?:has|includes)",
             "incoming NPC states must be validated against NPC_LIFE_STATES")
    _require(
        WORLD,
        r"NPC_LIFE_TRANSITIONS\[current\]\?\.includes\(state\)",
        "the declared NPC transition graph must reject active forbidden transitions",
    )

    priorities = _priority_map()
    order = ("bullet", "fire", "vehicle", "corpse", "fight", "social")
    missing = [event for event in order if event not in priorities]
    assert not missing, f"NPC_LIFE_EVENT_PRIORITY lacks events: {missing}"
    values = [priorities[event] for event in order]
    assert all(a > b for a, b in zip(values, values[1:])), (
        "event priority must be bullet > fire > vehicle > corpse > fight > social"
    )

    # Exercise the tiny reference model with the priorities declared by the game.
    model = _ReferenceNpc(priorities=priorities, cooldown_ms=int(_number("NPC_STATE_COOLDOWN_MS")))
    assert model.react(1_000, ["social"]) == "social"
    assert model.react(1_100, ["fight", "bullet", "corpse"]) == "panic"
    assert model.react(1_150, ["fight"]) == "panic", "lower threats must not thrash cooldown"
    assert model.react(1_101 + model.cooldown_ms, ["fight"]) == "help"


def test_snapshot_flags_and_three_consumers() -> None:
    snapshot_flags = ("panic", "helping", "surrendered", "social")
    for flag in snapshot_flags:
        _require(
            WORLD,
            rf"\b{flag}\s*:\s*[^,}}]+",
            f"world snapshot must expose the {flag!r} NPC flag",
        )
        _require(
            PREVIEW,
            rf"\bsrc(?:\?\.)?\.{flag}\b|\bsrc\[['\"]{flag}['\"]\]",
            f"three_preview.js must consume the {flag!r} NPC flag",
        )

    _require(PREVIEW, r"\b(?:npcLifePose|npcLifeAnimationPose|npcSocialPose)\b",
             "3D preview needs a dedicated NPC life pose helper")
    _require(PREVIEW, r"(?:panic|helping|surrendered|social).{0,180}(?:leftArm|rightArm|arms|body|head)",
             "NPC life flags must affect body animation, not diagnostics only", re.S)


def test_priority_pools_respect_shared_cap() -> None:
    pool_roles = _quoted_values("NPC_LIFE_POOL_PRIORITY")
    required_roles = {"mission", "police", "guard", "gang", "civilian"}
    assert required_roles <= pool_roles, (
        f"NPC_LIFE_POOL_PRIORITY lacks: {sorted(required_roles - pool_roles)}"
    )

    world_cap = _number("NPC_LIFE_NPC_CAP")
    preview_cap = _number("NPC_CAP", PREVIEW)
    assert 24 <= world_cap <= 96, "NPC cap must be explicit and mobile-safe"
    assert world_cap == preview_cap, "world selection cap and Three.js instance cap must match"

    life_block = _life_block()
    _require(life_block, r"NPC_LIFE_POOL_PRIORITY", "snapshot selection must consume pool priority")
    _require(life_block, r"NPC_LIFE_NPC_CAP", "priority pool merge must enforce the total NPC cap")
    _require(life_block, r"\b(?:remaining|budget|slots)\b", "pool merge needs a decreasing remaining budget")
    _require(life_block, r"\.slice\s*\(\s*0\s*,", "each priority pool must be bounded before merging")


def test_authority_boundaries_and_diagnostics() -> None:
    life_block = _life_block()
    forbidden_writes = (
        r"\.(?:cash|money|balance|hp|health)\s*(?:\+\+|--|[+\-*/]?=)",
        r"\[['\"](?:cash|money|balance|hp|health)['\"]\]\s*(?:\+\+|--|[+\-*/]?=)",
    )
    for pattern in forbidden_writes:
        assert not re.search(pattern, life_block), (
            "NPC life AI must not mutate server-authoritative damage or economy fields"
        )

    _require(life_block, r"\bNPC_LIFE_SYSTEM_START\b", "NPC life authority block needs a start marker")
    _require(life_block, r"\bNPC_LIFE_SYSTEM_END\b", "NPC life authority block needs an end marker")
    for marker in ("npcLifeSystem", "npcLifeStates", "npcLifePools", "npcLifeMemory"):
        _require(
            PREVIEW,
            rf"\.dataset\.{marker}\s*=",
            f"missing Three.js diagnostic dataset marker {marker}",
        )


def test_social_and_helper_safety_guards() -> None:
    socialize = re.search(
        r"function\s+_residentCanSocialize\([^)]*\)\s*\{(.*?)\n\}", WORLD, re.S
    )
    assert socialize, "missing resident social eligibility guard"
    social_body = socialize.group(1)
    for guard in ("_alertUntil", "_npcSurrenderUntil", "_npcHelpingUntil", "lifeBusy"):
        assert guard in social_body, f"social eligibility must guard active {guard} state"

    helper = re.search(
        r"function\s+_npcAssignHelper\([^)]*\)\s*\{(.*?)\n\}", WORLD, re.S
    )
    assert helper, "missing NPC helper assignment"
    helper_body = helper.group(1)
    assert "_planNpcRouteTo" in helper_body, "helpers must validate a bounded route before assignment"
    assert "_npcHelpRetryAfter" in helper_body, "failed helper paths need a retry cooldown"
    _require(
        WORLD,
        r"_npcAdvanceRoute\(n\s*,\s*dt\s*,\s*sp\s*,\s*npcPassable\)",
        "assigned helpers must follow the validated pedestrian route",
    )


def _life_block() -> str:
    start_token = "NPC_LIFE_SYSTEM_START"
    end_token = "NPC_LIFE_SYSTEM_END"
    start = WORLD.find(start_token)
    end = WORLD.find(end_token, start + len(start_token)) if start >= 0 else -1
    assert start >= 0 and end > start, (
        "world.html must bound the new AI with NPC_LIFE_SYSTEM_START/END markers"
    )
    return WORLD[start : end + len(end_token)]


@dataclass
class _ReferenceNpc:
    """Minimal state arbitration model; gameplay movement remains in JavaScript."""

    priorities: dict[str, int]
    cooldown_ms: int
    state: str = "idle"
    state_priority: int = 0
    cooldown_until: int = 0

    _EVENT_STATE = {
        "bullet": "panic",
        "fire": "panic",
        "vehicle": "panic",
        "corpse": "help",
        "fight": "help",
        "social": "social",
    }

    def react(self, now_ms: int, events: list[str]) -> str:
        event = max(events, key=self.priorities.__getitem__)
        priority = self.priorities[event]
        if now_ms < self.cooldown_until and priority <= self.state_priority:
            return self.state
        self.state = self._EVENT_STATE[event]
        self.state_priority = priority
        self.cooldown_until = now_ms + self.cooldown_ms
        return self.state


def main() -> None:
    tests = (
        test_limits_and_memory_contract,
        test_states_transitions_and_priorities,
        test_snapshot_flags_and_three_consumers,
        test_priority_pools_respect_shared_cap,
        test_authority_boundaries_and_diagnostics,
        test_social_and_helper_safety_guards,
    )
    failures = []
    for test in tests:
        try:
            test()
        except AssertionError as exc:
            failures.append(f"{test.__name__}: {exc}")
    if failures:
        raise AssertionError(
            "NPC life contract failures:\n  - " + "\n  - ".join(failures)
        )
    print("NPC_LIFE_SYSTEM_CONTRACT_OK")


if __name__ == "__main__":
    main()
