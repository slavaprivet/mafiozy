"""Static release contracts that do not belong to a combat simulator test."""

from pathlib import Path


ROOT = Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")
BOT = (ROOT / "mafiozi_bot.py").read_text(encoding="utf-8")


def run() -> None:
    for marker in (
        "return QP.weapon || null;",
        "weapon: currentWeapon || 'fists'",
        "id: 'blackmarket_bellini'",
        "id: 'blackmarket_moretti'",
        "issuedByFamily:true",
        "Этот рынок обслуживает только семью",
        "const k = Math.max(0.35, power || 1) * 0.95;",
        "const kb = 0.09;",
        "const kb = 0.07;",
        "Math.max(0.72, Math.min(0.92, baseBulletScale * 0.72))",
        "Math.max(0.78, Math.min(0.96, baseTrailScale * 0.78))",
        "rawThreatChat.startsWith('Горю!')",
        "function _igniteInteriorCharacter(n,sourceR,sourceC)",
        "_hitInteriorNpc(n,0,0,6,'molotov_fire',true)",
        "drawBurningCharacter(p.x,p.y,nn.id||nn.name||'interior_npc'",
        "scale*1.35*dt",
        "moveScale*1.3*dt",
        "kind === 'business_defense_shot'",
        "function _markBusinessOperational(businessId, cooldownUntil = 0)",
        "function _idleBusinessGuardPose(biz, index",
        "const _businessDefenseChat = new Map()",
        "? (liveNest ? (liveNest.guards || []) : [])",
        "function _spawnMajorManager(d = {})",
        "casino ? 7.65 : 4",
        "first snapshot can reconcile against that temporary spawn",
        "socket.onopen = () =>",
        "sendInput(true);",
        "casinoOwner.c=casinoOwner.tc=26.35",
        "const businessOwnerNpc = bi.type === 'business'",
        "businessOwnerNpc?`👑 ${nn.name}`:nn.name",
        "kind:'curtain'",
        "const isCurtain=wall.kind==='curtain'",
        "function _sendAggroWeaponHit(targetId, weapon, shotId = _authoritativeShotId)",
        "_sendAggroWeaponHit(chosenAggro.id",
        "suit:'#f3efe5'",
        "Семья Карло Беллини",
        "Семья Витторио Моретти",
        "mafia_family",
        "const BURJ_POS = { r: 36, c: 36 }",
        "{ id: 'mansion', r: 136, c: 16",
        "function _peacefulInteriorGunLock",
        "(_majorInteriorObjectId && direct.majorGuard)",
        "_majorRaidLocal?.combatStarted ? _findGangCompanionTarget(m)",
        "function _majorGuardCombatTarget(bi,n)",
        "function _hurtGangMemberInInterior(member,damage",
        "if (!_majorInteriorObjectId && Math.random() < 0.25)",
    ):
        assert marker in WORLD, marker
    assert "damagedProps.values()" not in WORLD
    assert "ВОССТАНОВЛЕНИЕ ${Math.floor(secs/60)}" not in WORLD
    assert "strokeText('ЖЁЛТАЯ БАНДА'" not in WORLD
    assert "family_pistol = key == 'pistol'" in BOT
    assert "p_ref['_weapon_classes'] = {'pistol'} |" not in BOT
    assert "CITY_GANG_MAX           = 4" in BOT
    assert "'npc_gang_fight':True" in BOT
    assert "**({'suit':'#f3efe5'} if faction == 'yellow' else {})" in BOT
    print("world source contracts: OK")


if __name__ == "__main__":
    run()
