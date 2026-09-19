import { INTERIOR_SAFE_DIMENSIONS } from './interior_interactive_safe.mjs';

// Functional, metre-scale furnishing for the real building rooms. No Three.js,
// lights, textures, per-frame work, or world state is created by this planner.
// Parts are immutable and shared through a bounded recipe cache. Coordinates
// are room-local (origin in the centre, +Z the default entrance). Collision
// parts are furniture-local; consumers rotate them with the furniture, rather
// than making one tall, solid collider around a table and all its chairs.
const hash = value => { let h = 2166136261; for (const c of String(value)) h = Math.imul(h ^ c.charCodeAt(0), 16777619); return h >>> 0; };
const clamp = (n, a, b) => Math.max(a, Math.min(b, n));
const EPSILON = 1e-7;
const overlap = (a, b, gap = 0) => a[0] < b[2] + gap && a[2] > b[0] - gap && a[1] < b[3] + gap && a[3] > b[1] - gap;
const contains = (a, b) => a[0] >= b[0] - 1e-7 && a[1] >= b[1] - 1e-7 && a[2] <= b[2] + 1e-7 && a[3] <= b[3] + 1e-7;
const palettes = {
  residential: { wall: '#cfbfaa', floor: '#846046', accent: '#6e6656', wood: '#654632', metal: '#ad9162' },
  hotel: { wall: '#d4c6ae', floor: '#806249', accent: '#733f4b', wood: '#584034', metal: '#b59a66' },
  hospital: { wall: '#dddcca', floor: '#a5b5ad', accent: '#527f78', wood: '#8c7458', metal: '#a0aaa6' },
  club: { wall: '#bba791', floor: '#604638', accent: '#6e3342', wood: '#4e332c', metal: '#b0935b' },
  office: { wall: '#ccc3ae', floor: '#89745c', accent: '#53655b', wood: '#65503d', metal: '#a28d63' },
  shop: { wall: '#ccbea5', floor: '#998771', accent: '#6e4850', wood: '#6e523b', metal: '#ae9868' },
  workshop: { wall: '#c2bba7', floor: '#88887d', accent: '#465e59', wood: '#80704e', metal: '#7f8985' },
  bank: { wall: '#d8cfb9', floor: '#a6967c', accent: '#763e45', wood: '#604634', metal: '#b49d65' },
  police: { wall: '#cdcbb8', floor: '#938c78', accent: '#3c5965', wood: '#6d5942', metal: '#919991' },
  fire_station: { wall: '#d0c3ac', floor: '#a4947b', accent: '#8a4640', wood: '#73563d', metal: '#949d97' },
};
const aliases = { mansion: 'residential', guesthouse: 'hotel', hotel_lobby: 'hotel', nightclub: 'club', strip_club: 'club', restaurant: 'club', civic: 'office', civic_building: 'office', retail: 'shop', pawnshop: 'shop', gun_shop: 'shop', bookmaker: 'shop', warehouse: 'workshop', print_shop: 'workshop' };
const names = {
  living_room: 'Гостиная', banquet_hall: 'Банкетный зал', hotel_lobby: 'Вестибюль и стойка отеля', hotel_lounge: 'Гостиная отеля', hotel_guestroom: 'Номер отеля',
  hospital_reception: 'Регистратура и ожидание', hospital_ward: 'Палата', dining_hall: 'Обеденный зал', club_hall: 'Бар и клубный зал', vip_lounge: 'Гостиная для гостей',
  civic_hall: 'Общественная приёмная', meeting_hall: 'Зал заседаний', print_hall: 'Печатный цех', workshop: 'Мастерская', shop_floor: 'Торговый зал', office: 'Рабочий кабинет',
  bedroom: 'Спальня', study: 'Кабинет', kitchen: 'Кухня', dining_room: 'Столовая', guest_bedroom: 'Гостевая спальня', treatment_room: 'Процедурная', nurse_station: 'Пост медсестры',
  pharmacy: 'Аптечная комната', manager_office: 'Кабинет управляющего', security_office: 'Комната охраны', stockroom: 'Кладовая', archive: 'Архив', backstage: 'Гримёрная', cash_office: 'Кассовый кабинет',
  police_duty: 'Дежурная часть', fire_ready_room: 'Комната пожарной команды', warehouse: 'Склад', vault: 'Хранилище',
};
const roleAliases = { living: 'living_room', hotel_dining: 'dining_hall', dining: 'dining_hall', hotel_kitchen: 'kitchen', guestroom: 'hotel_guestroom', hotel_room: 'hotel_guestroom', ward: 'hospital_ward', treatment: 'treatment_room', hospital_treatment: 'treatment_room', hospital_nurse: 'nurse_station', shop_sales: 'shop_floor', shop_store: 'stockroom', clubbar: 'club_hall', lounge: 'vip_lounge', residentialliving: 'living_room', residentialbed: 'bedroom', residentialkitchen: 'kitchen', hall: 'meeting_hall' };
const cache = new Map();
const CACHE_LIMIT = 192;

export function functionalFurnitureBounds(item) {
  const c = Math.abs(Math.cos(item.yaw || 0)), s = Math.abs(Math.sin(item.yaw || 0));
  const hx = (item.width * c + item.depth * s) / 2, hz = (item.width * s + item.depth * c) / 2;
  return [item.x - hx, item.z - hz, item.x + hx, item.z + hz];
}

