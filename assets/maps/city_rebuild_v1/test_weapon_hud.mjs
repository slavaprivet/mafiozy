import assert from 'node:assert/strict';
import {ARSENAL} from './hero_arsenal.mjs';
import {WEAPON_ICON_PATHS,weaponIconSvg} from './weapon_icons.mjs';
import {SNIPER_SCOPE_SVG,WEAPON_HUD_CSS,weaponHudViewState} from './weapon_hud.mjs';

const ids=ARSENAL.map(item=>item.id);assert.deepEqual(Object.keys(WEAPON_ICON_PATHS),ids);assert.equal(new Set(ids.map(id=>WEAPON_ICON_PATHS[id].body+'|'+WEAPON_ICON_PATHS[id].accent)).size,ids.length);
for(const item of ARSENAL){const svg=weaponIconSvg(item.id,{title:item.label});assert.match(svg,/^<svg/);assert(svg.includes('<path'));assert(!/[🚀🎯💥🔫✋]/u.test(svg),'HUD icons must not depend on emoji');assert(svg.includes(item.label))}
assert.deepEqual(weaponHudViewState({weaponId:'deagle',magazine:0,reserveAmmo:21}),{state:'empty',ammoText:'ПУСТО · 0 / 21',magazine:0,reserveAmmo:21,reloadRemaining:0});
assert.equal(weaponHudViewState({weaponId:'m16',magazine:12,reserveAmmo:30}).state,'ready');assert.equal(weaponHudViewState({weaponId:'shotgun',magazine:1,reserveAmmo:8,reloadRemaining:.34}).state,'reloading');assert.equal(weaponHudViewState({weaponId:'none'}).state,'unarmed');
assert(SNIPER_SCOPE_SVG.includes('mfz-scope-optic')&&SNIPER_SCOPE_SVG.includes('M88 400h242'));assert(!/wind|range|distance|<text/i.test(SNIPER_SCOPE_SVG),'scope cannot claim fabricated ballistics');assert(WEAPON_HUD_CSS.includes('pointer-events:none')&&WEAPON_HUD_CSS.includes('data-ammo-state=empty')&&WEAPON_HUD_CSS.includes('burgundy')===false);
console.log(JSON.stringify({passed:true,weapons:ids.length,checks:['unique_svg_silhouettes','no_emoji','empty_magazine_warning','reload_state','unarmed_state','sniper_scope_reticle','scope_pointer_passthrough']}));
