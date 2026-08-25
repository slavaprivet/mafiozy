"""Python entry point for deterministic NPC-boss route-generation QA."""

from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parent


def test_empire_route_generation() -> None:
    subprocess.run(
        ['node', str(ROOT / 'test_empire_route_generation_dom.js')],
        cwd=ROOT,
        check=True,
    )


if __name__ == '__main__':
    test_empire_route_generation()
