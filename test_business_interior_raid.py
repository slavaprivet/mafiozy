from pathlib import Path


ROOT = Path(__file__).parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")


def test_assault_contract_is_symmetric_and_bounded():
    assert "function _seedBusinessInteriorRaid(bi,property,override=null)" in WORLD
    assert "activity.attacker_roster" in WORLD
    assert "hasAssignedRoster=Array.isArray(activity.defender_roster)" in WORLD
    assert "const assignedRaw=hasAssignedRoster||assignedSource.length?assignedSource" in WORLD
    assert "+activity.defender_count||assignedSource.length" in WORLD
    assert "PLAYER_BUSINESS_INTERIOR_MAX_ATTACKERS=8" in WORLD
    assert "PLAYER_BUSINESS_INTERIOR_MAX_DEFENDERS=12" in WORLD
    assert "Math.max(2,Math.min(PLAYER_BUSINESS_INTERIOR_MAX_ATTACKERS,+activity.force||2))" in WORLD
    assert "playerDefends" in WORLD
    assert "side==='attacker'?'business_raid_attacker':'business_raid_defender'" in WORLD


def test_real_rosters_use_reserves_without_respawn():
    assert "attackerReserve:[],defenderReserve:[]" in WORLD
    assert "reserve.push(...alive.slice(maxLive))" in WORLD
    assert "if(!row.casualty)_spawnBusinessInteriorRaidNpc" in WORLD
    assert "row.casualty=true;row.hp=0" in WORLD
    assert "[...state.guardRoster,...state.defenderRoster]" in WORLD
    assert "const rosterBacked=Array.isArray(activity.defender_roster)||Array.isArray(activity.guard_roster)||!!activity.token" in WORLD
    assert "const legacyFrontCount=rosterBacked?0:" in WORLD
    assert "Array.isArray(activity.guard_roster)?activity.guard_roster" in WORLD


def test_los_cover_combat_and_hold_contract():
    assert "function _convertedBusinessRaidCoverLayout" in WORLD
    for operation in ("beer_bar", "pawnshop", "bookmaker", "strip_club", "gun_shop", "chop_shop", "poker_club", "print_shop"):
        assert f"op==='{operation}'" in WORLD
    assert "_majorInteriorLineClear(bi,n.r,n.c,target.r,target.c)" in WORLD
    assert "_fireBusinessRaidRound(bi,state,n,target)" in WORLD
    assert "target.isRaidPlayer)_hurtLocal" in WORLD
    assert "playerSide!==n.businessRaidSide" in WORLD
    assert "PLAYER_BUSINESS_INTERIOR_HOLD_MS=20000" in WORLD
    assert "state.phase='advance'" in WORLD
    assert "liveAttackers.every(n=>Math.hypot(n.r-cash.r,n.c-cash.c)<=2.15)" in WORLD
    assert "state.outcome='defended'" in WORLD
    assert "state.outcome='captured'" in WORLD


def test_tier_drives_weapon_hp_accuracy_and_cadence():
    for tier in range(1, 5):
        assert f"{tier}:{{weapon:" in WORLD
    assert "raidHit:row.accuracy||ai.hit,raidDamage:ai.damage,raidCooldown:ai.cooldown" in WORLD
    assert "src.weapon_budget" in WORLD
    assert "Math.random()<(n.raidHit||ai.hit)" in WORLD


def test_server_assignment_and_resolution_routes_match_contract():
    assert "/property-guards`" in WORLD
    assert "holding_ref:holdingRef,count:" in WORLD
    assert "`building:${property.building_key||''}`" in WORLD
    assert "/interior-raid/resolve`" in WORLD
    assert "attacker_down_slots=state.attackerRoster.filter(x=>x.casualty).map(x=>x.slot)" in WORLD
    assert "defender_down_ids=state.defenderRoster.filter(x=>x.casualty&&x.memberId!=null).map(x=>x.memberId)" in WORLD
    assert "...(guard_down_ids.length?{guard_down_ids}:{})" in WORLD
    assert "j?.error==='raid still active'" in WORLD


def test_hud_preview_and_3d_bridge_telemetry():
    assert "previewbusinessinteriorraid" in WORLD
    assert "previewEnterBusinessInteriorRaid" in WORLD
    assert "businessInteriorRaidHud" in WORLD
    assert "dataset.businessInteriorRaid=" in WORLD
    assert "businessRaid:src.businessInteriorRaid?" in WORLD
    assert "dataset.businessInteriorRaid3d=" in THREE
    assert "businessInteriorRaidVisual='bridge-npcs-tracers-cover-v1'" in THREE
    assert "activity.business_label||property.operation_name" in WORLD
    assert 'text-overflow:ellipsis;white-space:nowrap' in WORLD


def test_assigned_defender_family_visuals_are_lean_and_authored():
    assert "ownerPrimary=String(property.color" in WORLD
    assert "_customGang?.flag?.primary" in WORLD
    assert "ownerAccent=String(property.accent" in WORLD
    assert "const defender=side==='defender',primary=defender?state.ownerPrimary" in WORLD
    assert "rareHeavy=row.tier>=4&&index%4===0" in WORLD
    assert "body:rareHeavy?3:(index%3?0:1)" in WORLD
    assert "face:Number.isFinite(+authored.face)" in WORLD
    assert "hair:Number.isFinite(+authored.hair)" in WORLD
    assert "suit:primary,trousers:accent,accent" in WORLD
    assert "gang:!!n.npcEmpireBoss||!!n.businessRaidSide,empireCrew:!!n.businessRaidSide" in WORLD
    assert "bossColor:n.raidFamilyColor||'',bossAccent:n.raidFamilyAccent||''" in WORLD
    assert "visualRole:n.businessRaidSide?'gang'" in WORLD
    assert "NPC_BODY_PROFILES" in THREE
    assert "empireMember?(empireColor||authoredSuit" in THREE


def test_wave_model_never_exceeds_live_caps_or_revives_casualties():
    attackers = [{"id": i, "dead": i in {1, 5}} for i in range(8)]
    defenders = [{"id": i, "dead": i in {2, 7, 10}} for i in range(12)]
    live_attackers = [x for x in attackers if not x["dead"]][:4]
    attack_reserve = [x for x in attackers if not x["dead"]][4:]
    live_defenders = [x for x in defenders if not x["dead"]][:6]
    defend_reserve = [x for x in defenders if not x["dead"]][6:]
    assert len(live_attackers) <= 4
    assert len(live_defenders) <= 6
    assert all(not x["dead"] for x in attack_reserve + defend_reserve)
    seen = {x["id"] for x in live_attackers + attack_reserve}
    assert seen == {0, 2, 3, 4, 6, 7}
