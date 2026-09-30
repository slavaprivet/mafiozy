# Rendered cargo acceptance13 — root only

NOT RUN. Historical visual12/gpu01 remains unchanged. Uses exact PCK SHA and sibling receipt, same CLI as visual12, 40second timeout. No focus requests, NO_FOCUS and offscreen.

Stops and writes RESULT at FIRST assertion failure; every assertion/coroutine return is guarded before further input or item access. Every input dispatch records original native mouse mode, then synchronously releases it before checking or awaiting. Unexpected NO_FOCUS capture is a failure, never silently accepted. Backend capability probe is separately synchronous capture/read/release. Logical no-focus suspension remains required.

Real InputEventMouseMotion coordinates, cached Window pointer, polled viewport/global position, hovered UID, frame and scroll geometry are recorded immediately and after rendered frames. No direct UID injection or forced focus. Requires root no-focus guard and window pointer14 patch. Modal real E and LMB transfer, no-hover E, F reopening, 800/1280 layout, original14UID/ammo/100 units, full3NPC/8buildings/377colliders preserved.

World actual-context refresh records CPU call duration and twelve raw first/warm GPU/wall/draw samples at one identical observer camera before PNG IO. Includes max, not just p95. This is cold-to-warm diagnostic, not a no-overlay A/B comparison or ordinary camera usability proof. Closed/open60frame phases remain, same attached camera. All short offscreen timings are diagnostic only.


15 correction: the original camera is temporarily reparented from SpringArm to actual main scene (same object for real picker). All actor physics remains active. Exact camera pose is asserted after12 rendered frames; original parent/index/local transform are restored. top_level alone was insufficient because SpringArm moves its direct camera child. This remains an explicit observer, not ordinary-camera usability proof.

On either PASS or first FAIL, synchronous input release occurs before deferred scene.free. Production exit hooks then run; one process frame is awaited before quit. Requires root cursor release in main exit for native cursor texture lifecycle. Historical13/GPU14 failure remains unchanged.
