// Isolated presentation candidate. Not imported by world/Walk.
// `binding` must eventually come from the coordinator's native-site adapter.
// This module does not authenticate data, choose sites, move actors or pay money.
const HOLD_MS = 2400;
const ARRIVAL_RADIUS = .8;
const EXIT_RADIUS = 1.05;
export function collectVisit23(state, input) {
  const {action, binding, actor, now, generation} = input;
  const wasChecking = state?.phase === 'checking';
  const key = String(input.actionKey || '');
  const validGeneration = Number.isSafeInteger(generation) && generation > 0;
  if (state && validGeneration && generation < state.generation) {
    return {state, effect: null}; // An old asynchronous poll cannot restart work.
  }
  const same = state && generation === state.generation && key === state.key;
  if (!same) {
    if (!validGeneration || !key) return {state: null, effect: wasChecking ? {type: 'release'} : null};
    state = {key, generation, phase: 'approach', siteId: null, startedAt: null};
  }
  if (state.phase === 'done' || state.phase === 'cancelled') return {state, effect: null};
  const eligible = input.provenance === 'server' && action?.kind === 'collect' &&
    !key.includes(':offline:') && !key.includes(':preview:') &&
    binding?.holdingId === action.target_id && binding?.ownerId === actor?.leaderId &&
    typeof binding?.siteId === 'string' && binding.siteId.length > 0 &&
    binding.open === true && Number.isFinite(binding.r) && Number.isFinite(binding.c) &&
    Number.isFinite(actor?.r) && Number.isFinite(actor?.c) && Number.isFinite(now) &&
    actor.alive === true && !actor.combat && !actor.hidden &&
    (!state.siteId || state.siteId === binding.siteId);
  if (!eligible) return {state: {...state, phase: 'cancelled'}, effect: wasChecking ? {type: 'release'} : null};
  const distance = Math.hypot(actor.r - binding.r, actor.c - binding.c);
  if (state.phase === 'approach') {
    // Arrival requires the real planner's exact-result gate as well as distance.
    if (!input.arrivedExact || distance > ARRIVAL_RADIUS) return {state, effect: wasChecking ? {type: 'release'} : null};
    const guard = input.guard;
    const nearbyGuard = guard?.alive === true && !guard.combat &&
      guard.ownerId === actor.leaderId && guard.siteId === binding.siteId &&
      Number.isFinite(guard.r) && Number.isFinite(guard.c) &&
      Math.hypot(guard.r - actor.r, guard.c - actor.c) <= 1.5;
    const facing = nearbyGuard ? {r: guard.r, c: guard.c} : {r: binding.r, c: binding.c};
    return {
      state: {...state, phase: 'checking', siteId: binding.siteId, startedAt: now},
      effect: {type: 'begin-check', facing, text: 'Проверю, как идут дела.'}
    };
  }
  if (distance > EXIT_RADIUS || now < state.startedAt) {
    return {state: {...state, phase: 'cancelled'}, effect: {type: 'release'}};
  }
  if (now - state.startedAt < HOLD_MS) return {state, effect: {type: 'hold'}};
  return {state: {...state, phase: 'done'}, effect: {type: 'release'}};
}
