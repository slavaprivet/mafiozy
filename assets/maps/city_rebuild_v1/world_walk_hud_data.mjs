// Served asset: presentation-only boundary. Callers inject source-world snapshots and actions;
// this module never reads authentication, starts networking, or owns inventory.
export const WALK_HUD_ACTIONS = Object.freeze([
  'menu', 'profile', 'inventory', 'business', 'newspaper', 'missions',
  'empires', 'boss', 'gang', 'status', 'mode', 'money',
  'role_help', 'police', 'mafia', 'gang_manage',
]);

const text = value => value == null ? '' : String(value);
const number = value => value !== null && value !== undefined && value !== '' && Number.isFinite(Number(value)) ? Number(value) : null;
const nonnegative = value => { const n = number(value); return n === null ? null : Math.max(0, n); };
// Preserve exact server integer strings across repeated bridge normalization.
const cashValue = value => {
  if (typeof value === 'bigint' || typeof value === 'string' && /^\d+$/.test(value.trim())) {
    const integer = BigInt(typeof value === 'string' ? value.trim() : value);
    if (integer > BigInt(Number.MAX_SAFE_INTEGER)) return String(integer);
  }
  return nonnegative(value);
};
const list = value => Array.isArray(value) ? value : [];
// A bridge hands its freshly normalized snapshot straight to the walk
// controller.  Keep that provenance out-of-band so arbitrary integrations are
// still normalized defensively, without exposing a renderer-only field to UI
// consumers or retaining snapshot objects.
const normalizedSnapshots = new WeakSet();
export const isNormalizedWalkHudState = value => !!value && typeof value === 'object' && normalizedSnapshots.has(value);
function copyAppearance(value, depth = 0) {
  if (value == null || typeof value !== 'object') return value ?? null;
  if (depth > 6) return null;
  if (Array.isArray(value)) return value.map(item => copyAppearance(item, depth + 1));
  const out = {};
  for (const [key, item] of Object.entries(value)) {
    if (['__proto__', 'constructor', 'prototype'].includes(key) || typeof item === 'function') continue;
    out[key] = copyAppearance(item, depth + 1);
  }
  return out;
}
function member(item = {}, kind = '') {
  return {
    id: text(item.id), name: text(item.name), role: text(item.role), kind: text(item.kind || kind),
    isSelf: item.isSelf === true, canKick: item.canKick === true,
    renderId: text(item.renderId), renderRole: text(item.renderRole),
    level: nonnegative(item.level), hp: nonnegative(item.hp), maxHp: nonnegative(item.maxHp),
    look: item.look ? copyAppearance(item.look) : null, weapon: text(item.weapon),
    npcCount: nonnegative(item.npcCount), online: item.online == null ? null : !!item.online,
  };
}

/** Missing source values stay unknown, never become a fictitious balance/level. */
export function normalizeWalkHudState(raw = {}) {
  const available = raw?.available === true;
  const src = available ? raw : {};
  const p = src.player || {}, clock = src.clock || {}, status = src.status || {};
  const gang = src.gang || {}, ui = src.ui || {};
  const hp = nonnegative(p.hp), maxHp = nonnegative(p.maxHp);
  const state = {
    available, source: available ? 'world' : 'unavailable',
    player: {
      id: text(p.id), name: text(p.name), level: nonnegative(p.level), hp, maxHp,
      hpRatio: hp === null || !(maxHp > 0) ? null : Math.min(1, hp / maxHp),
      cash: cashValue(p.cash), diamonds: nonnegative(p.diamonds), mode: text(p.mode),
      look: p.look ? copyAppearance(p.look) : null, dead: p.dead == null ? null : !!p.dead,
      armor: p.armor ? {id: text(p.armor.id), current: nonnegative(p.armor.current), max: nonnegative(p.armor.max)} : null,
    },
    clock: {label: text(clock.label), hour: number(clock.hour), minute: number(clock.minute), phase: text(clock.phase)},
    status: {title: text(status.title), label: text(status.label), detail: text(status.detail), badge: text(status.badge), kind: text(status.kind), role: text(status.role)},
    gang: {
      id: text(gang.id), name: text(gang.name), role: text(gang.role), kind: text(gang.kind),
      isLeader: gang.isLeader === true, isCreator: gang.isCreator === true, canManage: gang.canManage === true,
      playerCount: nonnegative(gang.playerCount), playerMax: nonnegative(gang.playerMax),
      npcCount: nonnegative(gang.npcCount), npcMax: nonnegative(gang.npcMax),
      players: list(gang.players).map(item => member(item, 'player')), npcs: list(gang.npcs).map(item => member(item, 'npc')),
    },
    bosses: list(src.bosses).map(b => ({
      id: text(b.id), name: text(b.name), gangName: text(b.gangName), title: text(b.title),
      renderId: text(b.renderId), renderRole: text(b.renderRole),
      look: b.look ? copyAppearance(b.look) : null, color: text(b.color), accent: text(b.accent),
      status: text(b.status), rank: nonnegative(b.rank), members: nonnegative(b.members),
      hospitalUntil: nonnegative(b.hospitalUntil),
    })).filter(b => b.id),
    missions: {count: nonnegative(src.missions?.count)},
    ui: {blocked: !!ui.blocked, reason: text(ui.reason), openPanels: list(ui.openPanels).map(text)},
    actions: Object.fromEntries(WALK_HUD_ACTIONS.map(action => [action, available && src.actions?.[action] === true])),
  };
  normalizedSnapshots.add(state);
  return state;
}

