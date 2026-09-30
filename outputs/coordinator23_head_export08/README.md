# Candidate08 static/export readiness

Read-only review; **no engine or GPU run**. Exact PCK `710f2d40d852c4181d874494294ef236e6bc2d215ab216b4c016ad92e82c3c72`, receipt `db79de96f1ae53dc548d7c6fc3968c0ce765a80951b3a745a89bd8b9497e2812`.

PCK v4 directory and all308 entry payload MD5s verified independently. All203 source input hashes still match the export receipt. Fourteen reviewed main/player/population/combat/contact subjects exist as GDSC compiled payloads with correct `.gd.remap` targets and no raw `.gd` counterpart; EXPORT_PROOF records their compiled SHA256. The pre-existing raw loader/float-color bridge are intentional hash-read dependencies, not combat source fallback.

New head/port/marks/impulse scripts are explicit export files. Head lifecycle/owner, blood adapters and closed-eye resources are explicit too. Session/eyes/weapon JSON manifests and byte assets remain included. Residents uses Artist's `const Residents=preload(...)`; no dynamic raw-source reconstruction was introduced. Main binds contact after population setup with reviewed limits. Contact default is true; main and exported notes both identify23f. Player, population, weapon UI/host, project and main scene are byte-identical to candidate07. Main changed only revision, default contact enable and comment. No control suppression or UI hiding was added.

Documentation-only inconsistency: INTEGRATION's main source description still says `OFF`, although the actual runtime default is ON. Several inherited status strings also still say `untested combined overlay`; root should refresh them from current acceptance evidence. These do not change exported gameplay.

## Serialized compiled checks for root

Run separately, in this order, after root grants CPU window:

```powershell
python outputs/coordinator23_head_export08/run_compiled.py active
python outputs/coordinator23_head_export08/run_compiled.py native
```

Neither command has been executed here. Each uses the locked engine `--headless --main-pack ABS/MafioziPreview.pck --fixed-fps60 --script ABS/compiled_*.gd`, no stage `--path`, and an empty working directory.90second process timeout. The short first run should repeat ACTIVE89; the second repeats native800. Result JSON requires engine exit0, successful compiled binding and zero native test errors. Existing logs cause fail-closed refusal instead of overwriting evidence.

Pack mounting order matters: `--main-pack` mounts before the external harness and its `res://` preloads are parsed. Do NOT load the PCK inside `run()`/`_initialize()` of a script already preloading runtime modules; that can bind source/cached scripts first. No `load_resource_pack` is required with this invocation.

External source dependencies are ONLY wrappers + frozen test scripts: `active_head_followup.gd -> tests/native_head_only.gd -> head_native_base.gd -> head_base.gd`. Their res:// host/producer/owner/rules/scene/assets resolve from the mounted PCK. EXTERNAL_TEST_PINS hashes this entire inheritance chain and EXPORT_PROOF. Before native tests, wrappers verify packSHA, every reviewed compiled payloadSHA, `Script.has_source_code()==false`, and exported revision23f; they then call the inherited frozen test. Thus the external test itself remains readable GDScript while the implementation under test is compiled.

Scope remains component acceptance. Frozen harness disables the car corridor/normal population and automatic player processing; it does not validate default contact readiness, current player input, visual wounds or loaded GPU costs. Root's separate actual hook/native input and rendered acceptance are still required.