function makeRecipe(kind, p, variation = 0) {
  const key = `${kind}:${Object.values(p).join(':')}:${variation % 2}`;
  if (cache.has(key)) return cache.get(key);
  const parts = [], collisionParts = [], cream = '#e2d9c4', linen = '#eee6d4', dark = '#313936';
  const add = (shape, x, y, z, w, h, d, color, metal = false, yaw = 0) => parts.push({ shape, position: [x, y, z], size: [w, h, d], color, ...(metal ? { metalness: .65 } : {}), ...(yaw ? { yaw } : {}) });
  const box = (x, y, z, w, h, d, color = p.wood, metal = false) => add('box', x, y, z, w, h, d, color, metal);
  const cyl = (x, y, z, w, h, color = p.metal, metal = true) => add('cylinder', x, y, z, w, h, w, color, metal);
  const solid = (x, y, z, w, h, d, type = 'body', cover = false) => collisionParts.push({ rect: [x - w / 2, z - d / 2, x + w / 2, z + d / 2], minY: y - h / 2, maxY: y + h / 2, kind: type, ...(cover ? { cover: true } : {}) });
  const legs = (w, d, top, thickness = .065, x = 0, z = 0, color = p.wood, collide = true) => {
    for (const lx of [-w / 2 + .08, w / 2 - .08]) for (const lz of [-d / 2 + .08, d / 2 - .08]) {
      box(x + lx, top / 2, z + lz, thickness, top, thickness, color);
      if (collide) solid(x + lx, top / 2, z + lz, thickness, top, thickness, 'leg');
    }
  };
  const table = (w, d, top, x = 0, z = 0) => { legs(w, d, top - .05, .065, x, z); box(x, top - .04, z, w, .08, d); solid(x, top - .04, z, w, .08, d, 'tabletop', true); };
  const chair = (x, z, yaw = 0) => {
    const at = parts.length, bt = collisionParts.length;
    legs(.49, .51, .45, .045, 0, 0, p.wood, false);
    box(0, .47, 0, .49, .065, .51); box(0, .52, .015, .43, .055, .43, p.accent); box(0, .8, -.23, .49, .5, .055, p.accent);
    solid(0, .49, 0, .49, .12, .51, 'seat'); solid(0, .8, -.23, .49, .5, .055, 'back');
    const c = Math.cos(yaw), s = Math.sin(yaw);
    for (let i = at; i < parts.length; i++) { const a = parts[i], [px, py, pz] = a.position; a.position = [x + px * c + pz * s, py, z - px * s + pz * c]; if (yaw) a.yaw = yaw; }
    for (let i = bt; i < collisionParts.length; i++) { const a = collisionParts[i], r = a.rect, points = [[r[0], r[1]], [r[2], r[1]], [r[2], r[3]], [r[0], r[3]]].map(([px, pz]) => [x + px * c + pz * s, z - px * s + pz * c]); a.rect = [Math.min(...points.map(v => v[0])), Math.min(...points.map(v => v[1])), Math.max(...points.map(v => v[0])), Math.max(...points.map(v => v[1]))]; }
  };
  const handles = (x, y, z, w = .14) => box(x, y, z, w, .025, .025, p.metal, true);
  const wheels = (w, d) => { for (const x of [-w / 2 + .08, w / 2 - .08]) for (const z of [-d / 2 + .08, d / 2 - .08]) cyl(x, .09, z, .09, .1, dark, false); };
  switch (kind) {
    case 'bed': case 'single_bed': {
      const w = kind === 'bed' ? 1.55 : 1.02;
      legs(w, 2.1, .25); box(0, .29, 0, w, .19, 2.04); box(0, .46, .015, w - .09, .19, 2, linen); box(0, .575, .32, w - .08, .06, 1.34, p.accent);
      box(0, .63, -1.02, w + .07, 1.12, .15); box(0, .93, -.93, w - .16, .31, .055, p.accent);
      for (const x of kind === 'bed' ? [-.37, .37] : [0]) box(x, .6, -.66, kind === 'bed' ? .63 : .75, .13, .43, cream);
      box(0, .62, .79, w - .04, .045, .3, cream); solid(0, .36, 0, w, .38, 2.04, 'bed'); solid(0, .63, -1.02, w + .07, 1.12, .15, 'headboard'); break;
    }
    case 'nightstand_lamp':
      box(0, .28, 0, .47, .53, .44); box(0, .37, .226, .4, .2, .02, p.wall); handles(0, .37, .247); cyl(0, .572, -.04, .21, .04); cyl(0, .775, -.04, .027, .38); cyl(0, 1.015, -.04, .32, .28, cream, false); solid(0, .28, 0, .47, .53, .46); break;
    case 'sofa': case 'armchair': {
      const w = kind === 'sofa' ? 2.2 : .89;
      legs(w, .94, .16, .065, 0, 0, p.wood, false); box(0, .3, 0, w - .07, .28, .85); box(0, .82, -.37, w, .59, .2, p.accent);
      for (const x of [-w / 2 + .08, w / 2 - .08]) box(x, .59, .015, .15, .6, .94, p.accent);
      const n = kind === 'sofa' ? 3 : 1;
      for (let i = 0; i < n; i++) { const x = (i - (n - 1) / 2) * (w - .33) / n; box(x, .51, .025, (w - .39) / n, .16, .7, p.accent); box(x, .84, -.238, (w - .37) / n, .38, .095, variation ? '#87675d' : '#8b5a60'); }
      if (kind === 'sofa') box(-.73, .7, .07, .3, .3, .14, cream);
      solid(0, .33, 0, w - .07, .5, .85, 'seat'); solid(0, .82, -.37, w, .59, .2, 'back', true);
      for (const x of [-w / 2 + .08, w / 2 - .08]) solid(x, .59, .015, .15, .6, .94, 'arm'); break;
    }
    case 'coffee_table':
      table(1.1, .65, .49); box(-.22, .51, .05, .29, .035, .31, cream); box(-.22, .535, .05, .28, .012, .3, p.accent); cyl(.28, .54, 0, .11, .1, p.metal, true); break;
    case 'chair': chair(0, 0); break;
    case 'dining_set': case 'meeting_table': {
      const meeting = kind === 'meeting_table', w = meeting ? 2.2 : 1.62;
      table(w, .93, .8); box(0, .807, 0, w - .2, .014, .25, cream);
      for (const x of [-w * .27, w * .27]) for (const s of [-1, 1]) {
        chair(x, s * .9, s > 0 ? Math.PI : 0);
        if (!meeting) { cyl(x, .824, s * .26, .23, .02, linen, false); cyl(x + .22, .86, s * .26, .067, .09, cream, false); }
        else box(x, .825, s * .23, .28, .022, .22, linen);
      }
      if (meeting) { chair(-1.52, 0, Math.PI / 2); chair(1.52, 0, -Math.PI / 2); }
      break;
    }
    case 'desk': case 'dressing_table':
      table(1.5, .75, .81); box(-.43, .42, -.005, .45, .66, .66); solid(-.43, .42, -.005, .45, .66, .66);
      for (const y of [.28, .56]) { box(-.43, y, .335, .39, .22, .022, p.accent); handles(-.43, y, .356); }
      if (kind === 'desk') { box(.18, .83, -.02, .4, .026, .3, cream); box(.49, .875, -.19, .18, .11, .14, p.metal); }
      else { box(0, 1.2, -.32, .96, .72, .05, p.metal, true); box(0, 1.2, -.285, .85, .61, .025, '#657f7b'); }
      break;
    case 'reception': case 'bar_counter': {
      const w = kind === 'bar_counter' ? 3.15 : 2.55;
      box(0, .54, 0, w - .06, 1.05, .7); box(0, 1.1, 0, w, .11, .87, cream); box(0, .57, .36, w - .2, .71, .025, p.accent);
      for (const x of [-w * .3, 0, w * .3]) box(x, .57, .379, .024, .76, .025, p.metal, true);
      box(0, .18, .409, w - .2, .035, .025, p.metal, true); box(-w * .31, 1.217, -.1, .29, .22, .26, dark); box(-w * .31, 1.34, -.1, .2, .03, .17, p.metal);
      if (kind === 'bar_counter') for (let i = 0; i < 4; i++) { cyl(.12 + i * .24, 1.24, -.07, .075, .17, i % 2 ? '#43685e' : '#906946', false); cyl(.12 + i * .24, 1.35, -.07, .035, .055, p.metal); }
      else box(.35, 1.17, 0, .46, .025, .31, p.accent);
      solid(0, .54, 0, w - .06, 1.05, .7, 'counter', true); solid(0, 1.1, 0, w, .11, .87, 'countertop', true); break;
    }
    case 'sideboard':
      box(0, .51, 0, 1.74, .94, .46); box(0, 1.005, 0, 1.8, .07, .53, cream);
      for (const x of [-.56, 0, .56]) { box(x, .51, .24, .51, .78, .025, p.accent); handles(x, .77, .264); }
      cyl(-.52, 1.1, 0, .25, .12, linen, false); cyl(.49, 1.16, 0, .15, .24, '#827453', false); solid(0, .51, 0, 1.74, .94, .46, 'cabinet', true); solid(0, 1.005, 0, 1.8, .07, .53, 'top', true); break;
    case 'wardrobe': case 'locker':
      box(0, .985, 0, 1.19, 1.97, .55, kind === 'locker' ? p.metal : p.wood, kind === 'locker');
      for (const x of [-.285, .285]) { box(x, 1.025, .29, .55, 1.82, .025, p.accent); handles(x + .18, 1.02, .314, .06); if (kind === 'locker') for (const y of [1.61, 1.67, 1.73]) box(x, y, .31, .25, .016, .015, dark); else box(x, 1.055, .308, .43, 1.51, .025, p.wood); }
      solid(0, .985, .015, 1.19, 1.97, .6, 'cabinet', true); break;
    case 'deposit_cabinet':
      // Sealed static deposit furniture belonging to the existing bank vault.
      // Its small compartment fronts are not new gameplay targets or loot IDs.
      box(0, .925, -.02, 1, 1.85, .32, '#465350', true);
      for (let row = 0; row < 6; row++) for (let col = 0; col < 3; col++) {
        const x = (col - 1) * .322, y = .17 + row * .303;
        box(x, y, .1465, .304, .28, .025, (row + col) % 2 ? '#7c8682' : '#6c7976', true);
        box(x, y + .035, .17, .078, .025, .018, p.metal, true);
        box(x, y - .045, .164, .062, .027, .008, cream);
      }
      solid(0, .925, 0, 1, 1.85, .36, 'deposit-cabinet', true); break;
    case 'archive': case 'bookcase': case 'goods_shelf': case 'bottle_shelf': case 'medicine_cabinet': case 'weapon_cabinet': {
      const medical = kind === 'medicine_cabinet', metal = medical || kind === 'weapon_cabinet', w = kind === 'bookcase' ? 1 : 1.38, d = .44;
      box(0, .985, -.195, w, 1.97, .05, metal ? p.metal : p.wood, metal);
      for (const x of [-w / 2 + .025, w / 2 - .025]) box(x, .985, 0, .05, 1.97, d, metal ? p.metal : p.wood, metal);
      for (const y of [.07, .67, 1.28, 1.9]) box(0, y, 0, w, .055, d, metal ? p.metal : p.wood, metal);
      if (kind === 'weapon_cabinet') {
        for (const x of [-.43, -.15, .15, .43]) { box(x, .68, .06, .085, .66, .1, p.wood); box(x, 1.16, .06, .035, .68, .05, dark); box(x + .033, .88, .09, .07, .18, .045, dark); }
      } else for (let row = 0; row < 3; row++) for (let col = 0; col < (kind === 'bookcase' ? 4 : 3); col++) {
        const x = kind === 'bookcase' ? (col - 1.5) * .19 : (col - 1) * .36, y = .115 + row * .61, color = [p.accent, cream, '#617169', '#946d4b'][(row + col + variation) % 4];
        if (medical || kind === 'bottle_shelf') { cyl(x, y + .17, 0, medical ? .14 : .1, .31, medical ? linen : color, false); cyl(x, y + .346, 0, medical ? .09 : .045, .04, p.accent, false); if (medical) box(x, y + .18, .074, .07, .1, .012, p.accent); }
        else { box(x, y + .19, 0, kind === 'bookcase' ? .115 : .28, .38, .29, color); if (kind !== 'bookcase') box(x, y + .19, .151, .16, .052, .012, linen); }
      }
      // Shelves block at their physical frame/surfaces, with no phantom box
      // around the open space above them or in front of the goods.
      solid(0, .985, -.195, w, 1.97, .05, 'shelf_back', true);
      for (const x of [-w / 2 + .025, w / 2 - .025]) solid(x, .985, 0, .05, 1.97, d, 'shelf_side');
      for (const y of [.07, .67, 1.28, 1.9]) solid(0, y, 0, w, .055, d, 'shelf');
      break;
    }
    case 'hospital_bed':
      wheels(1.03, 2.03); legs(1.03, 2.03, .5, .055, 0, 0, p.metal, false);
      box(0, .54, 0, 1.05, .13, 2.1, p.metal, true); box(0, .69, 0, .96, .2, 2.01, linen); box(0, .815, .34, .96, .05, 1.2, p.accent); box(0, .85, -.65, .69, .15, .42, cream);
      for (const z of [-1.055, 1.055]) { for (const x of [-.51, .51]) box(x, .88, z, .045, .65, .055, p.metal, true); box(0, 1.19, z, 1.06, .045, .055, p.metal, true); box(0, 1.035, z, .99, .21, .045, p.accent); solid(0, .91, z, 1.065, .605, .055, 'bed_end'); }
      for (const x of [-.53, .53]) { box(x, .98, -.12, .035, .035, 1.5, p.metal, true); for (const z of [-.85, .61]) box(x, .79, z, .035, .38, .035, p.metal, true); solid(x, .82, -.12, .035, .36, 1.5, 'bed_rail'); }
      solid(0, .63, 0, 1.05, .32, 2.1, 'bed'); break;
    case 'iv_stand':
      box(0, .065, 0, .5, .045, .05, p.metal, true); box(0, .065, 0, .05, .045, .5, p.metal, true); cyl(0, .98, 0, .035, 1.86); box(0, 1.86, 0, .41, .026, .026, p.metal, true);
      for (const x of [-.155, .155]) { box(x, 1.66, 0, .1, .24, .075, '#b9cfbb'); cyl(x, 1.508, 0, .03, .07, p.metal); box(x, 1.23, 0, .012, .49, .012, '#d3dac8'); }
      solid(0, .065, 0, .5, .045, .05, 'base'); solid(0, .065, 0, .05, .045, .5, 'base'); solid(0, .98, 0, .035, 1.86, .035, 'pole'); break;
    case 'bedside_cabinet':
      box(0, .36, 0, .48, .67, .49, p.wall); box(0, .716, 0, .52, .04, .53, p.metal, true); for (const y of [.23, .52]) { box(0, y, .26, .4, .24, .026, p.accent); handles(0, y, .282); } cyl(.1, .79, -.02, .09, .12, linen, false); solid(0, .37, 0, .52, .72, .55, 'cabinet'); break;
    case 'medicine_trolley':
      wheels(.72, .52); legs(.72, .52, .94, .035, 0, 0, p.metal, false);
      for (const y of [.29, .87]) { box(0, y, 0, .75, .045, .54, p.metal, true); box(0, y + .065, -.26, .75, .09, .025, p.accent); solid(0, y, 0, .75, .045, .54, 'shelf'); }
      for (const x of [-.34, .34]) solid(x, .54, 0, .035, .88, .5, 'frame');
      box(-.16, .43, 0, .31, .23, .35, cream); box(.16, .43, 0, .18, .23, .26, p.accent);
      for (const x of [-.21, .03, .22]) { cyl(x, .985, 0, .075, .17, linen, false); cyl(x, 1.079, 0, .048, .026, p.accent, false); } break;
    case 'bench':
      legs(1.8, .6, .46, .07, 0, 0, p.metal, false); box(0, .485, 0, 1.8, .09, .6, p.accent); box(0, .81, -.265, 1.8, .5, .07, p.accent);
      for (const x of [-.87, .87]) box(x, .65, 0, .05, .04, .6, p.metal, true);
      solid(0, .485, 0, 1.8, .09, .6, 'seat'); solid(0, .81, -.265, 1.8, .5, .07, 'back'); break;
    case 'kitchen_counter':
      box(0, .46, 0, 2.16, .87, .63, p.wood); box(0, .92, 0, 2.22, .065, .7, cream);
      for (const x of [-.8, -.27, .27, .8]) { box(x, .48, .331, .5, .73, .026, p.wall); handles(x, .76, .354); }
      box(-.58, .964, 0, .62, .025, .48, p.metal, true); box(-.58, .98, 0, .49, .013, .35, dark); cyl(-.58, 1.05, -.24, .035, .18); box(-.58, 1.13, -.18, .035, .026, .14, p.metal, true);
      box(.57, .966, 0, .69, .025, .54, dark); for (const x of [.4, .75]) for (const z of [-.13, .13]) cyl(x, .987, z, .2, .018, p.metal);
      solid(0, .48, 0, 2.22, .95, .72, 'counter', true); break;
    case 'refrigerator':
      box(0, .96, 0, .72, 1.91, .69, p.wall); box(0, 1.53, .359, .65, .64, .035, cream); box(0, .63, .359, .65, 1.09, .035, cream);
      for (const y of [1.3, 1]) box(-.25, y, .398, .035, .29, .035, p.metal, true); solid(0, .96, .022, .72, 1.91, .735, 'cabinet', true); break;
    case 'luggage_cart':
      wheels(.98, .69); box(0, .18, 0, 1.04, .09, .73, p.accent); for (const x of [-.48, .48]) cyl(x, .86, -.27, .04, 1.43); box(0, 1.59, -.27, .99, .04, .045, p.metal, true);
      box(-.21, .47, 0, .55, .49, .6, p.wood); box(.31, .47, 0, .33, .49, .54, p.accent); box(-.21, .8, .03, .66, .17, .5, cream); handles(-.21, .745, 0); handles(.31, .745, 0);
      solid(0, .44, 0, 1.02, .61, .73, 'luggage'); for (const x of [-.48, .48]) solid(x, .86, -.27, .04, 1.43, .04, 'frame'); break;
    case 'display_counter':
      box(0, .35, 0, 1.85, .64, .7); box(0, .84, -.28, 1.83, .65, .06, p.accent); box(0, 1.18, 0, 1.92, .07, .78, cream);
      for (const x of [-.92, .92]) box(x, .875, .33, .035, .61, .035, p.metal, true);
      for (const x of [-.58, 0, .58]) { box(x, .71, .03, .41, .09, .43, cream); box(x, .825, .03, .28, .13, .28, variation ? '#817650' : p.accent); }
      solid(0, .35, 0, 1.85, .64, .7, 'cabinet'); solid(0, 1.18, 0, 1.92, .07, .78, 'countertop', true); break;
    case 'workbench':
      table(2.1, .87, .94); box(0, .26, 0, 1.86, .055, .69, p.accent); box(-.53, 1.05, -.12, .52, .19, .4, p.accent); handles(-.53, 1.17, -.12, .2);
      box(.54, 1.01, .07, .27, .13, .19, p.metal, true); box(.54, 1.12, .07, .27, .1, .05, dark); box(.12, .97, .04, .32, .025, .38, cream); break;
    case 'printing_press':
      box(0, .34, 0, 1.58, .62, 1.47, p.accent); for (const x of [-.64, .64]) box(x, .97, -.1, .22, 1.17, 1.16, p.metal, true);
      box(0, 1.44, -.44, 1.24, .16, .32, p.accent); box(0, .87, .73, 1.41, .09, .44, p.metal, true); box(0, .954, .74, .98, .07, .35, linen);
      for (const z of [-.29, .08]) for (const x of [-.38, 0, .38]) cyl(x, 1.23, z, .27, .31, dark, false);
      box(.65, 1.4, .33, .25, .3, .28, p.accent); box(.65, 1.562, .33, .17, .025, .16, '#bb815d'); solid(0, .79, -.03, 1.58, 1.48, 1.5, 'machine', true); solid(0, .87, .73, 1.41, .09, .44, 'feed_table'); break;
    case 'paper_rolls':
      box(0, .09, 0, 1.24, .16, .82); for (const x of [-.38, 0, .38]) { cyl(x, .67, 0, .35, 1.02, cream, false); cyl(x, 1.187, 0, .085, .017, '#74634b', false); solid(x, .67, 0, .35, 1.02, .35, 'paper'); } solid(0, .09, 0, 1.24, .16, .82, 'pallet'); break;
    case 'music_console':
      box(0, .44, 0, 1.8, .83, .68, dark); box(0, .895, 0, 1.79, .06, .68); for (const x of [-.5, .5]) { cyl(x, .94, 0, .46, .03, dark, false); cyl(x, .962, 0, .09, .015); }
      for (const x of [-.15, 0, .15]) box(x, .947, .18, .035, .04, .18, p.metal, true); solid(0, .45, 0, 1.8, .89, .68, 'console', true); break;
    case 'planter':
      cyl(0, .23, 0, .44, .44, p.wood, false); cyl(0, .457, 0, .4, .026, '#504e36', false); cyl(0, .71, 0, .035, .55, '#616b45', false);
      add('sphere', -.09, .83, 0, .36, .51, .32, '#687d56'); add('sphere', .15, 1.025, -.03, .3, .52, .31, '#778459'); solid(0, .23, 0, .44, .44, .44, 'pot'); break;
    case 'functional_safe': break;
    default: throw new Error(`Unknown functional furniture: ${kind}`);
  }
  let width = kind === 'functional_safe' ? INTERIOR_SAFE_DIMENSIONS.width : 0, depth = kind === 'functional_safe' ? 2 * Math.max(Math.abs(INTERIOR_SAFE_DIMENSIONS.rear), Math.abs(INTERIOR_SAFE_DIMENSIONS.front)) : 0, height = kind === 'functional_safe' ? INTERIOR_SAFE_DIMENSIONS.height : 0;
  for (const part of parts) {
    const c = Math.abs(Math.cos(part.yaw || 0)), s = Math.abs(Math.sin(part.yaw || 0));
    width = Math.max(width, 2 * Math.abs(part.position[0]) + part.size[0] * c + part.size[2] * s);
    depth = Math.max(depth, 2 * Math.abs(part.position[2]) + part.size[2] * c + part.size[0] * s);
    height = Math.max(height, part.position[1] + part.size[1] / 2);
    Object.freeze(part.position); Object.freeze(part.size); Object.freeze(part);
  }
  for (const body of collisionParts) { Object.freeze(body.rect); Object.freeze(body); }
  const result = Object.freeze({ kind, width, depth, height, parts: Object.freeze(parts), collisionParts: Object.freeze(collisionParts), ...(kind === 'functional_safe' ? { dynamic: true, interactionReach: 1.25, interactionSide: '+z' } : {}) });
  if (cache.size >= CACHE_LIMIT) cache.delete(cache.keys().next().value);
  cache.set(key, result);
  return result;
}

