from pathlib import Path


ROOT = Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")


def require(source: str, needle: str, label: str) -> None:
    if needle not in source:
        raise AssertionError(f"missing {label}: {needle}")


require(WORLD, "n._empireSpeechMood=mood", "empire speech context")
require(WORLD, "Math.hypot(r-player.r,c-player.c)<=5.4", "actor-bound speech distance")
require(THREE, "holdingGuard=!!src.empireHoldingGuard", "authoritative holding guard flag")
require(THREE, "holdingGuard?'ОХРАНА ВЛАДЕНИЯ'", "readable holding guard title")
require(THREE, "label.sprite.scale.set(12.2,3.05,1);label.layoutPriority=recoverable?72:48", "readable ordinary casualty card")
require(THREE, "guardRoleBadge='shared-texture-bounded-pool-readable-v2'", "bounded readable guard badge")
require(THREE, "map:flagTexture,transparent:true,side:THREE.DoubleSide", "transparent pennant material")
require(THREE, "g.font='900 30px Arial';g.fillText(sub", "readable ownership subline")

print("artist11 readability contract: ok")
