"""Python test entry point for deterministic empire-route admission QA."""

import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent


def test_empire_route_admission_observability() -> None:
    subprocess.run(
        ['node', str(ROOT / 'test_empire_route_admission_dom.js')],
        cwd=ROOT, check=True,
    )


if __name__ == '__main__':
    test_empire_route_admission_observability()
