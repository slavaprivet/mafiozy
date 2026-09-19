import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {WALK_HUD_SHELL_CSS as css,WALK_HUD_SOURCE_MODAL_SURFACES as surfaces} from './walk_hud_shell.mjs';
const source=readFileSync(new URL('../../../world.html',import.meta.url),'utf8');
assert.deepEqual(surfaces,{gameMainMenu:'.gmm-shell',profileModal:'.card',missionsModal:'.missions-card',newspaperModal:'#newspaperPaper',npcEmpireOverlay:'.ne-card',customGangModal:'.cg-card',policeModal:'.police-card',jobModal:'.job-card',modeModal:'.box'});
for(const [id,selector]of Object.entries(surfaces)){
 assert(source.includes(`id="${id}"`)||source.includes(`.id='${id}'`),`${id} exists in static or generated source DOM`);
 if(selector[0]==='#')assert(source.includes(`id="${selector.slice(1)}"`),`${selector} is a real source child`);
 else assert(new RegExp(`class=["'][^"']*\\b${selector.slice(1)}\\b`).test(source),`${selector} is a real source wrapper`);
 assert(css.includes(selector[0]==='#'?selector:`#${id} ${selector}`),`${id} styles address its actual wrapper`);
}
for(const match of css.replace(/\/\*[\s\S]*?\*\//g,'').matchAll(/([^{}]+)\{/g)){const selector=match[1].trim();if(selector.startsWith('@'))continue;assert(selector.startsWith("html[data-walk-player-hud='true']"),`no unscoped source UI override: ${selector}`);}
for(const selector of ['.gmm-setting input[type=range]','.gmm-setting label','.gmm-toggle.on','.cg-card input','.cg-actions button','.police-action','.job-action','.ne-btn','.mission-item button','.news-summary','.opt.pvp','.opt.pve'])assert(css.includes(selector),`audited native control: ${selector}`);
assert(css.includes('#gameMainMenu{--menu-gold:'));assert(css.includes('z-index:12800'),'source child dialogs may appear above main menu');assert(css.includes('z-index:13100'));
assert(!/#gameMainMenu\s*\{[^}]*display\s*:/.test(css),'main menu native visibility lifecycle remains source-owned');
assert(!/\.gmm-panel[^{}]*\{[^}]*display\s*:/.test(css),'native settings/character tab lifecycle is not overwritten');
assert(!/#customGangModal \.cg-(?:color|preview)[^{}]*\{/.test(css),'custom flag colors remain source-owned');
assert(css.includes(':focus-visible'));assert(css.includes('max-height:calc(100dvh - 32px)'));assert(css.includes('@media(max-height:700px)'));assert(css.includes('@media(prefers-reduced-motion:reduce)'));
assert.match(source,/#stage\s*\{\s*position:\s*fixed;\s*inset:\s*0;\s*overflow:\s*hidden;/,'regression fixture: original fixed stage creates stacking context');
assert.match(source,/html, body\s*\{[^}]*height:\s*100%[^}]*overflow:\s*hidden/s,'absolute replacement preserves full viewport in source non-scrolling layout');
assert.match(source,/#stage\.three-mode #handbrakeBtn\s*\{[^}]*display:none\s*!important[^}]*pointer-events:none\s*!important/s,'legacy 2D drift button can never cover the 3D walk HUD');
assert.match(source,/#stage\.three-mode #mapHud,\s*#stage\.three-mode #mapToggle,\s*html\[data-walk-player-hud='true'\] #mapHud,\s*html\[data-walk-player-hud='true'\] #mapToggle\s*\{[^}]*display:none\s*!important[^}]*pointer-events:none\s*!important/s,'legacy 2D minimap and its toggle stay out of the 3D walk HUD even if the stage class changes');
assert.match(source,/#stage\.three-mode #districtMissionClose,\s*html\[data-walk-player-hud='true'\] #districtMissionClose\s*\{[^}]*display:none\s*!important[^}]*pointer-events:none\s*!important/s,'legacy floating mission close button stays out of the 3D walk HUD');
assert.match(source,/function drawMinimap\(\)\s*\{\s*(?:\/\/[^\n]*\n\s*){2}if \(document\.documentElement\.dataset\.walkPlayerHud === 'true' \|\| document\.getElementById\('stage'\)\?\.classList\.contains\('three-mode'\)\) return;/s,'legacy minimap drawing is idle throughout 3D walk HUD lifetime');
assert.match(source,/if \(_walkRendererActive\(\)\) \{\s*\/\/[^\n]*\n\s*\/\/[^\n]*\n\s*_mapHud\?\.remove\(\);\s*_mapTgl\?\.remove\(\);/s,'legacy minimap DOM is removed in 3D mode so it cannot flash');
assert.match(source,/if \(!_walkRendererActive\(\) && BUS\.state === 'stopped'\)/,'legacy bus boarding prompt is disabled in 3D mode');
assert.match(source,/showEventBanner\([^\n]+?'police-map-alert'/,'police dispatch uses the compact map notification in 3D mode');
assert.match(source,/html\[data-walk-player-hud='true'\] #eventBanner\.police-map-alert[\s\S]{0,600}bottom:\s*296px[\s\S]{0,600}width:\s*230px/,'police dispatch notice is aligned above the compact exploration map');
const stageRule=css.match(/html\[data-walk-player-hud='true'\] #stage\{([^}]+)\}/)?.[1];assert(stageRule);assert.match(stageRule,/position:absolute/);assert.match(stageRule,/z-index:auto/);assert(!/transform|opacity|isolation|contain|filter/.test(stageRule),'do not recreate a stacking context');
console.log(JSON.stringify({passed:true,sourceSurfaces:Object.keys(surfaces),checks:['actual_DOM_wrappers','gateway_only_selectors','source_controls_styled','mainmenu_nested_stack','visibility_not_overwritten','flag_colors_preserved','keyboard_focus','bounded_scrolling','short_viewport','reduced_motion']}));
