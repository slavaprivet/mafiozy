# -*- coding: utf-8 -*-
from __future__ import annotations

from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime

ROOT = Path(__file__).resolve().parent
WORLD = ROOT / "world.html"
MARKER = "MAFIOZY_JSON_ONLY_ENGINE_7_2_TRUE_NATIVE"

if not WORLD.exists():
    print("ОШИБКА: world.html не найден.")
    sys.exit(1)

original_text = WORLD.read_text(encoding="utf-8", errors="strict")
text = original_text

def validate_inline_javascript(html_text: str) -> tuple[bool, str]:
    scripts = re.findall(r"<script\b[^>]*>(.*?)</script>", html_text, flags=re.S | re.I)
    errors = []
    for script_index, javascript in enumerate(scripts, 1):
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".js", encoding="utf-8", delete=False
        ) as temporary:
            temporary.write(javascript)
            temporary_name = temporary.name
        try:
            result = subprocess.run(
                ["node", "--check", temporary_name],
                text=True,
                capture_output=True,
                timeout=60,
            )
            if result.returncode:
                errors.append(
                    f"script #{script_index}\n{result.stderr or result.stdout}"
                )
        except FileNotFoundError:
            return False, "Node.js не найден."
        finally:
            Path(temporary_name).unlink(missing_ok=True)
    return (not errors), "\n\n".join(errors[:3])

# Движок ставится один раз. Повторный запуск только проверяет файл.
if MARKER in original_text:
    ok, details = validate_inline_javascript(original_text)
    if not ok:
        print("ОШИБКА: движок уже установлен, но world.html повреждён.")
        print(details)
        sys.exit(20)
    print("Mafiozy JSON Only Engine 7.2 True Native уже установлен.")
    print("world.html не переписывался. Карта хранится только в map_overrides.json.")
    sys.exit(0)

# Резервная копия до любых изменений.
backup_dir = ROOT / "_backups" / f"{datetime.now():%Y%m%d_%H%M%S}_before_json_map_engine_4_0"
backup_dir.mkdir(parents=True, exist_ok=True)
shutil.copy2(WORLD, backup_dir / "world.html")
if (ROOT / "map_overrides.json").exists():
    shutil.copy2(ROOT / "map_overrides.json", backup_dir / "map_overrides.json")

# Удаляем только прежние UI-блоки редактора. Render helper поворота пока сохраняем.
editor_patterns = [
    r'<script>\s*// MAFIOZY_DEV_MAP_EDITOR_V1.*?</script>\s*',
    r'<script>\s*// MAFIOZY_STUDIO_WORLD_EDITOR_V1(?:_\d+)*.*?</script>\s*',
    r'<script>\s*// MAFIOZY_WORLD_EDITOR_2_0.*?</script>\s*',
    r'<script>\s*// MAFIOZY_WORLD_EDITOR_2_1.*?</script>\s*',
    r'<script>\s*// MAFIOZY_WORLD_EDITOR_3_0_STABLE.*?</script>\s*',
    r'<script>\s*// MAFIOZY_JSON_ONLY_ENGINE_7_2_TRUE_NATIVE.*?</script>\s*',
]
for pattern in editor_patterns:
    text = re.sub(pattern, "", text, flags=re.S)

# Находим строго цикл пляжного декора.
beach_comment = "  // Пляжный декор — пальмы, зонтики, шезлонги, дорожки, лодки, вышка."
loop_marker = "  for (const d of _beachDecor) {"
comment_pos = text.find(beach_comment)
loop_start = text.find(loop_marker, comment_pos)

if comment_pos < 0 or loop_start < 0:
    print("ОШИБКА: цикл _beachDecor не найден.")
    sys.exit(2)

brace_start = text.find("{", loop_start)
depth = 0
loop_end = None
for index in range(brace_start, len(text)):
    char = text[index]
    if char == "{":
        depth += 1
    elif char == "}":
        depth -= 1
        if depth == 0:
            loop_end = index + 1
            break

if loop_end is None:
    print("ОШИБКА: не удалось определить конец цикла _beachDecor.")
    sys.exit(3)

before = text[:loop_start]
beach = text[loop_start:loop_end]
after = text[loop_end:]

# Точечно убираем экспериментальные обёртки ТОЛЬКО вне _beachDecor.
broken_block = "draw: () => _mfzDrawDecorRotated(d, () => {)"
before = before.replace(broken_block, "draw: () => {")
after = after.replace(broken_block, "draw: () => {")

one_line_wrapper = re.compile(
    r'draw:\s*\(\)\s*=>\s*_mfzDrawDecorRotated'
    r'\(d,\s*\(\)\s*=>\s*(.*?)\)\}\);'
)

def unwrap(match: re.Match[str]) -> str:
    return "draw: () => " + match.group(1) + "});"

before, fixed_before = one_line_wrapper.subn(unwrap, before)
after, fixed_after = one_line_wrapper.subn(unwrap, after)
text = before + beach + after

# В текущем повреждённом файле ожидаем 11-12 чужих обёрток.
fixed_total = fixed_before + fixed_after + original_text.count(broken_block)
print(f"Исправлено чужих обёрток поворота: {fixed_total}")

# Добавляем helper поворота, только если его ещё нет.
helper_anchor = "function drawBeachUmbrella(r, c, col) {"
helper_code = r"""
// MAFIOZY_UNIVERSAL_DECOR_ROTATION_3_1_PRECISE
function _mfzDrawDecorRotated(d, drawFn) {
  const a = Number(d && d._studioRot || 0);
  if (!a) { drawFn(); return; }
  const p = w2s(d.r, d.c);
  ctx.save();
  ctx.translate(p.x, p.y);
  ctx.rotate(a);
  ctx.translate(-p.x, -p.y);
  drawFn();
  ctx.restore();
}

"""

# Нормализуем старый helper-маркер, не дублируя функцию.
text = text.replace(
    "// MAFIOZY_UNIVERSAL_DECOR_ROTATION_2_1",
    "// MAFIOZY_UNIVERSAL_DECOR_ROTATION_3_1_PRECISE"
)

if "function _mfzDrawDecorRotated(d, drawFn)" not in text:
    if helper_anchor not in text:
        print("ОШИБКА: не найден якорь функций пляжного декора.")
        sys.exit(4)
    text = text.replace(helper_anchor, helper_code + helper_anchor, 1)

# Повторно определяем строгий диапазон пляжа после исправлений.
comment_pos = text.find(beach_comment)
loop_start = text.find(loop_marker, comment_pos)
brace_start = text.find("{", loop_start)
depth = 0
loop_end = None
for index in range(brace_start, len(text)):
    if text[index] == "{":
        depth += 1
    elif text[index] == "}":
        depth -= 1
        if depth == 0:
            loop_end = index + 1
            break

