"""Python entry point for deterministic NPC-boss anti-stall QA."""

import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent


def test_empire_boss_stall_recovery() -> None:
    subprocess.run(
        ['node', str(ROOT / 'test_empire_boss_stall_recovery_dom.js')],
        cwd=ROOT,
        check=True,
    )


if __name__ == '__main__':
    test_empire_boss_stall_recovery()
