"""Regression contracts for murder-response player custody ownership."""

import re
from pathlib import Path


HTML = Path("world.html").read_text(encoding="utf-8")


def _body(name: str) -> str:
    start = HTML.index(f"function {name}(")
    brace = HTML.index("{", start)
    depth = 0
    quote = None
    escaped = False
    i = brace
    while i < len(HTML):
        ch = HTML[i]
        if quote:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == quote:
                quote = None
        elif ch in "'\"`":
            quote = ch
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return HTML[start:i + 1]
        i += 1
    raise AssertionError(name)


def run() -> None:
    owner = _body("_murderPoliceVehicleOwnsCustody")
    assert "String(ar.vehicleId||'')===String(v.id||'')" in owner

    # Neither timeout nor ordinary call completion may make the assigned car
    # leave while the player is still physically escorted beside it.
    assert "if(_murderPoliceVehicleOwnsCustody(v))return;" in _body("_orderMurderCrewReturn")
    assert "if(_murderPoliceVehicleOwnsCustody(v))return false;" in _body("_finishMurderPoliceCall")
    assert "if(_murderPoliceVehicleOwnsCustody(v))return false;" in _body("_parkMurderPoliceVehicle")

    start = _body("_startMurderPolicePrisonTransport")
    assert start.index("ar.playerBoarded=true") < start.index("v.state='returning'")
    assert "ar.playerAttachedVehicleId=String(v.id||'')" in start
    assert "_setMurderPoliceArrestPhase(ar,'transport'" in start

    service = _body("updateServiceVehicles")
    loop_guard = service.index("if(v._murderFleet)_enforceMurderPoliceCustodyVehicle(v,now)")
    watchdog = service.index("if (now - v._lastMoveT > 14000)")
    assert loop_guard < watchdog
    returning = service[service.index("} else if (v.state === 'returning')") :]
    invariant = returning.index("policeArrestTransportInvariant='return-blocked-unboarded'")
    movement = returning.index("if (_vehicleStep(v, dt))")
    assert invariant < movement
    assert "_murderPoliceArrest.playerBoarded" in returning
    assert "player.r=v.y;player.c=v.x" in returning
    assert "_startMurderPolicePrisonHandoff(v,now,'road-arrival')" in returning

    handoff = _body("_updateMurderPolicePrisonHandoff")
    assert all(phase in handoff for phase in (
        "ar.phase==='unloading'", "ar.phase==='handoff'",
        "ar.phase==='prison_escort'", "ar.phase==='booking'",
    ))
    complete = _body("_completeMurderPolicePrisonTransport")
    assert "player.r=jailR;player.c=jailC" in complete
    assert "_murderPoliceArrest=null" in complete
    assert "dataset.policeArrestDelivered" in complete
    assert "_deathOv?.classList.remove('show')" in complete

    # The bridge exposes one animation owner: only the initial downed phase is
    # dead/prone; cuffs, escort, hidden transit and booking cannot fight it.
    bridge = HTML[HTML.index("getPlayerState() {") : HTML.index("setAim(angle)")]
    assert "const custodyPoseOwned=!!arrest,stance=custodyPoseOwned?'stand'" in bridge
    assert "dead:arrest?['awaiting_pickup','downed'].includes(arrestPhase)" in bridge
    assert "arrestHidden:arrestPhase==='transport'" in bridge
    assert re.search(r"cuffed:servingSentence\|\|\[[^]]*'transport'", bridge)

    print("POLICE_MURDER_CUSTODY_OK: boarding ownership, attached transit, handoff, booking, single pose owner")


if __name__ == "__main__":
    run()
