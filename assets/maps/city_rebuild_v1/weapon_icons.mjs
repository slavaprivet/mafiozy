// Hand-authored side silhouettes for the preview arsenal. No font glyphs or
// emoji are used, so every inventory id remains visually stable across hosts.
export const WEAPON_ICON_PATHS=Object.freeze({
 none:Object.freeze({body:'M33 42c7-3 9-12 12-24 2-5 8-3 7 3l-2 10 4-18c1-6 8-5 8 2l-2 16 5-20c2-6 9-4 8 3l-3 20 6-17c2-6 9-2 7 4l-7 27c-2 9-9 15-19 15H38z',accent:'M42 45h29v6H42z'}),
 nagan:Object.freeze({body:'M18 24h71l18 8v9H77l-8 17H50l4-19H18zM91 26h48v7H91z',accent:'M62 25a12 12 0 1 0 0 24 12 12 0 0 0 0-24z'}),
 tt_pistol:Object.freeze({body:'M22 23h102l15 7v10H73l-7 18H47l5-21H22z',accent:'M45 18h79v7H45zM78 39h23v5H78z'}),
 revolver:Object.freeze({body:'M14 23h83l17 8v10H81L70 59H48l7-19H14zM96 25h61v8H96z',accent:'M62 23a14 14 0 1 0 0 28 14 14 0 0 0 0-28z'}),
 deagle:Object.freeze({body:'M17 19h123l18 9v12H78L66 60H43l8-23H17z',accent:'M35 14h106v8H35zM87 40h30v6H87z'}),
 golden_colt:Object.freeze({body:'M18 22h112l15 7v10H75L63 59H44l7-22H18z',accent:'M34 17h96v7H34zM84 39h28v5H84z'}),
 sawn_off:Object.freeze({body:'M10 26h124l30 7v8H72L58 58H37l10-19H10z',accent:'M93 21h70v5H93zM75 27h7v14h-7z'}),
 shotgun:Object.freeze({body:'M5 27h151l19 6v8H70L55 58H34l10-18H5z',accent:'M85 21h87v6H85zM103 27h30v15h-30z'}),
 uzi:Object.freeze({body:'M30 17h79l20 10v18H76L66 61H45l8-18H30z',accent:'M66 44h18l8 19H69zM109 24h54v7h-54z'}),
 golden_uzi:Object.freeze({body:'M27 16h84l21 11v18H76L65 62H43l9-19H27z',accent:'M67 44h19l8 19H70zM111 22h56v8h-56zM37 21h63v5H37z'}),
 ak74:Object.freeze({body:'M8 24h119l18 7v11H81L67 59H48l7-18H8zM123 25h49v7h-49z',accent:'M20 18h77v7H20zM89 41l18 2-4 20H85z'}),
 m16:Object.freeze({body:'M7 25h139l23 6v9H83L68 58H49l8-18H7z',accent:'M31 17h73l9 10H88l-8-5H31zM91 40h17l-2 21H88z'}),
 tommy_gun:Object.freeze({body:'M8 24h126l30 7v9H79L65 58H43l10-18H8z',accent:'M85 38a17 17 0 1 0 0 25 17 17 0 0 0 0-25zM109 21h52v6h-52z'}),
 sniper:Object.freeze({body:'M3 28h154l19 5v7H72L58 57H37l9-17H3z',accent:'M69 16h55v8H69zM78 12h37v5H78zM121 26h52v5h-52z'}),
 rpg:Object.freeze({body:'M5 26h139l26 7-26 8H5L18 34z',accent:'M30 19h98v7H30zM54 41h18l-4 19H50zM132 22l24-9 5 11z'}),
});

export function weaponIconSvg(id,{className='mfz-weapon-icon',title=''}={}){
 const paths=WEAPON_ICON_PATHS[id];if(!paths)throw Error(`Unknown weapon icon ${id}`);
 const safeClass=String(className).replace(/[^a-zA-Z0-9_ -]/g,''),titleNode=title?`<title>${String(title).replace(/[<>&]/g,'')}</title>`:'';
 return `<svg class="${safeClass}" viewBox="0 0 180 68" role="img" aria-hidden="${title?'false':'true'}" focusable="false">${titleNode}<path class="mfz-icon-body" d="${paths.body}"/><path class="mfz-icon-accent" d="${paths.accent}"/></svg>`;
}
