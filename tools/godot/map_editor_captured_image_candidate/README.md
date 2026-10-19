# Approved original captured-image CPU loader (not a texture adapter)

Source-only candidate outside production. Frozen capture/factory/material
packages are unchanged. Actual original Canvas capture and repeat evidence:
`../map_editor_landmark_canvas_capture/ROOT_CAPTURE_VERIFICATION.md`.

Inputs are pinned exact saved receipt2445be… / root-observed canonical614c65…,
original closure0c905c… and source4e459b…. The package preserves all43 original
PNG/RGBA files (55,033,856 original RGBA bytes +6,522,608 PNG bytes), dimensions,
source recipe/font trace metadata, original sRGB base pixels, original samplers
and original six cube face ordinal order. No gamma conversion, flip, resampling,
PNG rewrite or mip generation happens. Cube face ordinal is not relabelled as a
native cubemap orientation: that visual acceptance is still HOLD.

API:

```gdscript
const CaptureImages = preload("res://captured_image_loader.gd")
var cpu_images = CaptureImages.new()
var admitted = cpu_images.configure() # fixed res://captured_canvas/ only
var loaded = cpu_images.load_image("texture-0-image-0")
# loaded.image is a newly owned Image; loaded.descriptor is a defensive deep copy
var cube = cpu_images.load_texture_images("texture-1")
# images6 in ORIGINAL face order; sampler dictionary copy, NO Texture resource
cpu_images.invalidate() # reject all stale generation requests until configure
```

The only approved mutable state exposed is a fresh Image/data/descriptor copy.
Internal cache stores immutable validated RGBA snapshot bytes, not returned
Image resources. Godot PackedByteArray copies use safe copy-on-write: native
Image.fill and returned-byte edits were tested against original cached hashes
and independent caller Images. There is no Texture, Material, renderer, node,
gameplay owner or public acceptance callback in this module. Results always say
cpu_only:true / ready:false and font/sampler/IBL/owner accepted:false. A future
separate genuine-owner adapter must admit those gates; JSON booleans cannot.

## Lazy cache and source validation

configure verifies exact metadata/closure bytes and all43 original descriptors,
but reads/decodes zero image files. First use of each admitted fixed ID performs
PNG+RGBA bytecount/SHA, native Image PNG decode, original dimensions/format and
every RGBA pixel equality. Only then is it cached. Subsequent reads are defensive
copies from that validated immutable snapshot, not a current filesystem view.
Changing source files on disk cannot mutate an already approved in-memory
snapshot. Explicit configure/invalidate increments generation and clears cache;
tampered files are refused on the next cold load. Failed metadata configure also
invalidates old authority/cache. Unknown IDs and filesystem paths are never used.

Do not present a retained original snapshot as newly verified disk content; the
owner must invalidate/reconfigure when intentionally switching source generation.
This candidate admits only the root-observed single capture generation; adopting
a different capture requires a new reviewed SHA-pinned source package, not caller
fields or a new arbitrary path. Original output files are never modified.

## Reproduce outside production

```powershell
node tools/godot/map_editor_captured_image_candidate/stage.mjs --check
node tools/godot/map_editor_captured_image_candidate/stage.mjs --stage
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path '<printed destination>' --quit-after 1200 --script res://test_captured_image_loader.gd
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path '<printed destination>' --quit-after 1200 --script res://benchmark_captured_image_loader.gd
```

Stager validates all actual43 source file pairs before exclusive new output writes,
no symlink/path aliases/overwrite. No import required: runtime only reads raw PNG,
RGBA and JSON via CPU Image codec. Native tests mutate only their isolated copied
fixture files and restore them, never the actual root capture. Source code pins
are in receipt.json. Check explicit suite JSON and failures:[], not exit0 alone.

Actual isolated native tests: **289 checks PASS**, all43 source images and all
55MB original pixel hashes, defensive mutation, lazy reads/decode counts, source
tamper/unknown ID/invalidation, original cube/sampler metadata, no acceptance.

Paired CPU evidence (Godot4.7.2 headless,1warmup+7pairs, benchmark.json): cold/new
generation p50/p95 **441.886/457.494ms**; same-generation cached copies
**0.802/0.879ms**. Each cold pair performs86 reads/86 hashes/43 PNG decodes;
warm performs no new IO/hash/decode. OS filecache was warmed; metadata configure
cost is excluded. This measures repeated CPU preparation benefit only, not cold
OS disk startup, GPU upload, visuals, FPS or whole-game loading. Source SHA and
native pixel validation were not removed; they occur once per approved generation.

Actual font/backend identity, original GPU samplers/mip/anisotropy behavior,
cube orientation/PMREM/native IBL/BRDF and protected game-owner gates remain HOLD.
Do not promote frozen publication/graphics authority merely because pixels exist.
