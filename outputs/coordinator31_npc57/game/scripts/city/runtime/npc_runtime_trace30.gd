extends RefCounted
## Explicit troubleshooting only; errors and semantic state remain unconditional.
static var _enabled := -1
static func enabled() -> bool:
	if _enabled<0:_enabled=1 if OS.get_cmdline_user_args().has("--city-debug-trace30=1") else 0
	return _enabled==1
