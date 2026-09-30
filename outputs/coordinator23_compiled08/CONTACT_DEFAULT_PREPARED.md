New copy: `test_contact_default.gd`, SHA256
`cc469b212ccc22a784468bf05b69ffde49a34d0dc22079128fb26f764feaaca7`.

Prepared only: no engine/GPU/parse run performed. Original64PASS harness remains byte-identical
(`311e9702…89aa4b`). The relative parent dependency is correct: both directories are immediate
children of `outputs`, so `../artist23_combat_next/test_combined_eyes_input.gd` resolves unchanged.

The only behavior change is replacing the explicit binder call with read-only checks of the actual
default startup: export ON, status `bound_waiting_final_death`, installed port/sampler, and both
sampler callbacks targeting the current public population forwarding methods. It does not call the
binder or replace either callback. All scheduled movement/weapon/death/contact tests remain intact.

`contact01.log` contains no resource/parse error; it fails on the old second registration attempt.
Candidate08 source defaults ON and calls the binder before `preview_ready`. Population setup rejects
an existing port with `population_lifetime`, so a second call is expected to fail after successful
startup. However, contact01 did not record the original startup status: that historical log alone
does not prove the exact reason. The new `DEFAULT_CONTACT_STARTUP` line and first result case report
the actual loaded-pack status and installed hooks before any mutation, distinguishing duplicate
registration from a missing compiled resource/configuration failure during the root's next run.

Root can use the same headless `--main-pack .../s01-20260930-quality23f/MafioziPreview.pck` command,
substitute this absolute script path, retain the measured-limits argument and use a new output folder.
No runtime/candidate files changed.