/** Only open existing interfaces. No caller-selected global method or mutation. */
export function createWalkHudDispatcher({isActive = () => false, actions = {}, getBossIds = () => []} = {}) {
  const allowed = new Set(WALK_HUD_ACTIONS);
  return async function performWalkHudAction(action, payload = {}) {
    if (!isActive()) return {accepted: false, reason: 'source-unavailable'};
    if (!allowed.has(action)) return {accepted: false, reason: 'unknown-action'};
    if (!Object.prototype.hasOwnProperty.call(actions, action) || typeof actions[action] !== 'function') {
      return {accepted: false, reason: 'action-unavailable'};
    }
    let safePayload;
    if (action === 'boss') {
      const id = typeof payload?.id === 'string' ? payload.id : '';
      if (!id || !Array.from(getBossIds(), text).includes(id)) return {accepted: false, reason: 'unknown-boss'};
      safePayload = {id};
    }
    try {
      const result = await actions[action](safePayload);
      if (result === false) return {accepted: false, reason: 'source-declined'};
      if (result && typeof result === 'object' && result.accepted === false) {
        return {accepted: false, reason: text(result.reason) || 'source-declined'};
      }
      return {accepted: true, action};
    } catch {
      return {accepted: false, reason: 'source-action-failed'};
    }
  };
}

// Native source interfaces remain outside the walk ShadowRoot. The renderer
// must suppress movement/aim/fire while these overlays are actually visible.
export const WALK_HUD_SOURCE_PANEL_IDS = Object.freeze([
  'gameMainMenu', 'profileModal', 'newspaperModal', 'missionsModal', 'modeModal',
  'npcEmpireOverlay', 'customGangModal', 'policeModal', 'jobModal', 'shopOverlay',
  'taxiOverlay', 'arenaOverlay', 'michaelModal', 'bizConfirmModal', 'fireStationModal',
  'lockpickModal', 'respawnModal', 'jailOverlay', 'arrestOverlay', 'characterCreator',
]);

export function getWalkHudOpenPanels(doc, view = doc?.defaultView) {
  if (!doc?.getElementById) return [];
  const candidates = new Set(WALK_HUD_SOURCE_PANEL_IDS.map(id => doc.getElementById(id)).filter(Boolean));
  for (const el of doc.querySelectorAll?.('[role="dialog"], [aria-modal="true"]') || []) candidates.add(el);
  const panels = [];
  for (const el of candidates) {
    if (el.hidden || el.getAttribute?.('aria-hidden') === 'true') continue;
    if (typeof el.getClientRects === 'function' && !el.getClientRects().length) continue;
    const css = view?.getComputedStyle?.(el);
    if (css && (css.display === 'none' || css.visibility === 'hidden' || css.visibility === 'collapse')) continue;
    if (!css && !el.classList?.contains('show') && !el.classList?.contains('open')) continue;
    panels.push(el.id || el.getAttribute?.('aria-label') || 'source-dialog');
  }
  return [...new Set(panels)];
}

/** Small source-side facade; closure readers can access world lexical state. */
export function createWorldWalkHudBridge({readSnapshot, isActive = () => false, actions = {}, getBossIds = () => [], document: doc} = {}) {
  const performWalkHudAction = createWalkHudDispatcher({isActive, actions, getBossIds});
  return Object.freeze({
    getWalkHudState() {
      if (!isActive() || typeof readSnapshot !== 'function') return normalizeWalkHudState();
      try {
        const raw = readSnapshot() || {};
        const openPanels = doc ? getWalkHudOpenPanels(doc) : list(raw.ui?.openPanels);
        return normalizeWalkHudState({
          ...raw, available: true,
          actions: Object.fromEntries(WALK_HUD_ACTIONS.map(action => [action,
            Object.prototype.hasOwnProperty.call(actions, action) && typeof actions[action] === 'function' && raw.actions?.[action] !== false])),
          ui: {...raw.ui, openPanels, blocked: !!raw.ui?.blocked || openPanels.length > 0,
            reason: raw.ui?.reason || (openPanels.length ? 'source-dialog' : '')},
        });
      } catch {
        // E.g. startup TDZ: never display stale/fabricated source values.
        return normalizeWalkHudState();
      }
    },
    performWalkHudAction,
  });
}
