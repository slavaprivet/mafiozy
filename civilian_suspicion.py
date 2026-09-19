"""Low-trust civilian reports request observation; never grant damage or wanted.
Civilians are client-owned in the current world. IDs can be syntax-checked here,
not authenticated against a nonexistent server resident registry.
"""
import math
import re

_NONCE = re.compile(r"^[A-Za-z0-9:_-]{8,96}$")
_WITNESS = re.compile(r"^resident_[A-Za-z0-9_-]{1,64}$")

def validate_civilian_report(player, data, now):
    reply = {"kind": "civilian_report_reply", "ok": False}
    if not isinstance(data, dict) or not isinstance(player, dict):
        return dict(reply, reason="invalid")
    nonce = data.get("nonce")
    if not isinstance(nonce, str) or not _NONCE.fullmatch(nonce):
        return dict(reply, reason="nonce")
    reply["nonce"] = nonce
    if player.get("dead") or (player.get("_jail_until") or 0) > now:
        return dict(reply, reason="unavailable")
    witness = data.get("witness_id")
    if not isinstance(witness, str) or not _WITNESS.fullmatch(witness):
        return dict(reply, reason="witness")
    kind = data.get("report_kind")
    if kind not in ("weapon_display", "heard_gunfire"):
        return dict(reply, reason="kind")
    # No client-selected suspect/other UID or arbitrary crime classification.
    if any(key in data for key in ("target_uid", "suspect_uid", "wanted", "damage")):
        return dict(reply, reason="authority")
    try:
        px, py = float(player["x"]), float(player["y"])
        x, y = float(data["x"]), float(data["y"])
        wx, wy = float(data["witness_x"]), float(data["witness_y"])
        if not all(math.isfinite(v) for v in (px, py, x, y, wx, wy)):
            raise ValueError
    except (KeyError, TypeError, ValueError, OverflowError):
        return dict(reply, reason="position")
    if math.hypot(x-px, y-py) > 14 or math.hypot(wx-x, wy-y) > 14:
        return dict(reply, reason="range")
    if kind == "weapon_display" and str(player.get("_weapon") or "fists").lower() in ("", "none", "fists", "unarmed"):
        return dict(reply, reason="weapon")
    if kind == "heard_gunfire" and now - float(player.get("_last_shot_t") or 0) > 15:
        return dict(reply, reason="no_recent_shot")
    previous = player.get("_civilian_suspicion_report") or {}
    if previous.get("nonce") == nonce:
        return dict(reply, **previous["reply"])
    if now - float(previous.get("at") or -60) < 30:
        return dict(reply, reason="cooldown")
    accepted = dict(reply, ok=True, report_kind=kind, x=x, y=y,
                    action="observe", witness_verified=False)
    player["_civilian_suspicion_report"] = {"at": now, "nonce": nonce, "reply": accepted}
    return accepted
