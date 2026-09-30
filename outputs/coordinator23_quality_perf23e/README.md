# Exact NPC merge workload allowance for quality23e

Prepared while root GPU diagnostic ran. No Godot/engine/GPU launched here; only small file/JSON checks and9synthetic comparator cases.

Run from repository root after root stops the current game in its own finally-restored wrapper:

```powershell
python outputs/coordinator23_quality_perf23e/run_pair.py --candidate-pck "outputs/coordinator23_quality/candidate05/godot/mafiozi_walk/exports/win64/s01-20260930-quality23e-check/MafioziPreview.pck" --tag loaded_23c_to_23e_01
```

Expected actual pair duration around55–60sec, as prior loaded pair; hard safety cap remains2*38sec. No reduction of warmup/workload to claim a shorter cap. Same inherited3NPC/8buildings/377bodies/377shapes/14cargo100of100, camera proof, source receipt form/hash, wall/GPU/RAM/drawcalls and all prior guards.

Baseline exact23c-play PCK4a2392c... and receipt185 remain pinned. Candidate adjacent build_receipt must bind its exact PCK and unchanged source inputs. Approved source deltas derive from MERGE_PLAN_PINNED.json SHA64da24098ab59d0496e1fd6ffff3f114bde5d4901e7dee595c31f0f6971acf43. Every entry requires exact(path,beforeSHA,afterSHA), including null-before for new assets. No wildcards or owner-only admission. Unknown protected mismatch is rejected BEFORE launching GPU and again in comparison.

43protected paths: original32 + additionally pinned weapon_projectiles.gd +10new NPC files.29remain byte-identical.14exact allowed deltas:10new closed-eyes/blood files; local preview hit owner; ragdoll host; preview_population integration; weapon_projectiles integration. Source-to-scene checks still enforce same IDs/generations/capsule geometry/collision layers/masks. Changed preview_population is allowed only by its exact triple, not a generic exemption. All mappings in PREP_AUDIT.json and hard-coded AUDITED_DELTAS.

Nine synthetic cases PASS, including approved merge accepted and a one-hash change in a newly added death-eyes asset rejected. No actual new performance result yet. Merely allowing known source changes is not NPC behavior/visual acceptance: user's blood/marks/sliding complaints remain open, owned by the relevant implementation agent.
