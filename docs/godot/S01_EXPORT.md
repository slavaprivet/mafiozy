# S01 Windows x86_64 preview export

This package is a standalone export of the current small Godot migration
preview. It is not acceptance of a finished game, migrated NPC systems or
full-city performance. The export task does not launch the executable or GPU.

## Fixed engine and template version

`ENGINE_LOCK.json` pins Godot **4.7.2.stable.official.ed1daf0bf**, the exact
editor binaries and the matching **4.7.2.stable** Windows x86_64 templates.
The editor ZIP and template archive are official Godot release assets. Their
published SHA-256 and byte counts are recorded along with locally verified
extracted-file hashes. A different engine, modified binary or mismatched
template is rejected before export.

Official template archive:

`https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz`

- Size: **1,281,349,702 bytes**.
- SHA-256: `f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011`.
- Only Windows x86_64 debug/release templates and `version.txt` are installed
  from the verified archive; other platform templates are not extracted.

The default local engine cache is
`%LOCALAPPDATA%\MafioziTools\Godot-4.7.2`. Templates use the standard exact-version
directory `%APPDATA%\Godot\export_templates\4.7.2.stable`. The script never
replaces an existing file with a mismatching hash silently.

## Reproduce

From the repository root in PowerShell:

```powershell
# Verify the installed exact engine/templates without exporting or launching.
.\tools\godot\export_preview.ps1 -VerifyOnly

# Install from the verified official archive if this machine lacks templates.
.\tools\godot\export_preview.ps1 -PrepareTemplates -VerifyOnly

# Create a new release artifact in the ignored project exports directory.
.\tools\godot\export_preview.ps1 -Label s01-review-01
```

`-EngineDirectory` can point at the same locked binaries in another directory.
Omit `-Label` to use a UTC timestamp. Existing output labels are refused so a
previous reviewable build is not overwritten. No working tree reset, source
rewrite or save migration is involved.

The script performs these checks before reporting success:

1. Exact GUI/console editor SHA-256, lengths and engine version string.
2. Exact installed template SHA-256, lengths and `version.txt`.
3. Headless `--export-release "Windows Desktop S01"`, without a GPU shader bake.
4. Runtime source inputs unchanged between the pre-export and post-export hash
   snapshots. Changes during a concurrent integration require a new export.
5. PCK directory parsed directly as data: expected Godot version, required
   runtime JSON/main script present, test/debug harness paths absent.
6. Output hashes and source input receipts written to `build_receipt.json`.

## Output and packaging boundary

The folder is `godot/mafiozi_walk/exports/win64/<label>/`. Keep the executable
and `.pck` beside one another, together with any DLLs the official exporter
adds. No Godot editor installation is needed to run the resulting package.
`build_receipt.json` and `export.log` are diagnostic records, not game content.
The project already ignores `exports/` in its `.gitignore`.

The `Windows Desktop S01` preset exports **release**, **x86_64**, native desktop
texture formats, no embedded PCK, no console wrapper, no signing credentials,
no encryption secrets and no remote deployment. Resource modification is
disabled, retaining the official template executable. Only runtime project
resources and the explicit `data/*.json` data filter are packaged. Export
exclusions cover `scripts/test_*`, test directories, output directories, logs,
Markdown documentation and export configuration/credentials.

The ordinary preview HUD and root-owned optional `--preview-capture` hook
remain part of current runtime code; this task does not secretly edit `main.gd`
to remove them. The pack inventory distinguishes these runtime functions from
the excluded standalone test harness scripts.

No real browser save, account credential, gameplay backend, user profile or
`user://` content is read or copied. Root owns the separate Godot application
profile and the one visible executable launch; those are not accepted by the
export-only check. Screenshot quality, controls and frame-time measurements
must be evaluated against this exact release receipt when root runs it.

## References

Godot's [Windows export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html)
describes the optimized executable plus PCK package. The
[command-line export interface](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)
provides the headless release export command. The official
[4.7.2 archive page](https://godotengine.org/download/archive/4.7.2-stable/)
links the matching release assets. Pack inspection follows the exact
[4.7.2 reader layout](https://github.com/godotengine/godot/blob/4.7.2-stable/core/io/file_access_pack.cpp).

## Produced artifact for root's live gate

`exports/win64/s01-20260926-review02/` was exported successfully using the exact
locked engine and templates. Source files were unchanged during the export;
the export log contains no script, shader or general error lines.

| File | Bytes | SHA-256 |
|---|---:|---|
| `MafioziPreview.exe` | 109,268,480 | `d34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562` |
| `MafioziPreview.pck` | 2,379,688 | `6748159a51e6524998378005d426dcc1ff34be5aff4e1d85c5dfbce61845c6f5` |

Independent read-only verification checked all **28 PCK v4 entries** against
their stored payload digests, confirmed byte-identical runtime `block.json`,
verified every imported-resource and script-remap target exists in the pack,
and confirmed that standalone test harnesses are absent. The EXE PE header is
AMD64 (`0x8664`), and its hash exactly equals the official release template.
Evidence: `outputs/godot_s01_export_integrity.json`, plus the package's
`build_receipt.json` and `export.log`.

Neither this executable nor a GPU run was launched by the export task.
Root's next live launch must use this exact receipt or a freshly exported
receipt after subsequent source/profile/lighting changes. This receipt records
21 source/import-configuration inputs and the export script's own SHA-256
`619ec98476e1fef047f3ac2496b9d763319364a95d0e3352562ee21bf37fcd1c`.

The earlier `s01-20260926-review01` artifact is retained. Review02 adds receipt
coverage of `.import` inputs and the exporter script. Its packed gameplay/data
payloads equal review01; the only changed pack entry is `.godot/uid_cache.bin`.
Consequently this workflow pins each artifact hash, but does not claim that
separate editor exports are byte-for-byte deterministic.
