# Updated review — previous blocking finding resolved

The updated checkpoint57.py now captures each scoped staged mode/blob ID after add, requires stage0, and compares every scoped committed tree entry against that snapshot. It also rechecks pinned working-file SHA and branch main before push. This resolves the previous concrete gap where commit --only could commit different scoped content without a postcommit content check. Foreign index invariance remains checked after add and after commit.

Reviewed source SHA256: `b299b8004b6e72aa656ed575161188fbeae25ab8c04e667cd5a8281b2ae4503d`. Review was source-text only; no Git command, checkpoint main, engine or freeze was executed. The previous review below is retained as history. The smaller literal-pathspec and foreign unmerged-stage hardening notes remain suggestions; no actual conflicting path/stage has been demonstrated.

# Read-only review of checkpoint57.py

Reviewed `outputs/coordinator31_npc57/checkpoint57.py` as source text. No Git command or checkpoint script was executed and no root-owned script was edited.

The scope collector keeps the new release, candidate, four active proposals and explicit coordination files. It excludes `.godot`, `__pycache__`, native_project, checkpoint output and ordinary run directories; the two causal failed runs are explicitly retained. Final successful raw evidence is expected inside the release EVIDENCE.zip. The foreign-index guard snapshots each other path's mode, blob SHA and stage and checks equality after add and commit. `commit --only` and the subsequent changed-path subset check help keep the foreign staged dshshop files out of this commit.

One concrete integrity gap remains before push: the script checks scoped working-file SHA before commit and changed path names after commit, but does not compare committed blob contents with the pinned SOURCE.json. A scoped working file could change in the interval before `commit --only` reads it, and the changed-path subset check would still pass. Before pushing, verify the commit's scoped blobs against the pinned content and confirm HEAD/branch still identify that commit on main. Keep the existing foreign-index checks. The accepted release ASSEMBLY/source pins should also match committed source, not just the working tree.

Two smaller hardening points are appropriate for this reusable wrapper: reject unmerged index stages explicitly rather than collapsing duplicate path stages into a dictionary, and use literal pathspec interpretation for the NUL file list so future filenames with wildcard/pathspec syntax are not expanded. No current path containing such syntax has been demonstrated in this review.

The startup57 RUN.json contract now includes ordinary_ready/resident_count/staff_count/revision, but root remains the sole writer of the final DELIVERY.json and actual F5 pointer. A passing bounded startup alone is not a persistent user-game delivery record.