beach = text[loop_start:loop_end]
outside = text[:loop_start] + text[loop_end:]

# Если пляж ещё не обёрнут — оборачиваем только конкретные draw-строки внутри цикла.
if "_mfzDrawDecorRotated(d, () =>" not in beach:
    lines = beach.splitlines(keepends=True)
    wrapped = 0
    result = []
    callback_pattern = re.compile(r'(draw:\s*\(\)\s*=>\s*)([^;\n]+)(\}\);)')
    for line in lines:
        if "draw:" in line and "drawPlankPath" in line or (
            "draw:" in line and any(name in line for name in [
                "drawBigPalmTree(", "drawPalmTree(", "drawBeachUmbrella(",
                "drawBeachChair(", "drawBeachedBoat(", "drawLifeguardTower(",
                "drawShell(", "drawTikiBar(", "drawSurfboard(", "drawBeachBall(",
                "drawBeachTowel(", "drawSandcastle(", "drawVolleyNet(",
                "drawIceCreamCart(", "drawStarfish(", "drawCrab(",
                "drawBeachGrass(", "drawBeachPuddle(", "drawFloatRing("
            ])
        ):
            match = callback_pattern.search(line)
            if match:
                line = (
                    line[:match.start()]
                    + match.group(1)
                    + "_mfzDrawDecorRotated(d, () => "
                    + match.group(2)
                    + ")"
                    + match.group(3)
                    + line[match.end():]
                )
                wrapped += 1
        result.append(line)
    beach = "".join(result)
    text = text[:loop_start] + beach + text[loop_end:]
    print(f"Добавлено безопасных пляжных обёрток: {wrapped}")

# Жёсткая проверка области: 20 пляжных вызовов, 0 вызовов за её пределами.
comment_pos = text.find(beach_comment)
loop_start = text.find(loop_marker, comment_pos)
brace_start = text.find("{", loop_start)
depth = 0
loop_end = None
for index in range(brace_start, len(text)):
    if text[index] == "{":
        depth += 1
    elif text[index] == "}":
        depth -= 1
        if depth == 0:
            loop_end = index + 1
            break

beach = text[loop_start:loop_end]
outside = text[:loop_start] + text[loop_end:]
beach_count = beach.count("_mfzDrawDecorRotated(d, () =>")
outside_count = outside.count("_mfzDrawDecorRotated(d, () =>")

# В версии 7 число веток пляжного декора не фиксируется: игра может развиваться.
if beach_count < 1:
    print('ОШИБКА: не найдено ни одной пляжной обёртки поворота.')
    sys.exit(5)
if outside_count != 0:
    print(f"ОШИБКА: за пределами пляжа осталось {outside_count} чужих обёрток.")
    sys.exit(6)

# Устанавливаем один чистый UI Editor 3.1.
if "</body>" not in text:
    print("ОШИБКА: </body> не найден.")
    sys.exit(7)