function normalizePurpose(value, assetId) {
  const raw = typeof value === 'object' ? value?.kind : value;
  const source = String(raw || assetId || 'residential').toLowerCase();
  if (palettes[source] || aliases[source]) return { source, theme: aliases[source] || source };
  const match = /hotel|hospital|nightclub|strip_club|pawnshop|print_shop|gun_shop|bookmaker|bank|police|fire_station|workshop|warehouse|restaurant|civic|retail/.exec(source)?.[0];
  return { source: match || 'residential', theme: aliases[match] || match || 'residential' };
}
function roleFor(theme, level, roomIndex) {
  if (theme === 'hospital') return level ? (roomIndex % 3 ? 'hospital_ward' : 'treatment_room') : 'hospital_reception';
  if (theme === 'hotel') return level ? 'hotel_guestroom' : roomIndex ? 'dining_hall' : 'hotel_lobby';
  if (theme === 'club') return level ? 'vip_lounge' : 'club_hall';
  if (theme === 'shop') return level ? 'manager_office' : 'shop_floor';
  if (theme === 'workshop') return level ? 'stockroom' : 'workshop';
  if (theme === 'office' || theme === 'bank') return level ? 'office' : 'civic_hall';
  if (theme === 'police') return level ? 'security_office' : 'police_duty';
  if (theme === 'fire_station') return level ? 'fire_ready_room' : 'workshop';
  return level ? ['bedroom', 'study', 'guest_bedroom'][roomIndex % 3] : ['living_room', 'kitchen', 'dining_room'][roomIndex % 3];
}
function normalizedRect(value) {
  const r = Array.isArray(value) ? value : value?.rect || value?.bounds;
  return Array.isArray(r) && r.length >= 4 && r.slice(0, 4).every(Number.isFinite) && r[2] > r[0] && r[3] > r[1] ? r.slice(0, 4) : null;
}

