"""Python test entry point for the dependency-free Node DOM fixture."""

import os
import subprocess


def test_district_dom_contract() -> None:
    root = os.path.dirname(os.path.abspath(__file__))
    subprocess.run(
        ['node', os.path.join(root, 'test_npc_empire_district_dom.js')],
        cwd=root, check=True,
    )


if __name__ == '__main__':
    test_district_dom_contract()