script = r"""
<script>
// MAFIOZY_WORLD_EDITOR_2_1
(() => {
  const LOCAL = location.hostname === '127.0.0.1' || location.hostname === 'localhost';
  const LOAD_URL = LOCAL ? '/__studio_map' : './map_overrides.json';

  let active=false, layer='city', selected=null, dragging=false, brushMode=null, brushLast=null, clipboard=null,lastPickKey='',lastPickCycle=0;
  let panel=null, info=null, snap=true, loaded=false;
  let baseMap=null, undoStack=[], redoStack=[];

  
  const DECOR_GROUPS = {
    nature:{
      title:'🌴 Родная природа',
      items:[
        ['palm','🌴 Пальма'],['grass','🌿 Пляжная трава'],
        ['shell','🐚 Ракушка'],['starfish','⭐ Морская звезда'],
        ['crab','🦀 Краб'],['puddle','💧 Лужица']
      ]
    },
    beach:{
      title:'🏖 Родной пляжный декор',
      items:[
        ['umbrella','⛱ Зонт'],['chair','🪑 Шезлонг'],
        ['towel','🟦 Полотенце'],['surfboard','🏄 Серф-доска'],
        ['ball','🏐 Мяч'],['float_ring','🛟 Круг'],
        ['sandcastle','🏰 Замок из песка'],['volley','🏐 Волейбольная сетка']
      ]
    },
    structures:{
      title:'🏝 Родные постройки',
      items:[
        ['tiki_bar','🍹 Тики-бар'],['lifeguard','🛟 Спасательная вышка'],
        ['plank','🪵 Деревянный настил'],['icecream','🍦 Тележка мороженого'],
        ['boat','🚤 Лодка']
      ]
    }
  };

  const DECOR_TYPES = Object.values(DECOR_GROUPS).flatMap(group => group.items);

  const ASSET_MATERIALS = {
    wood:{base:'#8b5a32',roughness:.85},
    metal:{base:'#56636b',roughness:.35},
    stone:{base:'#7d8588',roughness:.95},
    concrete:{base:'#9da4a6',roughness:.8},
    foliage:{base:'#2e7b43',roughness:1},
    glass:{base:'#75c5dc',roughness:.12},
    neon:{base:'#ff3bd5',roughness:.05},
    sand:{base:'#d9bc78',roughness:1}
  };

  const DISTRICT_BRUSHES = {
    coast:{
      title:'🌴 Кисть: Родное побережье',
      pool:['palm','grass','shell','starfish','crab'],
      spacing:2.2
    },
    lounge:{
      title:'🏖 Кисть: Зона отдыха',
      pool:['umbrella','chair','towel','surfboard','ball','float_ring'],
      spacing:2.4
    }
  };

  const DISTRICT_PREFABS = {
    beach_lounge:{
      title:'🏖 Префаб: Родная зона отдыха',
      objects:[
        ['tiki_bar',0,0,1,0],
        ['palm',-2.3,-1.3,1,0],
        ['palm',2.3,-1.3,1,0],
        ['umbrella',-1.5,1.2,1,0],
        ['umbrella',1.5,1.2,1,0],
        ['chair',-1.8,2.0,1,.12],
        ['chair',-1.0,2.2,1,.12],
        ['chair',1.0,2.2,1,-.12],
        ['chair',1.8,2.0,1,-.12],
        ['towel',0,2.8,1,0],
        ['surfboard',-2.6,.5,1,.15],
        ['float_ring',2.6,.5,1,0]
      ]
    },
    lifeguard_spot:{
      title:'🛟 Префаб: Спасательный пост',
      objects:[
        ['lifeguard',0,0,1,0],
        ['palm',-2,-1,1,0],
        ['umbrella',2,1,1,0],
        ['chair',1.5,1.8,1,.1],
        ['float_ring',-1.4,1.3,1,0],
        ['surfboard',-2.2,.6,1,.1]
      ]
    },
    beach_games:{
      title:'🏐 Префаб: Пляжные игры',
      objects:[
        ['volley',0,0,1,0],
        ['ball',0,1.3,1,0],
        ['umbrella',-2.4,1.5,1,0],
        ['chair',-2.2,2.2,1,.1],
        ['umbrella',2.4,1.5,1,0],
        ['chair',2.2,2.2,1,-.1]
      ]
    }
  };



  const LEGACY_NATIVE_MAP = {
    palm_tall:'palm',palm_coconut:'palm',palm_bent:'palm',
    beach_bush:'grass',beach_grass_tuft:'grass',
    rock_large:'shell',rock_cluster:'shell',driftwood:'plank',
    shell_cluster:'shell',starfish_group:'starfish',
    beach_shower:'umbrella',changing_booth:'umbrella',
    lifeguard_modern:'lifeguard',beach_bar:'tiki_bar',
    drink_cooler:'icecream',beach_sign:'plank',
    jet_ski:'boat',buoy_line:'float_ring',wood_pier_piece:'plank',
    tiki_torch:'palm',modern_bench:'chair',city_bin:'ball',
    flower_planter:'grass',city_fountain:'float_ring',
    ad_panel:'plank',bus_stop:'umbrella',cafe_table:'umbrella',
    modern_lamp:'palm',bollard:'ball',bike_rack:'plank',
    news_kiosk:'tiki_bar',street_clock:'palm',
    trash_pile:'shell',old_fence:'plank',graffiti_wall:'plank',
    wood_pallets:'plank',tire_stack:'float_ring',wrecked_car:'boat',
    clothes_line:'volley',rust_lamp:'palm',cardboard_home:'umbrella',
    broken_sofa:'chair',cargo_container:'tiki_bar',
    industrial_barrels:'ball',pipe_stack:'plank',fuel_tank:'boat',
    wood_crates:'plank',generator:'icecream',flood_light:'palm',
    chain_fence:'volley',warning_sign:'plank',forklift:'boat',
    cable_reel:'float_ring',industrial_vent:'icecream',
    luxury_fountain:'float_ring',pool_small:'puddle',
    hedge_block:'grass',luxury_planter:'grass',
    marble_statue:'sandcastle',guard_booth:'lifeguard',
    gold_lamp:'palm',villa_gate:'volley',topiary:'grass',
    sports_car_prop:'boat',oak_tree:'palm',pine_tree:'palm',
    wild_bush:'grass',country_rock:'shell',gazebo:'umbrella',
    wood_bridge:'plank',farm_fence:'plank',hay_bales:'towel',
    water_well:'float_ring',camp_fire:'starfish',
    picnic_table:'chair',mail_box:'plank',
    neon_sign:'plank',club_rope:'volley',club_light:'palm',
    taxi_prop:'boat',casino_sign:'plank',night_billboard:'plank',
    street_barrier:'volley',vip_booth:'lifeguard',
    led_strip:'plank',night_food_cart:'icecream'
  };

  function migrateLegacyDecor(list){
    let changed=0;
    for(const d of list){
      if(d && LEGACY_NATIVE_MAP[d.kind]){
        d.kind=LEGACY_NATIVE_MAP[d.kind];
        d._studioRot=Number(d._studioRot||0);
        d.scale=Number(d.scale||1);
        changed++;
      }
    }
    if(changed)console.info(`Studio 7.2: заменено экспериментальных объектов: ${changed}`);
    return changed;
  }

  const ready=()=>typeof MAP!=='undefined'&&Array.isArray(MAP)&&
    typeof _beachDecor!=='undefined'&&Array.isArray(_beachDecor)&&
    typeof canvas!=='undefined'&&typeof w2s==='function'&&typeof s2w==='function';

  function clone(v){return JSON.parse(JSON.stringify(v));}
  function cleanDecor(d){
    const out={};
    for(const [k,v] of Object.entries(d)) {
      if(!k.startsWith('_') || k==='_studioRot') out[k]=v;
    }
    if(!out.id) out.id=`asset:${out.kind||'decor'}:${Date.now()}:${Math.random().toString(36).slice(2,9)}`;
    if(typeof out.scale!=='number') out.scale=1;
    if(typeof out._studioRot!=='number') out._studioRot=0;
    return out;
  }

  function snapshot(){
    return JSON.stringify({
      map:MAP.map(row=>row.slice()),
      decor:_beachDecor.map(cleanDecor)
    });
  }
  function restore(raw){
    const s=JSON.parse(raw);
    for(let r=0;r<Math.min(MAP.length,s.map.length);r++){
      MAP[r].splice(0,MAP[r].length,...s.map[r]);
    }
    _beachDecor.splice(0,_beachDecor.length,...s.decor.map(x=>clone(x)));
    selected=null;updateInfo();
  }
  function pushUndo(){
    undoStack.push(snapshot());
    if(undoStack.length>40)undoStack.shift();
    redoStack.length=0;
  }
  function undo(){
    if(!undoStack.length)return;
    redoStack.push(snapshot());restore(undoStack.pop());
  }
  function redo(){
    if(!redoStack.length)return;
    undoStack.push(snapshot());restore(redoStack.pop());
  }

  function screen(e){
    const rect=canvas.getBoundingClientRect();
    return {
      x:(e.clientX-rect.left)*(canvas.width/rect.width),
      y:(e.clientY-rect.top)*(canvas.height/rect.height)
    };
  }

  function baseTile(r,c){
    if(r<=0||c<=0||r>=MAP_ROWS-1||c>=MAP_COLS-1)return 1;
    if(r>=140)return 15;
    const roadR=(r%BLOCK<=3),roadC=(c%BLOCK<=3);
    if(roadR||roadC)return 0;
    const sideR=(r%BLOCK===4)||(r%BLOCK===BLOCK-1);
    const sideC=(c%BLOCK===4)||(c%BLOCK===BLOCK-1);
    if(sideR||sideC)return 9;
    return 8;
  }

  function lockedBuilding(r,c){
    const key=r+','+c;
    if(typeof BURJ_POS!=='undefined'&&r===BURJ_POS.r&&c===BURJ_POS.c)return true;
    if(typeof POI_BY_RC!=='undefined'&&POI_BY_RC.get(key))return true;
    if(typeof BUSINESS_BY_RC!=='undefined'&&BUSINESS_BY_RC.get(key))return true;
    if(typeof _bankTileSet!=='undefined'&&_bankTileSet.has(key))return true;
    return false;
  }

  function visibleBounds(){
    const a=s2w(-100,-180),b=s2w(canvas.width+100,canvas.height+100);
    return {
      r0:Math.max(0,Math.floor(Math.min(a.r,b.r))-8),
      r1:Math.min(MAP_ROWS,Math.ceil(Math.max(a.r,b.r))+8),
      c0:Math.max(0,Math.floor(Math.min(a.c,b.c))-8),
      c1:Math.min(MAP_COLS,Math.ceil(Math.max(a.c,b.c))+8)
    };
  }

  function cityHit(x,y){
    const b=visibleBounds();
    let best=null,bestScore=Infinity;
    for(let r=b.r0;r<b.r1;r++)for(let c=b.c0;c<b.c1;c++){
      const t=MAP[r]?.[c];
      if(t<1||t>7)continue;
      if(t===1&&lockedBuilding(r,c))continue;

      const p=w2s(r+.5,c+.5);
      let left=p.x-30,right=p.x+30,top=p.y-50,bottom=p.y+18,cy=p.y-20;
      if(t===1){
        const seed=((r*73+c*131)%7)/7;
        const H=isoH(1.3+seed*1.4);
        left=p.x-42;right=p.x+42;top=p.y-H-24;bottom=p.y+20;cy=p.y-H*.48;
      }else if(t===6){
        left=p.x-28;right=p.x+28;top=p.y-85;bottom=p.y+16;cy=p.y-38;
      }else if(t===7){
        left=p.x-18;right=p.x+18;top=p.y-75;bottom=p.y+15;cy=p.y-34;
      }
      if(x<left||x>right||y<top||y>bottom)continue;
      const score=Math.abs(x-p.x)*.7+Math.abs(y-cy);
      if(score<bestScore){
        bestScore=score;
        best={type:'map',r,c,t,kind:t===1?'building':['','building','car','crate','barrel','dumpster','tree','lamp'][t]};
      }
    }
    return best;
  }

  const _mfzHitProfiles={
    palm_tall:[42,125],palm_coconut:[42,118],palm_bent:[52,112],
    oak_tree:[45,125],pine_tree:[42,130],gazebo:[55,105],
    cargo_container:[58,62],bus_stop:[50,92],lifeguard_modern:[48,110],
    beach_bar:[55,82],news_kiosk:[48,78],city_fountain:[52,45],luxury_fountain:[58,50],
    pool_small:[62,38],wrecked_car:[52,42],sports_car_prop:[52,42],taxi_prop:[52,42],
    neon_sign:[46,112],casino_sign:[48,115],night_billboard:[52,115],
    old_fence:[52,62],farm_fence:[52,62],chain_fence:[52,62],wood_bridge:[56,46],wood_pier_piece:[56,46]
  };

  function decorCandidates(x,y){
    const hits=[];
    for(let i=_beachDecor.length-1;i>=0;i--){
      const d=_beachDecor[i];
      if(!d||typeof d.r!=='number'||typeof d.c!=='number')continue;
      const p=w2s(d.r,d.c),scale=Math.max(.35,Math.min(3,Number(d.scale||1)));
      const profile=(
        /palm/.test(d.kind)?[42,120]:
        /boat|surfboard/.test(d.kind)?[55,45]:
        /lifeguard|tiki_bar/.test(d.kind)?[58,100]:
        /umbrella|volley/.test(d.kind)?[48,75]:
        /chair|towel|plank/.test(d.kind)?[48,42]:
        [36,58]
      );
      const rx=profile[0]*scale,ry=profile[1]*scale;
      if(x<p.x-rx||x>p.x+rx||y<p.y-ry||y>p.y+26*scale)continue;
      const score=Math.abs(x-p.x)/rx+Math.abs(y-(p.y-ry*.3))/ry;
      hits.push({score,index:i,hit:{type:'decor',index:i,obj:d,kind:d.kind}});
    }
    hits.sort((a,b)=>a.score-b.score||b.index-a.index);
    return hits.map(x=>x.hit);
  }

  function decorHit(x,y){
    const hits=decorCandidates(x,y);
    if(!hits.length){lastPickKey='';lastPickCycle=0;return null;}
    const key=`${Math.round(x/12)}:${Math.round(y/12)}:${hits.map(h=>h.obj.id||h.index).join(',')}`;
    if(key===lastPickKey)lastPickCycle=(lastPickCycle+1)%hits.length;
    else{lastPickKey=key;lastPickCycle=0;}
    return hits[lastPickCycle];
  }

  function pick(e){
    const p=screen(e);
    // Декор выбирается в обеих вкладках: районные объекты могут стоять по всему городу.
    const decor=decorHit(p.x,p.y);
    if(decor)return decor;
    return layer==='city'?cityHit(p.x,p.y):null;
  }

  function canPlaceMap(r,c,t){
    if(r<=0||c<=0||r>=MAP_ROWS-1||c>=MAP_COLS-1)return false;
    if(t===1&&lockedBuilding(r,c))return false;
    const cur=MAP[r]?.[c];
    return cur===0||cur===8||cur===9||cur===15;
  }

  function moveSelected(e){
    if(!selected)return;
    const p=screen(e),w=s2w(p.x,p.y);
    if(selected.type==='decor'){
      selected.obj.r=snap?Math.round(w.r*4)/4:w.r;
      selected.obj.c=snap?Math.round(w.c*4)/4:w.c;
    }else{
      selected.previewR=Math.round(w.r);
      selected.previewC=Math.round(w.c);
      selected.valid=canPlaceMap(selected.previewR,selected.previewC,selected.t);
    }
    updateInfo();
  }

  function commitMove(){
    if(!selected||selected.type!=='map'||selected.previewR==null||!selected.valid)return;
    MAP[selected.r][selected.c]=baseTile(selected.r,selected.c);
    MAP[selected.previewR][selected.previewC]=selected.t;
    selected.r=selected.previewR;selected.c=selected.previewC;
    selected.previewR=null;selected.previewC=null;selected.valid=null;
  }

  function removeSelected(){
    if(!selected)return;
    pushUndo();
    if(selected.type==='decor'){
      _beachDecor.splice(selected.index,1);
    }else{
      MAP[selected.r][selected.c]=baseTile(selected.r,selected.c);
    }
    selected=null;updateInfo();
  }

  function rotate(delta){
    if(!selected||selected.type!=='decor')return;
    pushUndo();
    const d=selected.obj;
    if(typeof d._studioRot!=='number')d._studioRot=0;
    d._studioRot+=delta;
    updateInfo();
  }

  function duplicate(){
    if(!selected)return;
    pushUndo();
    if(selected.type==='decor'){
      const d=clone(selected.obj);d.r+=.5;d.c+=.5;
      _beachDecor.push(d);
      selected={type:'decor',index:_beachDecor.length-1,obj:d,kind:d.kind};
    }else{
      const nr=selected.r+1,nc=selected.c+1;
      if(canPlaceMap(nr,nc,selected.t)){
        MAP[nr][nc]=selected.t;
        selected={type:'map',r:nr,c:nc,t:selected.t,kind:selected.kind};
      }
    }
    updateInfo();
  }


  function newAssetId(kind){
    return `asset:${kind}:${Date.now()}:${Math.random().toString(36).slice(2,9)}`;
  }

  function createAsset(kind,r,c,scale=1,rotation=0,extra={}){
    return Object.assign({
      id:newAssetId(kind),kind,r,c,scale,
      _studioRot:rotation,
      variant:Math.floor(Math.random()*5),
      tint:(Math.random()-.5)*.12
    },extra);
  }

  function addAssetAt(kind,r,c,scale=1,rotation=0){
    const d=createAsset(kind,r,c,scale,rotation);
    _beachDecor.push(d);
    return d;
  }

  function placePrefab(prefabId){
    const prefab=DISTRICT_PREFABS[prefabId];
    if(!prefab)return;
    setBrush(null);
    const w=s2w(canvas.width/2,canvas.height/2);
    pushUndo();
    const created=[];
    for(const [kind,dr,dc,scale,rot] of prefab.objects){
      const d=createAsset(
        kind,
        Math.round((w.r+dr)*4)/4,
        Math.round((w.c+dc)*4)/4,
        scale,
        rot,
        {_studioPrefab:prefabId}
      );
      Object.assign(d,{
        palm:{variant:1},umbrella:{col:'#2ecc71'},chair:{ang:.15},
        boat:{ang:.3,col:'#2980b9'},surfboard:{ang:.1,col:'#f1c40f'},
        ball:{col1:'#e74c3c',col2:'#fff'},towel:{col:'#3498db'},
        starfish:{col:'#e67e22'},grass:{variant:1},float_ring:{col:'#e74c3c'}
      }[kind]||{});
      _beachDecor.push(d);
      created.push(d);
    }
    const first=created[0];
    if(first)selected={type:'decor',index:_beachDecor.indexOf(first),obj:first,kind:first.kind};
    updateInfo();
    alert(`Префаб добавлен: ${prefab.title}\n\nКисть выключена. Каждый предмет выбирается и двигается отдельно.`);
  }

  function setBrush(id){
    brushMode=id||null;
    brushLast=null;
    const el=panel?.querySelector('#mfzBrushState');
    if(el)el.textContent=brushMode?DISTRICT_BRUSHES[brushMode].title:'Кисть выключена · клик по предмету — выбрать и двигать';
  }

  function brushPaint(e){
    if(!brushMode||layer!=='beach')return;
    const p=screen(e),w=s2w(p.x,p.y),brush=DISTRICT_BRUSHES[brushMode];
    if(brushLast&&Math.hypot(w.r-brushLast.r,w.c-brushLast.c)<brush.spacing)return;
    const count=1+(Math.random()<.28?1:0);
    for(let i=0;i<count;i++){
      const kind=brush.pool[Math.floor(Math.random()*brush.pool.length)];
      const rr=w.r+(Math.random()-.5)*1.6,cc=w.c+(Math.random()-.5)*1.6;
      addAssetAt(kind,Math.round(rr*4)/4,Math.round(cc*4)/4,.88+Math.random()*.24,(Math.random()-.5)*.32);
    }
    brushLast={r:w.r,c:w.c};
  }

  function scaleSelected(delta){
    if(!selected||selected.type!=='decor')return;
    pushUndo();
    selected.obj.scale=Math.max(.45,Math.min(2.2,Number(selected.obj.scale||1)+delta));
    updateInfo();
  }

  function copySelected(){
    if(!selected)return;
    clipboard=selected.type==='decor'?clone(selected.obj):{type:'map',t:selected.t,kind:selected.kind};
  }

  function pasteClipboard(){
    if(!clipboard)return;
    pushUndo();
    const w=s2w(canvas.width/2,canvas.height/2);
    if(clipboard.type==='map'){
      const r=Math.round(w.r),c=Math.round(w.c);
      if(canPlaceMap(r,c,clipboard.t)){
        MAP[r][c]=clipboard.t;
        selected={type:'map',r,c,t:clipboard.t,kind:clipboard.kind};
      }
    }else{
      const d=clone(clipboard);
      d.id=newAssetId(d.kind);
      d.r=Math.round(w.r*4)/4;d.c=Math.round(w.c*4)/4;
      _beachDecor.push(d);
      selected={type:'decor',index:_beachDecor.length-1,obj:d,kind:d.kind};
    }
    updateInfo();
  }

  function addDecor(kind){
    setBrush(null);
    const w=s2w(canvas.width/2,canvas.height/2);
    const d=createAsset(kind,Math.round(w.r*4)/4,Math.round(w.c*4)/4,1,0);
    Object.assign(d,{
      palm:{variant:1},umbrella:{col:'#2ecc71'},chair:{ang:.15},
      boat:{ang:.3,col:'#2980b9'},surfboard:{ang:.1,col:'#f1c40f'},
      ball:{col1:'#e74c3c',col2:'#fff'},towel:{col:'#3498db'},
      starfish:{col:'#e67e22'},grass:{variant:1},float_ring:{col:'#e74c3c'}
    }[kind]||{});
    pushUndo();_beachDecor.push(d);
    selected={type:'decor',index:_beachDecor.length-1,obj:d,kind};
    updateInfo();
  }

  async function load(){
    if(loaded||!ready())return;
    loaded=true;
    baseMap=MAP.map(row=>row.slice());
    try{
      const r=await fetch(LOAD_URL,{cache:'no-store'});
      if(!r.ok)return;
      const data=await r.json();
      if(Array.isArray(data.decorFull)){
        _beachDecor.splice(0,_beachDecor.length,...data.decorFull.map(x=>clone(x)));
      }else if(Array.isArray(data.decor)){
        // Совместимость со старым форматом.
        const byId=new Map();
        _beachDecor.forEach((d,i)=>byId.set(`${d.kind}:${Math.round(d.r*100)}:${Math.round(d.c*100)}`,d));
        for(const x of data.decor){
          if(x.added&&x.data)_beachDecor.push(clone(x.data));
          else{
            const d=byId.get(x.id);
            if(d){d.r=x.r;d.c=x.c;if(typeof x.angle==='number')d.ang=x.angle;}
          }
        }
      }
      migrateLegacyDecor(_beachDecor);
      for(const q of data.mapEdits||[]){
        if(MAP[q.r])MAP[q.r][q.c]=q.value;
      }
      // Совместимость со старыми buildingMoves/deletedBuildings.
      for(const b of data.deletedBuildings||[])for(const q of b.cells||[])if(MAP[q.r])MAP[q.r][q.c]=baseTile(q.r,q.c);
      for(const m of data.buildingMoves||[]){
        for(const q of m.from||[])if(MAP[q.r])MAP[q.r][q.c]=baseTile(q.r,q.c);
        for(const q of m.to||[])if(MAP[q.r])MAP[q.r][q.c]=1;
      }
    }catch(e){console.warn('Studio map load:',e);}
  }

  async function save(){
    const edits=[];
    for(let r=0;r<MAP.length;r++)for(let c=0;c<MAP[r].length;c++){
      if(MAP[r][c]!==baseMap[r][c])edits.push({r,c,value:MAP[r][c]});
    }
    const data={version:20,decorFull:_beachDecor.map(cleanDecor),mapEdits:edits};
    try{
      const r=await fetch('/__studio_map',{
        method:'POST',headers:{'Content-Type':'application/json'},
        body:JSON.stringify(data,null,2)
      });
      const body=await r.text();
      if(!r.ok)throw new Error(`HTTP ${r.status}: ${body}`);
      alert(`Карта сохранена. Изменено тайлов: ${edits.length}`);
    }catch(e){alert('Не удалось сохранить: '+e.message);}
  }

  function teleport(r,c){
    if(typeof player==='undefined'||typeof cam==='undefined')return;
    if((typeof myDrivingCarId!=='undefined'&&myDrivingCarId)||
       (typeof _bankInt!=='undefined'&&_bankInt)||
       (typeof _buildingInt!=='undefined'&&_buildingInt)){
      alert('Сначала выйди из машины или здания.');return;
    }
    player.r=Math.max(1,Math.min(MAP_ROWS-2,r));
    player.c=Math.max(1,Math.min(MAP_COLS-2,c));
    if('vr'in player)player.vr=0;if('vc'in player)player.vc=0;
    cam.x=(player.c-player.r)*TS*.5;cam.y=(player.c+player.r)*TS*.5*ISO_Y;
    window._studioTeleportUntil=Date.now()+10000;
  }

  function drawMini(){
    const m=panel?.querySelector('#mfzMini');if(!m||!ready())return;
    const g=m.getContext('2d'),W=m.width,H=m.height;
    g.fillStyle='#091019';g.fillRect(0,0,W,H);
    const sr=Math.max(1,Math.ceil(MAP_ROWS/H)),sc=Math.max(1,Math.ceil(MAP_COLS/W));
    for(let r=0;r<MAP_ROWS;r+=sr)for(let c=0;c<MAP_COLS;c+=sc){
      const t=MAP[r]?.[c];
      g.fillStyle=t===0?'#303943':t===1?'#8a6a4f':t===15?'#cbb16d':
        t===16?'#275d83':t===8?'#315b39':t===9?'#747b78':'#17202b';
      g.fillRect(c/MAP_COLS*W,r/MAP_ROWS*H,Math.max(1,sc/MAP_COLS*W+1),Math.max(1,sr/MAP_ROWS*H+1));
    }
    if(typeof player!=='undefined'){g.fillStyle='#00f5ff';g.beginPath();g.arc(player.c/MAP_COLS*W,player.r/MAP_ROWS*H,4,0,Math.PI*2);g.fill();}
  }

  function updateInfo(){
    if(!info)return;
    if(!selected)info.textContent='Ничего не выбрано';
    else if(selected.type==='decor'){
      const a=typeof selected.obj._studioRot==='number'?Math.round(selected.obj._studioRot*180/Math.PI):0;
      info.textContent=`${selected.kind} · r ${selected.obj.r.toFixed(2)} · c ${selected.obj.c.toFixed(2)} · ${a}° · масштаб ${(selected.obj.scale||1).toFixed(2)}`;
    }else info.textContent=`${selected.kind} · tile ${selected.t} · r ${selected.r} · c ${selected.c}`;
  }

  function overlay(){
    if(!active||!selected||typeof ctx==='undefined')return;
    ctx.save();ctx.lineWidth=3;
    ctx.strokeStyle=selected.valid===false?'#ff3b3b':'#00e5ff';
    ctx.fillStyle='rgba(0,229,255,.12)';
    if(selected.type==='decor'){
      const p=w2s(selected.obj.r,selected.obj.c);
      ctx.beginPath();ctx.ellipse(p.x,p.y,32,16,0,0,Math.PI*2);ctx.fill();ctx.stroke();
    }else{
      const r=selected.previewR??selected.r,c=selected.previewC??selected.c,p=w2s(r+.5,c+.5);
      ctx.beginPath();ctx.ellipse(p.x,p.y,32,16,0,0,Math.PI*2);ctx.fill();ctx.stroke();
    }
    ctx.restore();
  }



  // ============================================================
  // MAFIOZY NATIVE DISTRICT ART 7.1
  // Плоская изометрия, контуры и палитра близки к основному движку.
  // ============================================================
  function _mfzNativeShadow(x,y,rx,ry){ctx.save();ctx.fillStyle='rgba(0,0,0,.20)';ctx.beginPath();ctx.ellipse(x+6,y+4,rx,ry,-.12,0,Math.PI*2);ctx.fill();ctx.restore();}
  function _mfzNativeBox(x,y,w,h,d,top,left,right){ctx.save();ctx.lineWidth=1;ctx.strokeStyle='rgba(20,22,24,.55)';ctx.beginPath();ctx.moveTo(x,y-h);ctx.lineTo(x+w,y-h+w*.5);ctx.lineTo(x,y-h+w);ctx.lineTo(x-w,y-h+w*.5);ctx.closePath();ctx.fillStyle=top;ctx.fill();ctx.stroke();ctx.beginPath();ctx.moveTo(x-w,y-h+w*.5);ctx.lineTo(x,y-h+w);ctx.lineTo(x,y+d);ctx.lineTo(x-w,y+d-w*.5);ctx.closePath();ctx.fillStyle=left;ctx.fill();ctx.stroke();ctx.beginPath();ctx.moveTo(x+w,y-h+w*.5);ctx.lineTo(x,y-h+w);ctx.lineTo(x,y+d);ctx.lineTo(x+w,y+d-w*.5);ctx.closePath();ctx.fillStyle=right;ctx.fill();ctx.stroke();ctx.restore();}
  function _mfzNativeTree(x,y,pine){_mfzNativeShadow(x,y,27,8);ctx.fillStyle='#76502f';ctx.fillRect(x-4,y-45,8,45);if(pine){for(let i=0;i<3;i++){ctx.fillStyle=i%2?'#2b7041':'#236238';ctx.beginPath();ctx.moveTo(x,y-92+i*20);ctx.lineTo(x-29+i*3,y-35+i*15);ctx.lineTo(x+29-i*3,y-35+i*15);ctx.closePath();ctx.fill();}}else{for(const [dx,dy,r,c] of [[0,-68,22,'#2f7b43'],[-18,-58,18,'#286d3b'],[18,-57,19,'#35864a'],[0,-47,20,'#327f46']]){ctx.fillStyle=c;ctx.beginPath();ctx.arc(x+dx,y+dy,r,0,Math.PI*2);ctx.fill();}}}
  function _mfzNativeVehicle(x,y,color){_mfzNativeShadow(x,y,34,8);ctx.fillStyle=color;ctx.strokeStyle='#222';ctx.lineWidth=1;ctx.beginPath();ctx.moveTo(x-32,y-5);ctx.lineTo(x-22,y-22);ctx.lineTo(x+20,y-28);ctx.lineTo(x+34,y-10);ctx.lineTo(x+25,y+1);ctx.lineTo(x-25,y+2);ctx.closePath();ctx.fill();ctx.stroke();ctx.fillStyle='#26343b';ctx.beginPath();ctx.moveTo(x-16,y-23);ctx.lineTo(x-7,y-35);ctx.lineTo(x+15,y-36);ctx.lineTo(x+23,y-28);ctx.closePath();ctx.fill();ctx.fillStyle='#111';for(const dx of [-22,22]){ctx.beginPath();ctx.ellipse(x+dx,y+1,7,4,0,0,Math.PI*2);ctx.fill();}}
  function _mfzNativeLamp(x,y,night){_mfzNativeShadow(x,y,10,4);ctx.strokeStyle='#3a4247';ctx.lineWidth=5;ctx.beginPath();ctx.moveTo(x,y);ctx.lineTo(x,y-65);ctx.stroke();ctx.fillStyle=night?'#ff58db':'#ffe18a';if(night){ctx.shadowColor='#ff2dcc';ctx.shadowBlur=12;}ctx.beginPath();ctx.arc(x,y-71,7,0,Math.PI*2);ctx.fill();ctx.shadowBlur=0;}
  function _mfzNativePlant(x,y,lux){_mfzNativeShadow(x,y,20,6);_mfzNativeBox(x,y,20,12,2,lux?'#d4cbc0':'#8b6552',lux?'#a69c91':'#604638',lux?'#b8ada1':'#765445');for(let i=-2;i<=2;i++){ctx.strokeStyle='#347342';ctx.beginPath();ctx.moveTo(x,y-10);ctx.lineTo(x+i*7,y-25-Math.abs(i)*2);ctx.stroke();ctx.fillStyle=['#e75b5b','#f1c84b','#a76bd4'][i+2];ctx.beginPath();ctx.arc(x+i*7,y-27-Math.abs(i)*2,4,0,Math.PI*2);ctx.fill();}}
  function drawDistrictDecorLayer(){ /* native-only */ }

  function buildPanel(){
    panel=document.createElement('div');panel.id='mfzEditor20';
    panel.innerHTML=`
      <div class="head"><b>🛠 MAFIOZY TRUE NATIVE EDITOR 7.2</b><span>F8</span></div>
      <div class="tabs"><button data-layer="city">Город</button><button data-layer="beach">Пляж</button></div>
      <div id="mfzInfo">Ничего не выбрано</div>
      <div class="miniTitle">🗺 Клик — телепорт</div><canvas id="mfzMini" width="320" height="130"></canvas>
      <div id="mfzBrushState" class="brushState">Кисть выключена · клик по предмету — выбрать и двигать</div>
      <div id="mfzBrushes" class="brushes"></div>
      <div id="mfzPrefabs" class="prefabs"></div>
      <div id="mfzCatalog" class="catalog"></div>
      <div class="actions">
        <button data-a="rotL">↺ Повернуть -15°</button><button data-a="rotR">↻ Повернуть +15°</button>
        <button data-a="dup">📋 Дублировать</button><button data-a="del">🗑 Удалить</button><button data-a="scaleDown">➖ Масштаб</button><button data-a="scaleUp">➕ Масштаб</button>
        <button data-a="undo">↩ Undo</button><button data-a="redo">↪ Redo</button>
        <button data-a="snap">🧲 Сетка: ВКЛ</button><button class="save" data-a="save">💾 СОХРАНИТЬ КАРТУ</button>
      </div>
      <small>ЛКМ — выбрать/тащить · Q/E — поворот · Delete · Ctrl+S</small>`;
    const style=document.createElement('style');style.textContent=`
      #mfzEditor20{position:fixed;z-index:999999;left:14px;top:14px;width:350px;background:#111722f3;
      border:2px solid #d5aa3d;border-radius:12px;color:#fff;font:13px Segoe UI,Arial;padding:12px;
      box-shadow:0 14px 45px #000b;display:none}
      #mfzEditor20 .head{display:flex;justify-content:space-between;color:#ffd76b;font-size:15px;margin-bottom:8px}
      #mfzEditor20 .tabs,#mfzEditor20 .actions{display:grid;grid-template-columns:1fr 1fr;gap:6px}
      #mfzEditor20 button{background:#29384b;color:#fff;border:1px solid #41536a;border-radius:6px;padding:7px;cursor:pointer}
      #mfzInfo{background:#1d2634;padding:8px;border-radius:7px;margin:8px 0;color:#bfe6ff}
      .miniTitle{font-size:11px;color:#9fdcf1;margin:5px 0}#mfzMini{width:100%;height:130px;border:1px solid #40536a;border-radius:6px;cursor:crosshair}
      .catalog{display:none;grid-template-columns:1fr 1fr;gap:5px;max-height:150px;overflow:auto;margin-top:8px}
      .actions{margin-top:9px}.actions .save{grid-column:1/3;background:#876814;border-color:#d4aa37;font-weight:700}
      #mfzEditor20 small{display:block;color:#9facbd;margin-top:8px}body.mfz-edit20 canvas{cursor:crosshair!important}`;
    document.head.appendChild(style);document.body.appendChild(panel);info=panel.querySelector('#mfzInfo');
    const brushBox=panel.querySelector('#mfzBrushes');
    const off=document.createElement('button');off.textContent='🖱 Выключить кисть';off.onclick=()=>setBrush(null);brushBox.appendChild(off);
    Object.entries(DISTRICT_BRUSHES).forEach(([id,b])=>{
      const btn=document.createElement('button');btn.textContent=b.title;btn.onclick=()=>setBrush(id);brushBox.appendChild(btn);
    });
    const prefabBox=panel.querySelector('#mfzPrefabs');
    Object.entries(DISTRICT_PREFABS).forEach(([id,p])=>{
      const btn=document.createElement('button');btn.textContent=p.title;btn.onclick=()=>placePrefab(id);prefabBox.appendChild(btn);
    });
    const cat=panel.querySelector('#mfzCatalog');
    
    Object.entries(DECOR_GROUPS).forEach(([groupId,group])=>{
      const title=document.createElement('div');
      title.textContent=group.title;title.className='groupTitle';cat.appendChild(title);
      group.items.forEach(([k,l])=>{
        const b=document.createElement('button');b.textContent=l;b.dataset.kind=k;
        b.onclick=()=>addDecor(k);cat.appendChild(b);
      });
    });

    const mini=panel.querySelector('#mfzMini');
    mini.onclick=e=>{const r=mini.getBoundingClientRect();teleport((e.clientY-r.top)/r.height*MAP_ROWS,(e.clientX-r.left)/r.width*MAP_COLS);};
    panel.onclick=e=>{
      const l=e.target.dataset.layer;if(l){layer=l;cat.style.display=l==='beach'?'grid':'none';selected=null;updateInfo();}
      const a=e.target.dataset.a;
      if(a==='rotL')rotate(-Math.PI/12);if(a==='rotR')rotate(Math.PI/12);
      if(a==='dup')duplicate();if(a==='del')removeSelected();if(a==='scaleDown')scaleSelected(-.1);if(a==='scaleUp')scaleSelected(.1);if(a==='undo')undo();if(a==='redo')redo();if(a==='save')save();
      if(a==='snap'){snap=!snap;e.target.textContent=`🧲 Сетка: ${snap?'ВКЛ':'ВЫКЛ'}`;}
    };
  }

  function toggle(){if(!LOCAL)return;active=!active;panel.style.display=active?'block':'none';document.body.classList.toggle('mfz-edit20',active);}

  function init(){
    buildPanel();
    const wait=setInterval(async()=>{
      if(!ready())return;clearInterval(wait);await load();
      requestAnimationFrame(function loop(){try{drawDistrictDecorLayer();overlay();drawMini();}catch(_){}requestAnimationFrame(loop);});
      if(!LOCAL)return;
      window.addEventListener('keydown',e=>{
        if(e.key==='F8'){e.preventDefault();toggle();}
        if(!active)return;
        if(e.key.toLowerCase()==='q'){e.preventDefault();rotate(-Math.PI/12);}
        if(e.key.toLowerCase()==='e'){e.preventDefault();rotate(Math.PI/12);}
        if((e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==='s'){e.preventDefault();save();}
        if((e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==='z'){e.preventDefault();undo();}
        if((e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==='y'){e.preventDefault();redo();}
        if((e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==='d'){e.preventDefault();duplicate();}
        if((e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==='c'){e.preventDefault();copySelected();}
        if((e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==='v'){e.preventDefault();pasteClipboard();}
        if(e.key==='['){e.preventDefault();scaleSelected(-.1);}
        if(e.key===']'){e.preventDefault();scaleSelected(.1);}
        if(e.key==='Delete'){e.preventDefault();removeSelected();}
      },true);
      canvas.addEventListener('pointerdown',e=>{
        if(!active)return;e.preventDefault();e.stopImmediatePropagation();
        if(brushMode&&layer==='beach'){pushUndo();dragging=true;brushPaint(e);canvas.setPointerCapture(e.pointerId);return;}
        selected=pick(e);updateInfo();
        if(selected){pushUndo();dragging=true;canvas.setPointerCapture(e.pointerId);}
      },true);
      canvas.addEventListener('pointermove',e=>{
        if(!active||!dragging)return;e.preventDefault();e.stopPropagation();e.stopImmediatePropagation();if(brushMode&&layer==='beach'){brushPaint(e);return;}if(selected)moveSelected(e);
      },true);
      canvas.addEventListener('pointerup',e=>{
        if(!active||!dragging)return;e.preventDefault();e.stopImmediatePropagation();dragging=false;commitMove();
      },true);
    },250);
  }
  init();
})();
</script>
"""
text = text.replace("</body>", script + "\n</body>", 1)

