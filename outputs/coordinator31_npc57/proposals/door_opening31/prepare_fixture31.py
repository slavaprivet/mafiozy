import pathlib
O=pathlib.Path(__file__).resolve().parent;P=O.parent/'services31_resume'
(O/'fixture_base31.gd').write_bytes((P/'fixture31.gd').read_bytes())
s=(P/'exit_envelope31/run.py').read_text(encoding='utf-8')
s=s.replace('ROOT = HERE.parents[4]','ROOT = HERE.parents[3]').replace('outputs/coordinator31_npc57/game','outputs/coordinator31_release57/game')
s=s.replace('manifest = json.loads((HERE / "PATCH.json").read_text(encoding="utf-8-sig"))','manifest = json.loads((HERE / "PATCH.json").read_text(encoding="utf-8-sig")) if args.candidate else {}')
s=s.replace('and p.suffix in (".gd", ".py", ".json")','and p.suffix in (".gd", ".py") and (args.candidate or "patch" not in p.parts) and p.name not in ["prepare_fixture31.py", "derive_cause31.py", "build_patch31.py"]')
s=s.replace('    harness["../fixture31.gd"] = sha(HERE.parent / "fixture31.gd")\n','')
s=s.replace('sources = pins(project)','sources = pins(project)\n    assert sources == json.loads((ROOT/"outputs/coordinator31_release57/ASSEMBLY.json").read_text(encoding="utf-8-sig"))["source_pins"]')
s=s.replace('        current = pins(project)','        current = pins(project)\n        save(run / "SOURCE_AFTER.json", current)')
(O/'run31.py').write_text(s,encoding='utf-8')
