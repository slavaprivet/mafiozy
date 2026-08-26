import re
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")


def function_body(source: str, marker: str) -> str:
    start = source.index(marker)
    brace = source.index("{", start)
    depth = 0
    quote = None
    escaped = False
    for pos in range(brace, len(source)):
        ch = source[pos]
        if quote:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == quote:
                quote = None
            continue
        if ch in "'\"`":
            quote = ch
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return source[start : pos + 1]
    raise AssertionError(f"unterminated function: {marker}")


class BusinessInteriorMaterialScopeTests(unittest.TestCase):
    def test_red_is_local_cached_and_declared_before_all_cases(self):
        body = function_body(THREE, "const decorateBusinessInterior=data=>")
        declaration = "red=std('#a52f37',.64,.05)"
        self.assertIn(declaration, body)
        self.assertLess(body.index(declaration), body.index("case 'pumps':"))
        self.assertLess(body.index(declaration), body.index("new THREE.BoxGeometry(.025*S,.22,.02*S),red"))
        self.assertEqual(body.count("case 'pumps':"), 1)

    def test_material_declaration_does_not_depend_on_an_outer_red(self):
        body = function_body(THREE, "const decorateBusinessInterior=data=>")
        match = re.search(
            r"const steel=std\([^;]+?\),red=std\('#a52f37',\.64,\.05\);",
            body,
        )
        self.assertIsNotNone(match, "cached material declaration not found")
        script = (
            "'use strict';"
            "const calls=[];const std=(...args)=>{calls.push(args);return {args}};"
            + match.group(0)
            + ";console.log(JSON.stringify({red:red.args,count:calls.length}));"
        )
        result = subprocess.run(
            ["node", "-e", script],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.stdout.strip(), '{"red":["#a52f37",0.64,0.05],"count":9}')

    def test_all_business_variants_and_module_contract_are_retained(self):
        expected = {
            "coffee", "carwash", "barbershop", "pizza", "garage",
            "bar", "club", "warehouse", "casino", "port",
        }
        table = re.search(r"const BUSINESS_INTERIORS\s*=\s*\{(.+?)\n\};", WORLD, re.S)
        self.assertIsNotNone(table)
        ids = set(re.findall(r"(?:^|\n)\s*([a-z]+):\s*\{", table.group(1)))
        self.assertTrue(expected.issubset(ids))
        module = re.search(r'<script type="module" src="(three_preview\.js\?[^\"]+)"></script>', WORLD)
        self.assertIsNotNone(module)
        query = module.group(1)
        for sentinel in (
            "bridge-hangers-v426",
            "vehicle-admission-v427",
            "melee=smart-heavy-forward-kick-v16",
            "interior=business-red-material-v1",
        ):
            self.assertIn(sentinel, query)


if __name__ == "__main__":
    unittest.main()