# Меняем внутренний маркер UI.
text = text.replace(
    "// MAFIOZY_WORLD_EDITOR_2_1",
    "// MAFIOZY_JSON_ONLY_ENGINE_7_2_TRUE_NATIVE"
)
text = text.replace(
    "MAFIOZY TRUE NATIVE EDITOR 7.2",
    "MAFIOZY JSON MAP EDITOR 7.2"
)

# Проверка всех inline-script через Node.js.
scripts = re.findall(r"<script\b[^>]*>(.*?)</script>", text, flags=re.S | re.I)
errors = []
for script_index, javascript in enumerate(scripts, 1):
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".js", encoding="utf-8", delete=False
    ) as temporary:
        temporary.write(javascript)
        temporary_name = temporary.name
    try:
        result = subprocess.run(
            ["node", "--check", temporary_name],
            text=True,
            capture_output=True,
            timeout=60,
        )
        if result.returncode:
            errors.append(
                f"script #{script_index}\n{result.stderr or result.stdout}"
            )
    except FileNotFoundError:
        print("ОШИБКА: Node.js не найден. Без проверки установка запрещена.")
        sys.exit(8)
    finally:
        Path(temporary_name).unlink(missing_ok=True)

if errors:
    print("ОШИБКА JAVASCRIPT. world.html не изменён.")
    print("\n\n".join(errors[:3]))
    sys.exit(9)

WORLD.write_text(text, encoding="utf-8", newline="")

print("ГОТОВО: Mafiozy Mafiozy JSON Only Engine 7.2 True Native установлен.")
print("Дальнейшие изменения карты записываются только в map_overrides.json.")
print("Чужих обёрток вне пляжа: 0.")
print(f"Резервная копия: {backup_dir}")
