# Station texture adapter — frozen output-only CPU candidate

Separate from the frozen transport consumer and original source exporter.
No production resources, main, gameplay/window, browser or GPU changes.

Godot4.7.2 **524851 checks PASS**, clean exit. Test uses the two actual original
browser CanvasTexture captures from `outputs/map_editor_station_canvas_capture`.
The candidate stager locks the exact manifest, approved capture receipt,
source generator, RGBA/PNG and code hashes and refuses changed target overwrite.

## Preserved source contract

- Full1024×192 sRGB RGBA base pixels are untouched; exactly one vertical row flip
  for unchanged original PlaneGeometry UVs/Three `flipY=true`.
- Original mipmaps remain enabled: 11 levels including the base, ending1×1;
  1048572 native bytes/texture. No compression, resolution or LOD reductions.
- Original linear-mipmap-linear minification, linear magnification,
  clamp-to-edge and anisotropy1 are explicitly assigned through a **cloned**
  StandardMaterial3D. Existing source albedo/emission/PBR values are unchanged.
- An sRGB lookup only decodes a temporary float32 filtering workspace. Mips are
  generated in linear light and encoded back into sRGB. The base RGBA is never
  passed through a second gamma conversion. A black/white analytical mip oracle
  yields188 rather than the dark sRGB-byte average128. All base rows and mip
  dimensions, offsets, byte spans, opacity and upload/readback hash are tested.

CPU-generated mip pixel values are **not claimed byte-identical to the original
GPU driver's generated chain**. This package preserves the source hierarchy
and sampler requirement; exact distant appearance remains a required GPU gate.
It does not substitute a font, image or nearest/no-mip sampler to conceal it.

## Host API

`configure(expected_manifest_sha, source_textures, trusted_pixel_hashes)` admits
the exact two source descriptors and **host-approved** original capture hashes.
The host must verify the approved receipt's SHA before constructing this map;
do not take pixel hashes from an untrusted user document. The stager enforces
the approved receipt SHA. Forging a replacement pixel hash is rejected.

`prepare_capture(row, raw_srgb_rgba)` returns `{ok,texture,levels,native_sha256,
source_srgb_sha256,flipped_base_sha256,capture_record,cache_key,status}`.
The capture_record matches the frozen consumer's gate shape; its pixel hash
covers the native row-flipped image **including all mip levels**. Preserve raw
capture SHA and the processing recipe as separate provenance.

`material_with_sampler(original_material, prepared)` returns a cached clone,
not an in-place mutation. Install it only through the trusted host integration.
The texture cache is content-SHA/source/sampler/algorithm keyed and bounded8;
material cache bounded16. Returning callers share exact resource identity.
Real ImageTexture.update invalidates the cached texture; source material changes
invalidate stale clones. Input bytes, source records and capture recipes remain
detached/unchanged. No source file or user-selected resource is loaded here.

`consumer_gate(request, receipt, raw_by_id, visual_owner_admission)` verifies
the full source capture set and prepares cached textures. By default it returns
HOLD. Only the trusted visual owner's callback can acknowledge the required
original GPU mip/sampler parity review; a user boolean is not an unlock.
The headless test uses an explicit fixture callback, not real gameplay approval.

## CPU cost

Same original two captures, native source admission and warmup:
first complete mip build121072/118834µs;60 cached requests p50/p95
**2964/3611µs**. Reuse avoids approximately40× the measured repeated preparation
work and repeated texture allocation/upload. Cold construction happens once per
shared adapter lifetime; keep the adapter for the owning loaded map. Do not call
configure or clear it each frame. Hash validation still runs on cache requests.

These timings compare resource preparation/reuse, **not full-scene frame time
or FPS**. The headless total test takes approximately1.3 seconds. No GPU/main
integration or general-scene performance is accepted by this result.

## Run and remaining acceptance

`node tools/godot/map_editor_station_texture_adapter/stage.mjs --check`
is read-only. `--stage` creates only `outputs/map_editor_station_texture_adapter`
and refuses overwriting a differing file. Then run the approved Godot console
headless with that output path and `res://test_station_texture_adapter.gd`.

Remain: original driver mip pixel comparison, distant/angled label minification,
UV/orientation/sRGB sampler and lighting/shadow/depth visual parity, coordinator
live browser/font-backend comparison, actual runtime owner callbacks and
production integration. Coordinate one existing GPU game for those later tests.

Primary API references: [Godot Image](https://docs.godotengine.org/en/stable/classes/class_image.html)
and [BaseMaterial3D](https://docs.godotengine.org/en/stable/classes/class_basematerial3d.html).