export function planFunctionalRoom({ purpose, role, assetId = '', level = 0, roomIndex = 0, width, depth, seed = 0, door, connections = [], reserved = [] } = {}) {
  if (![width, depth].every(n => Number.isFinite(n) && n > 0) || !Number.isInteger(level) || level < 0 || !Number.isInteger(roomIndex) || roomIndex < 0) throw new Error('Functional room requires finite positive dimensions and non-negative integer indexes');
  const { source, theme } = normalizePurpose(purpose, assetId), variation = hash(`${seed}:${assetId}:${level}:${roomIndex}`), resolvedRole = roleAliases[role] || role || roleFor(theme, level, roomIndex);
  const p = { ...palettes[theme] }, hospital = theme === 'hospital', industrial = theme === 'workshop';
  if ((variation & 1) && !hospital && !industrial) p.accent = theme === 'club' || theme === 'hotel' ? '#5d705f' : '#7e4c4f';
  const result = { name: names[resolvedRole] || names[roleFor(theme, level, roomIndex)], role: resolvedRole, purpose: source, finish: hospital ? 'plaster' : industrial ? 'brick' : 'wood-panel', floorFinish: hospital ? 'matte-tile' : industrial ? 'concrete' : theme === 'bank' || resolvedRole === 'hotel_lobby' ? 'limestone-tile' : 'warm-parquet', palette: p, furniture: [], reserved: [], statistics: { parts: 0, collisionParts: 0, candidates: 0, edgeCandidates: 0, omitted: [] } };
  const usable = [-width / 2 + .13, -depth / 2 + .13, width / 2 - .13, depth / 2 - .13], blocks = reserved.map(normalizedRect).filter(Boolean), connected = [...connections];
  if (door && Number.isFinite(door.x) && Number.isFinite(door.z)) connected.unshift(door);
  if (!connected.length && !blocks.length) connected.push({ x: 0, z: depth / 2, width: Math.min(1.7, width - .3) });
  for (const d of connected) {
    if (!Number.isFinite(d?.x) || !Number.isFinite(d?.z)) continue;
    const clear = clamp(Number.isFinite(d.width) ? d.width : 1.7, 1.25, Math.max(1.25, Math.min(width, depth) - .26)) / 2;
    const onX = Math.abs(Math.abs(d.x) - width / 2) < Math.abs(Math.abs(d.z) - depth / 2), reach = 1.5;
    if (onX) { const s = Math.sign(d.x) || 1; blocks.push([Math.min(d.x, d.x - s * reach), d.z - clear, Math.max(d.x, d.x - s * reach), d.z + clear]); }
    else { const s = Math.sign(d.z) || 1; blocks.push([d.x - clear, Math.min(d.z, d.z - s * reach), d.x + clear, Math.max(d.z, d.z - s * reach)]); }
  }
  // Supplied stair/door paths are authoritative. A default front approach is
  // only needed for standalone recipes that have no layout path contract.
  if (!reserved.length && connected.length <= 1) blocks.push([-Math.min(.82, width * .23), depth * .12, Math.min(.82, width * .23), depth / 2]);
  result.reserved = blocks.map(r => r.slice());
  const area = width * depth, maxParts = area >= 100 ? 280 : area >= 45 ? 220 : 170, maxFurniture = area >= 100 ? 24 : 18, furniture = result.furniture, occupied = [];
  const localPoint = (anchor, dx, dz, yaw = anchor.yaw) => { const c = Math.cos(anchor.yaw), s = Math.sin(anchor.yaw); return { x: anchor.x + dx * c + dz * s, z: anchor.z - dx * s + dz * c, yaw }; };
  function place(kind, preferences = []) {
    const f = makeRecipe(kind, p, variation % 2);
    if (furniture.length >= maxFurniture || result.statistics.parts + f.parts.length > maxParts) { result.statistics.omitted.push({ kind, reason: 'part-budget' }); return null; }
    const candidates = [...preferences], previous = furniture.filter(v => v.kind === kind).length;
    if (kind === 'nightstand_lamp') for (const bed of furniture.filter(v => v.kind === 'bed' || v.kind === 'single_bed')) for (const s of [-1, 1]) candidates.push(localPoint(bed, s * (bed.width / 2 + f.width / 2 + .13), -bed.depth / 2 + f.depth / 2 + .19));
    if (kind === 'bedside_cabinet' || kind === 'iv_stand') for (const bed of furniture.filter(v => v.kind === 'hospital_bed')) for (const s of kind === 'iv_stand' ? [1, -1] : [-1, 1]) candidates.push(localPoint(bed, s * (bed.width / 2 + f.width / 2 + .13), -bed.depth / 2 + f.depth / 2 + (kind === 'iv_stand' ? .26 : .1)));
    if (kind === 'chair') for (const desk of furniture.filter(v => v.kind === 'desk' || v.kind === 'dressing_table')) candidates.push(localPoint(desk, 0, desk.depth / 2 + f.depth / 2 + .27, desk.yaw + Math.PI));
    if (kind === 'coffee_table') for (const sofa of furniture.filter(v => v.kind === 'sofa')) candidates.push(localPoint(sofa, 0, sofa.depth / 2 + f.depth / 2 + .34));
    const sideSign = variation & 2 ? 1 : -1;
    const order = /table|bed/.test(kind) ? [0, Math.PI, Math.PI / 2, -Math.PI / 2] : [0, sideSign * Math.PI / 2, -sideSign * Math.PI / 2, Math.PI];
    for (const yaw of order) {
      const c = Math.abs(Math.cos(yaw)), s = Math.abs(Math.sin(yaw)), hw = (f.width * c + f.depth * s) / 2, hd = (f.depth * c + f.width * s) / 2;
      if (hw * 2 > width - .26 || hd * 2 > depth - .26) continue;
      const left = usable[0] + hw, right = usable[2] - hw, back = usable[1] + hd, front = usable[3] - hd;
      const xs = previous % 2 ? [right, left, 0] : [left, right, 0];
      const zs = [back, front, clamp(-depth * .19, back, front), clamp(depth * .19, back, front)];
      // Forward faces into the room for wall-aligned cabinets and sofas.
      if (Math.abs(yaw) < .01) for (const x of xs) candidates.push({ x, z: back, yaw });
      else if (Math.abs(yaw - Math.PI) < .01) for (const x of xs) candidates.push({ x, z: front, yaw });
      else for (const z of zs) candidates.push({ x: yaw > 0 ? left : right, z, yaw });
      if (/table|hospital_bed|bed$/.test(kind)) for (const z of zs.slice(2)) for (const x of [left, right]) candidates.push({ x, z, yaw });
    }
    function accept(candidate) {
      result.statistics.candidates++;
      const item = { ...f, ...candidate }, b = functionalFurnitureBounds(item);
      if (!contains(b, usable) || blocks.some(r => overlap(b, r, .055)) || occupied.some(r => overlap(b, r, .13))) return null;
      if (kind === 'functional_safe') {
        const reach = localPoint(item, 0, item.depth / 2 + .6), clear = [reach.x - .5, reach.z - .5, reach.x + .5, reach.z + .5];
        if (!contains(clear, [-width / 2, -depth / 2, width / 2, depth / 2]) || occupied.some(r => overlap(clear, r, .02))) return null;
        item.interactionClearance = clear; blocks.push(clear);
      }
      furniture.push(item); occupied.push(b); result.statistics.parts += item.parts.length; result.statistics.collisionParts += item.collisionParts.length; return item;
    }
    for (const candidate of candidates) { const placed = accept(candidate); if (placed) return placed; }
    // A stair cut can leave a generous habitable pocket between the old wall
    // slots. Search its actual rectangle edges only after the cheap slots fail.
    // 16 coordinates per axis, 256 combinations per yaw: bounded work even
    // with many reserved paths; no per-frame search and no reduced clearances.
    if (/^(bed|single_bed|hospital_bed|sofa|dining_set|meeting_table|coffee_table|kitchen_counter|refrigerator|reception|bar_counter)$/.test(kind)) {
      for (const yaw of order) {
        const c = Math.abs(Math.cos(yaw)), s = Math.abs(Math.sin(yaw)), hx = (f.width * c + f.depth * s) / 2, hz = (f.depth * c + f.width * s) / 2;
        if (hx * 2 > width - .26 || hz * 2 > depth - .26) continue;
        const axisCandidates = (axis, half) => {
          const min = usable[axis] + half, max = usable[axis + 2] - half, values = [min, max, (min + max) / 2];
          const addEdges = (rects, gap) => { for (const r of rects) values.push(r[axis] - half - gap, r[axis + 2] + half + gap); };
          addEdges(blocks, .0551); addEdges(occupied, .1301);
          return [...new Set(values.filter(v => v >= min - EPSILON && v <= max + EPSILON).map(v => Math.round(v * 1e5) / 1e5))].sort((a, b) => Math.min(a - min, max - a) - Math.min(b - min, max - b)).slice(0, 16);
        };
        const xs = axisCandidates(0, hx), zs = axisCandidates(1, hz);
        for (const z of zs) for (const x of xs) { result.statistics.edgeCandidates++; const placed = accept({ x, z, yaw }); if (placed) return placed; }
      }
    }
    if (kind === 'bed') {
      const single = place('single_bed', preferences);
      if (single) { single.preferredKind = 'bed'; result.statistics.omitted.push({ kind: 'bed', reason: 'standard-single-bed-in-clear-space' }); return single; }
    }
    result.statistics.omitted.push({ kind, reason: 'clearance' }); return null;
  }
  const queue = [];
  const add = (...kinds) => queue.push(...kinds);
  const safe = () => add('functional_safe');
  const office = (includeSafe = false) => { add('desk', 'chair'); if (includeSafe) safe(); add('archive', 'armchair'); };
  switch (resolvedRole) {
    case 'bedroom': case 'guest_bedroom': case 'hotel_guestroom':
      add(width > 3.1 ? 'bed' : 'single_bed', 'nightstand_lamp', 'wardrobe'); if (area > 23) add('desk', 'chair'); if (theme === 'hotel' && area > 30) add('luggage_cart'); break;
    case 'hotel_lobby': add('reception', 'sofa', 'coffee_table', 'luggage_cart', 'armchair', 'planter'); if (area > 70) add('sofa', 'coffee_table'); break;
    case 'living_room':
      add('sofa', 'coffee_table'); if (theme === 'residential') add('kitchen_counter', 'refrigerator', 'dining_set'); add('armchair', 'bookcase', 'sideboard'); if (area > 65) add('planter'); break;
    case 'hotel_lounge': case 'vip_lounge':
      add('sofa', 'coffee_table', 'armchair', 'bookcase', 'sideboard'); if (area > 55) add('sofa', 'coffee_table', 'planter'); break;
    case 'banquet_hall': case 'dining_hall': case 'dining_room':
      add('dining_set', 'sideboard'); for (let i = 1; i < Math.min(5, Math.max(1, Math.floor(area / 26))); i++) add('dining_set'); if (area > 45) add('planter'); break;
    case 'club_hall':
      add('bar_counter', 'bottle_shelf', 'sofa', 'coffee_table', 'dining_set', 'music_console'); if (area > 95) add('sofa', 'coffee_table', 'dining_set'); break;
    case 'hospital_reception': add('reception', 'bench', 'bench', 'medicine_cabinet', 'medicine_trolley'); if (area > 60) add('bench', 'planter'); break;
    case 'hospital_ward': {
      const beds = Math.min(4, Math.max(1, Math.floor(area / 20)));
      for (let i = 0; i < beds; i++) add('hospital_bed', 'iv_stand', 'bedside_cabinet'); add('medicine_trolley'); if (area > 35) add('medicine_cabinet'); break;
    }
    case 'treatment_room': add('hospital_bed', 'iv_stand', 'medicine_trolley', 'medicine_cabinet', 'desk', 'chair'); break;
    case 'nurse_station': add('reception', 'medicine_cabinet', 'medicine_trolley', 'archive', 'chair'); break;
    case 'pharmacy': add('medicine_cabinet', 'medicine_cabinet', 'reception', 'medicine_trolley'); break;
    case 'kitchen': add('kitchen_counter', 'refrigerator', 'sideboard'); if (area > 30) add('dining_set'); break;
    case 'meeting_hall': add('meeting_table', 'sideboard', 'bookcase'); if (area > 85) add('meeting_table', 'bench'); break;
    case 'civic_hall': add('reception', 'bench', 'desk', 'chair', 'archive', 'bench'); break;
    case 'shop_floor':
      add(source === 'gun_shop' ? 'weapon_cabinet' : source === 'bookmaker' ? 'reception' : 'display_counter');
      add(source === 'gun_shop' ? 'weapon_cabinet' : source === 'bookmaker' ? 'desk' : 'goods_shelf');
      add(source === 'bookmaker' ? 'chair' : 'display_counter', 'goods_shelf'); if (area > 70) add('display_counter', 'goods_shelf'); break;
    case 'print_hall': add('printing_press', 'paper_rolls', 'workbench', 'archive'); if (area > 80) add('printing_press', 'paper_rolls'); break;
    case 'workshop':
      add('workbench', 'locker', 'goods_shelf'); if (theme === 'fire_station') add('bench', 'locker'); else if (source === 'print_shop') add('printing_press', 'paper_rolls'); else add('workbench'); break;
    case 'stockroom': case 'warehouse': add('goods_shelf', 'goods_shelf', 'workbench'); if (area > 40) add('goods_shelf', industrial ? 'paper_rolls' : 'sideboard'); break;
    case 'archive': add('archive', 'archive', 'desk', 'chair'); if (area > 40) add('archive'); break;
    case 'backstage': add('dressing_table', 'chair', 'wardrobe', 'sofa'); break;
    case 'manager_office': case 'cash_office': office(true); break;
    case 'security_office': office(theme !== 'bank'); if (theme !== 'bank') add(theme === 'police' ? 'weapon_cabinet' : 'locker'); break;
    case 'vault': add('deposit_cabinet', 'deposit_cabinet', 'desk', 'chair'); break;
    case 'study': office(variation % 3 === 0); add('bookcase'); break;
    case 'police_duty': add('reception', 'desk', 'chair', 'archive', 'bench', 'locker'); break;
    case 'fire_ready_room': add('locker', 'bench', 'dining_set', 'kitchen_counter'); break;
    default: office(theme === 'bank' && level > 0); break;
  }
  for (const kind of queue) place(kind);
  // No unrelated console fallback: a rejected bed cannot silently turn a hotel
  // bedroom into an office. The layout audit can act on these explicit omissions.
  result.reserved = blocks.map(r => r.slice());
  return result;
}

export function functionalFurnishingCacheStats() { return { entries: cache.size, limit: CACHE_LIMIT }; }
