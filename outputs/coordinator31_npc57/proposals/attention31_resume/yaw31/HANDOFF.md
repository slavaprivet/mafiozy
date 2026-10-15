# Rigid yaw31 — frozen for root integration

Base: current merged01 game57, not release56. Only two stationary facing writers changed: threat ALERT/RECOVER/release and ordinary focused attention. They build Basis(Vector3.UP, yaw), matching the existing rigid-body travel yaw writer. No surface/capsule admission tolerance, collision, HP, service, movement, quiet deadline, speed or generation rule changed.

## Causal evidence

- `runs/merged_threat_diag03`: real native miss -> flee 7.721m -> phone237frames -> quiet15 release. Then IDLE for20sec, decisions119, roam_serial119, no owner active/attention/health block, finite due next_decision; body/shape scale(0.999981,1,0.999981), Physical.configure=false. Full prior run preserved the same stall for200sec.
- `runs/yaw_threat_overlay01`: same actual-city input harness with only these two scripts overlaid: 17/17 checks PASS, exit0, source/harness drift0, stderr0. Both ordinary completions occur. During first ordinary walk body scale(1,1,1), Physical.configure=true. Native nonfatal hit, real flight7.881m, quiet15 release, normal speed1.80032 vs flee1.98003. No NPC relocation, HP writes or route replacement.
- `runs/merged_visual03`: merged01 actual graphical full city: native Golden Colt observation, model and skeleton face threat; max visible turn2.859rad; RECOVER returns to physical movement within5sec. Four real viewport PNGs. This run predates yaw31 integration and is independent visual evidence for the first attention package.

## Preserved diagnostics

`runs/yaw_baseline01` rejected a hypothesis in a simplified rotation-only loop: it did not reproduce drift. It lacked real CharacterBody move_and_slide transform updates. No conclusion is based on that synthetic run. Actual-city baseline/candidate establishes the defect and fix above.

Root may integrate this package using PATCH.json base SHA pins. Existing shared files were never edited by this agent. Final merged acceptance/performance remains root-owned.
