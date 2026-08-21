"""Python entry point for deterministic Canvas blood projection QA."""

import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent


def test_blood_splat_projection_dom() -> None:
    subprocess.run(
        ['node', str(ROOT / 'test_blood_splat_projection_dom.js')],
        cwd=ROOT, check=True,
    )


if __name__ == '__main__':
    test_blood_splat_projection_dom()
