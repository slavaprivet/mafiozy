"""Python test entry point for creator authoritative-save DOM fixture."""

import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent


def test_creator_authoritative_save() -> None:
    subprocess.run(
        ['node', str(ROOT / 'test_creator_authoritative_save_dom.js')],
        cwd=ROOT, check=True,
    )


if __name__ == '__main__':
    test_creator_authoritative_save()
