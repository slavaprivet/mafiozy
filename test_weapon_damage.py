"""Compatibility entry point for the split production weapon regressions."""

import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent
TESTS = (
    "test_world_source_contracts.py",
    "test_world_weapon_authority.py",
    "test_world_gang_nest_combat.py",
    "test_world_gang_ballistic_arrival.py",
)


def main() -> None:
    for filename in TESTS:
        subprocess.run([sys.executable, str(ROOT / filename)], cwd=ROOT, check=True)
    print("WEAPON_DAMAGE_E2E_OK")


if __name__ == "__main__":
    main()
