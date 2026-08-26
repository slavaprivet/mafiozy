"""Selected landmark dossier must display server-authoritative owner/family state."""

import json
import subprocess
import textwrap
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")


def function_body(marker: str) -> str:
    start = WORLD.index(marker)
    brace = WORLD.index("{", start)
    depth = 0
    quote = None
    escaped = False
    for pos in range(brace, len(WORLD)):
        char = WORLD[pos]
        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = None
            continue
        if char in "'\"`":
            quote = char
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return WORLD[start : pos + 1]
    raise AssertionError(f"unterminated function: {marker}")


class SelectedBusinessAuthorityClarityTests(unittest.TestCase):
    def test_nine_owner_family_combinations_and_escaping(self):
        resolver = function_body("function _selectedBusinessAuthorityDossier")
        script = textwrap.dedent(
            f"""
            const _businessPropertyOwners=new Map();
            const _robbedBusinessControls={{}};
            let _businessOwnerAuthorityReady=true,_businessFamilyAuthorityReady=true;
            const QP={{uid:'self-7'}};
            const _npcEmpireEsc=value=>String(value??'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\"/g,'&quot;');
            {resolver}
            const owners=[
              ['self',{{uid:'self-7',name:'Себастьян'}}],
              ['foreign',{{uid:'other-9',name:''}}],
              ['missing',null],
            ];
            const families=['bellini','moretti','neutral'];
            const out=[];
            for(const [ownerKind,owner] of owners)for(const family of families){{
              _businessPropertyOwners.clear();delete _robbedBusinessControls.coffee;
              if(owner)_businessPropertyOwners.set('coffee',owner);
              if(family!=='neutral')_robbedBusinessControls.coffee={{mafia_family:family}};
              const state=_selectedBusinessAuthorityDossier('coffee');
              out.push({{ownerKind,family,owner:state.displayedOwnerName,familyKey:state.normalizedFamilyKey,html:state.html,signature:state.signature}});
            }}
            _businessPropertyOwners.set('coffee',{{uid:'other-9',name:'<Иван & сын>'}});
            const escaped=_selectedBusinessAuthorityDossier('coffee').html;
            process.stdout.write(JSON.stringify({{out,escaped}}));
            """
        )
        proc = subprocess.run(
            ["node", "-"], input=script, text=True, encoding="utf-8",
            capture_output=True, cwd=ROOT,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        result = json.loads(proc.stdout)
        self.assertEqual(len(result["out"]), 9)
        expected_owner = {"self": "ВЫ", "foreign": "Игрок", "missing": "НЕТ"}
        for row in result["out"]:
            self.assertEqual(row["owner"], expected_owner[row["ownerKind"]])
            expected_family_key = "" if row["family"] == "neutral" else row["family"]
            self.assertEqual(row["familyKey"], expected_family_key)
            expected_uid = "self-7" if row["ownerKind"] == "self" else "other-9" if row["ownerKind"] == "foreign" else ""
            self.assertEqual(row["signature"], [True, expected_uid, expected_owner[row["ownerKind"]], True, expected_family_key])
            self.assertIn("СОБСТВЕННИК", row["html"])
            self.assertIn("СЕМЕЙНЫЙ КОНТРОЛЬ", row["html"])
            if row["family"] == "neutral":
                self.assertIn("НЕЙТРАЛЬНЫЙ", row["html"])
        self.assertIn("&lt;Иван &amp; сын&gt;", result["escaped"])
        self.assertNotIn("<Иван & сын>", result["escaped"])

    def test_readiness_is_independent_and_reconnect_keeps_eligibility_maps(self):
        resolver = function_body("function _selectedBusinessAuthorityDossier")
        marker = function_body("function _markBusinessAuthorityUnverified")
        self.assertNotIn(".clear(", marker)
        self.assertNotIn(".delete(", marker)
        self.assertIn("_businessOwnerAuthorityReady=false", marker)
        self.assertIn("_businessFamilyAuthorityReady=false", marker)

        script = textwrap.dedent(
            f"""
            const _businessPropertyOwners=new Map([['coffee',{{uid:'other',name:'Марко'}}]]);
            const _robbedBusinessControls={{coffee:{{mafia_family:'bellini'}}}};
            let _businessOwnerAuthorityReady=false,_businessFamilyAuthorityReady=false;
            const QP={{uid:'self'}};
            const _npcEmpireEsc=value=>String(value??'');
            {resolver}
            const neither=_selectedBusinessAuthorityDossier('coffee');
            _businessOwnerAuthorityReady=true;
            const ownerOnly=_selectedBusinessAuthorityDossier('coffee');
            _businessFamilyAuthorityReady=true;
            const both=_selectedBusinessAuthorityDossier('coffee');
            process.stdout.write(JSON.stringify({{neither,ownerOnly,both}}));
            """
        )
        proc = subprocess.run(["node", "-"], input=script, text=True, encoding="utf-8", capture_output=True, cwd=ROOT)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        state = json.loads(proc.stdout)
        self.assertEqual(state["neither"]["displayedOwnerName"], "СВЕРКА С СЕРВЕРОМ…")
        self.assertIn("СВЕРКА С СЕРВЕРОМ…", state["ownerOnly"]["html"])
        self.assertNotIn("СВЕРКА С СЕРВЕРОМ…", state["both"]["html"])

        onopen = WORLD.split("socket.onopen = () => {", 1)[1].split("socket.onmessage", 1)[0]
        onclose = WORLD.split("socket.onclose = () => {", 1)[1].split("};", 1)[0]
        self.assertIn("_markBusinessAuthorityUnverified()", onopen)
        self.assertIn("_bizLastSync=0", onopen)
        self.assertIn("void syncMyBusinesses()", onopen)
        self.assertIn("_markBusinessAuthorityUnverified()", onclose)

    def test_readiness_only_follows_successful_authority_channels(self):
        sync = function_body("function syncMyBusinesses")
        self.assertIn("if(!r.ok)throw new Error", sync)
        self.assertLess(sync.index("if(!r.ok)throw new Error"), sync.index("_businessOwnerAuthorityReady=true"))
        self.assertIn("_businessActionSignature=''", sync)

        ws = WORLD.split("if (d.robbed_business_controls !== undefined) {", 1)[1].split(
            "if (d.business_family_wars !== undefined)", 1
        )[0]
        self.assertIn("_businessFamilyAuthorityReady=true", ws)
        self.assertIn("_businessActionSignature=''", ws)

    def test_signature_is_selection_keyed_and_actions_ignore_display_readiness(self):
        card = function_body("function _syncBusinessActionCard")
        self.assertIn("sel.kind,String(sel.id)", card)
        self.assertIn("landmarkAuthority?.signature||null", card)
        self.assertIn("signature:[ownerReady,ownerUid,displayedOwnerName,familyReady,normalizedFamilyKey]", WORLD)

        actions = WORLD.split("function _prepareSelectedEstablishmentActions", 1)[1].split(
            "function _modeChoiceVisible", 1
        )[0]
        for display_only in (
            "_selectedBusinessAuthorityDossier",
            "_businessOwnerAuthorityReady",
            "_businessFamilyAuthorityReady",
            "displayedOwnerName",
            "normalizedFamilyKey",
        ):
            self.assertNotIn(display_only, actions)
        self.assertEqual(WORLD.count("_selectedBusinessAuthorityDossier(sel.id)"), 1)
        self.assertIn("previewOpenBusinessAuthority", WORLD)
        self.assertIn("previewbusinessauthority", WORLD)
        self.assertIn("return fetch(`${QP.api.replace(/\\/+$/, '')}/biz/${QP.uid}/list`", WORLD)
        self.assertIn("_bizLastSync = 0; await syncMyBusinesses();", WORLD)


if __name__ == "__main__":
    unittest.main()
