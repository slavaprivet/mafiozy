"""Focused contracts for persistent and locally rendered gang squads."""

from pathlib import Path


ROOT = Path(__file__).resolve().parent
BOT = (ROOT / "mafiozi_bot.py").read_text(encoding="utf-8")
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")


def run() -> None:
    remove_start = BOT.index("    def remove(self, uid: str) -> None:")
    remove_end = BOT.index("    def _clear_police_downed", remove_start)
    remove_body = BOT[remove_start:remove_end]
    assert "if crew_id and not crew_id.startswith('cg:'):" in remove_body

    handler_start = BOT.index("elif t in ('gang_player_leave','gang_player_kick')")
    handler_end = BOT.index("elif t == 'gang_hire_bot'", handler_start)
    handler = BOT[handler_start:handler_end]
    assert "not crew_id.startswith('cg:')" in handler

    load_start = WORLD.index("function _loadGang()")
    load_end = WORLD.index("_loadGang();", load_start)
    load_body = WORLD[load_start:load_end]
    assert "r:player.r+Math.sin(loadAng)*loadRadius" in load_body
    assert "name:g.name||'Боец',ang:Number.isFinite(player.ang)" in load_body

    update_start = WORLD.index("function _updateGang(dt)")
    update_end = WORLD.index("const _bankGuardSave", update_start)
    update_body = WORLD[update_start:update_end]
    assert "const formation = _gangFormation;" in update_body
    assert "_myGang.filter" not in update_body
    assert "formation.indexOf" not in update_body

    # Start dirty so the first frame hides constructor-default instance matrices.
    assert "gangMatrixActiveSlots=new Array(NPC_CAP).fill(true)" in THREE
    assert "if(gangMatricesDirty){npcParts.gangAura.instanceMatrix.needsUpdate=true" in THREE
    assert "gangMatrixUploads=gangMatricesDirty?'active-or-transition':'idle-skip'" in THREE


if __name__ == "__main__":
    run()
    print("GANG_SQUAD_INTEGRITY_OK")
