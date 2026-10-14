# Full-map portable publication closure — read-only validator

Existing frozen MapBundle, MapBundleStore, catalog, source/native factories and texture manifests were not changed. New independent data-only schema/verifier: `tools/godot/map_editor_publication_closure/{schema.json,closure.mjs,audit.mjs,test_closure.mjs}`. Generated audit inventory: `outputs/map_editor_publication_closure/{closure.json,AUDIT_REPORT.json}`.

## What the current bundle does and does not prove

MapBundle v1 preserves a source-bound object patch, ground patch and exact model SHA references; trusted host validates baseline/ground/resources. MapBundleStore safely saves that envelope. Neither embeds all world data nor resolves procedural/parking/rail/caption/landmark closures. The catalog's 196 GLBs are only one resource family. Having them in local `res://` or an importer cache does not make a published full map portable.

Required source data covered by the audit:

| Family | Coverage |
| --- | --- |
| Catalog | All original 9,901 source object identities and 196 original GLBs |
| Ground topology | Exact full grid, road/walk/protected/police/bridge masks and source origin |
| Ground palette | Original block/palette data, not guessed terrain materials |
| Procedural | All 9,394 exact source IDs, geometry/material/instance buffers and descriptors |
| Parking/rail | 265 semantic records, exact buffers, train GLB, route/motion/authority metadata |
| Protected landmarks | Original bridge/island/dormant-mainland identities, source geometry/light/recipe data; canonical IDs remain separate |
| Landmark texture closure | Original 38 resource/43-image recipes, samplers, adaptive fonts and PMREM/IBL requirements; no pixels substituted |
| Rail caption capture | Two existing approved original Canvas RGBA captures plus source/backend/font receipt |

**1,660 distinct portable content blobs, 71,712,262 bytes (~68.4 MiB)** pass current integrity checks. Different source families share binary hashes in one pool. This size is resource data plus manifests, not an embedded map JSON or measured installed/GPU size. The current MapBundle JSON 64-MiB limit should remain; put binary resources in a separate verified content package, not base64 into the save envelope.

No user map/baseline snapshot was invented: inventory `mapBundle_sha256` is null. The actual user-selected MapBundle must be supplied and admitted by the existing trusted baseline/object/ground validation before publication.

## Portable layout and trusted importer contract

Every materialized blob is named only `blobs/<sha256>.<json|glb|bin|rgba>` with exact SHA and byte count. No `outputs`, absolute computer paths, `user://`, `res://.godot`, user-selected resources or executable file type is a resolution target. Raw source manifests may retain historical path strings/code recipes as **opaque provenance**; the installed importer must never follow those strings or execute them. Resolve declared buffer hashes and semantic resource IDs through the verified content pool only.

The audit creates an inventory, **not a release archive**; blobs remain read from existing trusted source files during verification. Do not distribute only `closure.json` and assume the resources are present. A later approved packager must materialize all listed original bytes and a user-approved MapBundle into this canonical content layout, then verify the package independently on a clean installation.

Current factories use directory-based FileAccess and require a future trusted `godot-native-map-importer/closure-v1` mount/resolver. This importer is installed/signed game code, never code from a publication. It must support all family schemas, correct original 4.1 coordinate/origin semantics, original material/UV/instance bindings, ground patches, exact IDs, and source-owner rebuilds. Pin the accepted native importer/Godot version and its dependency/material/IBL pipeline at the host; do not ship `.godot` as a substitute for a compatible importer. Original GLB bytes must be reimported through the accepted native importer, with native dependencies checked afterward.

GLB headers, lengths and embedded JSON are validated. Existing source GLBs have no external non-data resource URIs; any future such dependency is rejected until explicitly added to a compatible closure format. An imported `.scn` or unresolved engine UID is not accepted as portable source data.

## Integrity is not readiness or authority

`verifyClosure(closure, readBlob, trusted, {requireReady:true})` is **read-only**. `readBlob` is a host-owned whitelist/content resolver; untrusted paths are rejected before it is called. Host supplies pinned per-family manifest SHAs, exact texture-capture/sampler admissions and installed runtime gates. These are not fields the map file can set.

Verifier checks every blob SHA/byte count/kind, exact family membership and semantic IDs, all manifest buffer aliases, 196 GLB references, train model, caption RGBA dependencies, missing/orphan/duplicate resources and strict portable paths. User publication cannot contain `ready`, authority/unlock, scripts or arbitrary userdata attachments. Maximum counts and per-blob sizes are bounded. It never calls ResourceLoader, eval, script import, user directory enumeration or gameplay mutation.

Actual inventory: **integrity=true, ready=false**, with **53 explicit HOLD conditions**: 43 uncaptured landmark image dependencies, original PMREM/IBL, eight installed importer/source/ground/procedural/parking-rail/protected-owner/GLB/caption-sampler gates, and missing user-approved MapBundle. No fake pixels/fonts, blank labels or fallback environment closes those gates. Even pretending every runtime owner is installed cannot bypass missing original captures.

Actual custody/door/convoy/navigation authority is admitted separately by the installed game. Resource hashes protect data integrity; they never establish server ownership, install scripts, unlock police or manufacture player/NPC state. Preserve absent content as HOLD, not deletion or replacement.

## Verification

`node tools/godot/map_editor_publication_closure/audit.mjs`: **3,345 actual existing resource/dependency checks PASS**, readiness intentionally refused.

`node tools/godot/map_editor_publication_closure/test_closure.mjs`: **31 adversarial/contract checks PASS**. Includes wrong/missing/duplicate bytes, family removal/cross-binding, semantic forgery, arbitrary absolute/traversal/`.godot`/user paths (not passed to reader), executable kinds, counterfeit ready/authority, orphan userdata and continued texture/font/PMREM HOLD.

No GPU/browser, production/main, Git or old frozen-file edits. No claim that fresh-PC publication is ready; the missing portable importer/package/approved textures/owners are explicitly enumerated.
