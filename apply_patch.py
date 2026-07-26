# -*- coding: utf-8 -*-
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent
WORLD = ROOT / "world.html"
MARKER = "MAFIOZY_STUDIO_WORLD_EDITOR_V1_1"

if not WORLD.exists():
    print("ОШИБКА: world.html не найден.")
    sys.exit(1)

text = WORLD.read_text(encoding="utf-8", errors="strict")

# Remove previous editor block if present.
start_old = text.find("<script>\n// MAFIOZY_STUDIO_WORLD_EDITOR_V1")
if start_old != -1:
    end_old = text.find("</script>", start_old)
    if end_old == -1:
        print("ОШИБКА: старый блок редактора повреждён.")
        sys.exit(2)
    text = text[:start_old] + text[end_old + len("</script>"):]

if MARKER in text:
    print("Mafiozy World Editor 1.1 уже установлен.")
    sys.exit(0)

if "</body>" not in text:
    print("ОШИБКА: тег </body> не найден.")
    sys.exit(3)

script = r"""
<script>
// MAFIOZY_STUDIO_WORLD_EDITOR_V1_1
(() => {
  const LOCAL_DEV = location.hostname === '127.0.0.1' || location.hostname === 'localhost';
  const OVERRIDE_URL = '/__studio_map';
  let editorOn = false, layer = 'decor', selected = null, dragging = false;
  let undoStack = [], redoStack = [], panel = null, info = null, snap = true;
  let loaded = false, buildingMoves = [], deletedBuildings = [];

  const DECOR_TYPES = [
    ['palm','🌴 Пальма'], ['umbrella','⛱ Зонтик'], ['chair','🛏 Шезлонг'],
    ['boat','🛶 Лодка'], ['lifeguard','🛟 Вышка'], ['surfboard','🏄 Сёрф'],
    ['ball','⚽ Мяч'], ['towel','🧺 Полотенце'], ['sandcastle','🏰 Замок'],
    ['volleyball','🏐 Сетка'], ['icecream_cart','🍦 Тележка'],
    ['starfish','⭐ Морская звезда'], ['grass','🌾 Трава'], ['float_ring','⭕ Круг']
  ];

  const ready = () =>
    typeof MAP !== 'undefined' && Array.isArray(MAP) &&
    typeof _beachDecor !== 'undefined' && Array.isArray(_beachDecor) &&
    typeof canvas !== 'undefined' && typeof w2s === 'function' && typeof s2w === 'function';

  function decorId(d, i) {
    if (d._studioId) return d._studioId;
    d._studioId = `${d.kind || 'obj'}:${Math.round((+d.r||0)*100)}:${Math.round((+d.c||0)*100)}:${i}`;
    return d._studioId;
  }

  function getAngle(d) {
    if (!d) return 0;
    if (typeof d.ang === 'number') return d.ang;
    if (typeof d.angle === 'number') return d.angle;
    if (typeof d.rot === 'number') return d.rot;
    return 0;
  }

  function setAngle(d, value) {
    if (!d || d.kind === 'building') return;
    if ('ang' in d || (!('angle' in d) && !('rot' in d))) d.ang = value;
    else if ('angle' in d) d.angle = value;
    else d.rot = value;
  }

  function cleanData(d) {
    const out={};
    for (const [k,v] of Object.entries(d)) if (!k.startsWith('_')) out[k]=v;
    return out;
  }

  function snapshot() {
    return JSON.stringify({
      decor: _beachDecor.map((d,i)=>({
        id:decorId(d,i), r:d.r, c:d.c, angle:getAngle(d),
        deleted:!!d._studioDeleted, added:!!d._studioAdded,
        data:d._studioAdded ? cleanData(d) : undefined
      })),
      buildingMoves: JSON.parse(JSON.stringify(buildingMoves)),
      deletedBuildings: JSON.parse(JSON.stringify(deletedBuildings))
    });
  }

  function restoreSnapshot(raw) {
    const s = JSON.parse(raw);
    const map = new Map(_beachDecor.map((d,i)=>[decorId(d,i),d]));
    for (const x of s.decor || []) {
      let d = map.get(x.id);
      if (!d && x.added && x.data) {
        d = Object.assign({}, x.data, {_studioId:x.id,_studioAdded:true});
        _beachDecor.push(d);
      }
      if (d) {
        d.r=x.r; d.c=x.c; d._studioDeleted=!!x.deleted;
        if (typeof x.angle === 'number') setAngle(d,x.angle);
      }
    }
    buildingMoves = s.buildingMoves || [];
    deletedBuildings = s.deletedBuildings || [];
    rebuildMapOverrides();
  }

  function pushUndo() {
    undoStack.push(snapshot());
    if (undoStack.length > 100) undoStack.shift();
    redoStack.length = 0;
  }
  function undo() {
    if (!undoStack.length) return;
    redoStack.push(snapshot());
    restoreSnapshot(undoStack.pop());
    updateInfo();
  }
  function redo() {
    if (!redoStack.length) return;
    undoStack.push(snapshot());
    restoreSnapshot(redoStack.pop());
    updateInfo();
  }

  function rotateSelected(delta) {
    if (!selected || selected.kind === 'building') return;
    pushUndo();
    setAngle(selected, getAngle(selected) + delta);
    updateInfo();
  }

  function baseTileType(r,c) {
    if (r<=0 || c<=0 || r>=MAP_ROWS-1 || c>=MAP_COLS-1) return 1;
    if (r>=140) return MAP[r][c];
    const onRoadR=(r%BLOCK<=3), onRoadC=(c%BLOCK<=3);
    if (onRoadR||onRoadC) return 0;
    const sideR=(r%BLOCK===4)||(r%BLOCK===BLOCK-1);
    const sideC=(c%BLOCK===4)||(c%BLOCK===BLOCK-1);
    if (sideR||sideC) return 9;
    return 8;
  }

  function rebuildMapOverrides() {
    if (!ready()) return;
    for (const b of deletedBuildings) {
      for (const q of b.cells || []) if (MAP[q.r] && MAP[q.r][q.c]===1) MAP[q.r][q.c]=baseTileType(q.r,q.c);
    }
    for (const m of buildingMoves) {
      for (const q of m.from || []) if (MAP[q.r] && MAP[q.r][q.c]===1) MAP[q.r][q.c]=baseTileType(q.r,q.c);
      for (const q of m.to || []) if (MAP[q.r]) MAP[q.r][q.c]=1;
    }
  }

  function buildingCluster(r,c) {
    r=Math.floor(r); c=Math.floor(c);
    if (!MAP[r] || MAP[r][c]!==1) return null;
    const stack=[[r,c]], seen=new Set(), cells=[];
    while(stack.length && cells.length<80) {
      const [rr,cc]=stack.pop(), key=rr+','+cc;
      if(seen.has(key)||!MAP[rr]||MAP[rr][cc]!==1) continue;
      seen.add(key); cells.push({r:rr,c:cc});
      for(const [dr,dc] of [[1,0],[-1,0],[0,1],[0,-1]]) {
        const nr=rr+dr,nc=cc+dc;
        if(Math.abs(nr-r)<=6 && Math.abs(nc-c)<=6) stack.push([nr,nc]);
      }
    }
    if (!cells.length) return null;
    const minR=Math.min(...cells.map(x=>x.r)), maxR=Math.max(...cells.map(x=>x.r));
    const minC=Math.min(...cells.map(x=>x.c)), maxC=Math.max(...cells.map(x=>x.c));
    return {kind:'building',cells,minR,maxR,minC,maxC,anchorR:minR,anchorC:minC};
  }

  function canPlaceBuilding(cells) {
    for(const q of cells) {
      if(q.r<=0||q.c<=0||q.r>=MAP_ROWS-1||q.c>=MAP_COLS-1) return false;
      const t=MAP[q.r]?.[q.c];
      if(t===15||t===16||t===17||t===18) return false;
    }
    return true;
  }

  function screen(e) {
    const rect=canvas.getBoundingClientRect();
    return {x:e.clientX-rect.left,y:e.clientY-rect.top};
  }

  function nearestDecor(x,y) {
    let best=null,dist=48;
    for(let i=0;i<_beachDecor.length;i++) {
      const d=_beachDecor[i]; if(d._studioDeleted) continue;
      decorId(d,i); const p=w2s(d.r,d.c), dd=Math.hypot(p.x-x,p.y-y);
      if(dd<dist){dist=dd;best=d;}
    }
    return best;
  }

  function pick(e) {
    const p=screen(e), w=s2w(p.x,p.y);
    if(layer==='buildings') return buildingCluster(w.r,w.c);
    return nearestDecor(p.x,p.y);
  }

  function moveSelected(e) {
    const p=screen(e), w=s2w(p.x,p.y);
    if(selected?.kind==='building') {
      const nr=Math.round(w.r), nc=Math.round(w.c);
      const dr=nr-selected.anchorR, dc=nc-selected.anchorC;
      selected.previewTo=selected.cells.map(q=>({r:q.r+dr,c:q.c+dc}));
      selected.previewValid=canPlaceBuilding(selected.previewTo);
    } else if(selected) {
      selected.r=snap?Math.round(w.r*4)/4:w.r;
      selected.c=snap?Math.round(w.c*4)/4:w.c;
    }
    updateInfo();
  }

  function commitBuildingMove() {
    if(!selected || selected.kind!=='building' || !selected.previewTo || !selected.previewValid) return;
    for(const q of selected.cells) if(MAP[q.r]?.[q.c]===1) MAP[q.r][q.c]=baseTileType(q.r,q.c);
    for(const q of selected.previewTo) MAP[q.r][q.c]=1;
    buildingMoves.push({from:selected.cells,to:selected.previewTo});
    const minR=Math.min(...selected.previewTo.map(x=>x.r)), minC=Math.min(...selected.previewTo.map(x=>x.c));
    selected=buildingCluster(minR,minC);
  }

  function addDecor(kind) {
    const w=s2w(innerWidth/2,innerHeight/2);
    const d={kind,r:Math.round(w.r*4)/4,c:Math.round(w.c*4)/4,_studioAdded:true,
      _studioId:`added:${Date.now()}:${Math.random().toString(36).slice(2)}`};
    Object.assign(d,{
      palm:{variant:1},umbrella:{col:'#2ecc71'},chair:{ang:.15},
      boat:{ang:.3,col:'#2980b9'},surfboard:{ang:.1,col:'#f1c40f'},
      ball:{col1:'#e74c3c',col2:'#fff'},towel:{col:'#3498db'},
      starfish:{col:'#e67e22'},grass:{variant:1},float_ring:{col:'#e74c3c'}
    }[kind]||{});
    pushUndo();_beachDecor.push(d);selected=d;updateInfo();
  }

  function duplicateSelected() {
    if(!selected || selected.kind==='building') return;
    pushUndo();
    const d=JSON.parse(JSON.stringify(selected));
    d._studioId=`added:${Date.now()}:${Math.random().toString(36).slice(2)}`;
    d._studioAdded=true;d.r+=.5;d.c+=.5;delete d._studioDeleted;
    _beachDecor.push(d);selected=d;updateInfo();
  }

  function deleteSelected() {
    if(!selected)return;
    pushUndo();
    if(selected.kind==='building') {
      for(const q of selected.cells) if(MAP[q.r]?.[q.c]===1) MAP[q.r][q.c]=baseTileType(q.r,q.c);
      deletedBuildings.push({cells:selected.cells});
    } else if(selected._studioAdded) {
      _beachDecor.splice(_beachDecor.indexOf(selected),1);
    } else selected._studioDeleted=true;
    selected=null;updateInfo();
  }

  async function loadOverrides() {
    if(loaded||!ready())return;
    loaded=true;_beachDecor.forEach(decorId);
    try {
      const r=await fetch(OVERRIDE_URL,{cache:'no-store'});
      if(!r.ok)return;
      const data=await r.json();
      const map=new Map(_beachDecor.map((d,i)=>[decorId(d,i),d]));
      for(const x of data.decor||[]) {
        let d=map.get(x.id);
        if(x.deleted){if(d)d._studioDeleted=true;continue;}
        if(!d&&x.added&&x.data){d=Object.assign({},x.data,{_studioId:x.id,_studioAdded:true});_beachDecor.push(d);}
        else if(d){
          d.r=x.r;d.c=x.c;
          if(typeof x.angle==='number')setAngle(d,x.angle);
        }
      }
      buildingMoves=data.buildingMoves||[];
      deletedBuildings=data.deletedBuildings||[];
      rebuildMapOverrides();
    }catch(_){}
  }

  async function saveAll() {
    const data={
      version:2,
      decor:_beachDecor.map((d,i)=>({
        id:decorId(d,i),r:d.r,c:d.c,angle:getAngle(d),
        deleted:!!d._studioDeleted,added:!!d._studioAdded,
        data:d._studioAdded?cleanData(d):undefined
      })),
      buildingMoves,deletedBuildings
    };
    try {
      const r=await fetch(OVERRIDE_URL,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data,null,2)});
      const body=await r.text();
      if(!r.ok)throw new Error(`HTTP ${r.status}: ${body}`);
      alert('Карта сохранена в map_overrides.json');
    }catch(e){alert('Ошибка сохранения: '+e.message);}
  }

  function updateInfo() {
    if(!info)return;
    if(!selected)info.textContent='Ничего не выбрано';
    else if(selected.kind==='building')info.textContent=`Здание: ${selected.cells.length} тайлов · ${selected.minR},${selected.minC}`;
    else info.textContent=`${selected.kind} · r:${(+selected.r).toFixed(2)} c:${(+selected.c).toFixed(2)} · угол:${Math.round(getAngle(selected)*180/Math.PI)}°`;
  }

  function drawOverlay() {
    if(!editorOn||!selected||typeof ctx==='undefined')return;
    ctx.save();ctx.strokeStyle='#00e5ff';ctx.fillStyle='rgba(0,229,255,.12)';ctx.lineWidth=2;
    if(selected.kind==='building') {
      const cells=selected.previewTo||selected.cells;
      ctx.strokeStyle=selected.previewValid===false?'#ff4d4d':'#00e5ff';
      for(const q of cells){const p=w2s(q.r+.5,q.c+.5);ctx.beginPath();ctx.ellipse(p.x,p.y,24,12,0,0,Math.PI*2);ctx.stroke();}
    } else {
      const p=w2s(selected.r,selected.c);ctx.beginPath();ctx.ellipse(p.x,p.y,28,13,0,0,Math.PI*2);ctx.fill();ctx.stroke();
    }
    ctx.restore();
  }

  function buildPanel() {
    panel=document.createElement('div');panel.id='mfzStudioEditor';
    panel.innerHTML=`
      <div class="head"><b>🛠 MAFIOZY WORLD EDITOR</b><span>F8</span></div>
      <div class="tabs"><button data-layer="decor">Декор</button><button data-layer="buildings">Здания</button></div>
      <div id="mfzStudioInfo">Ничего не выбрано</div>
      <div id="mfzCatalog" class="catalog"></div>
      <div class="actions">
        <button data-a="rotL">↺ Повернуть -15°</button><button data-a="rotR">↻ Повернуть +15°</button>
        <button data-a="dup">📋 Дублировать</button><button data-a="del">🗑 Удалить</button>
        <button data-a="undo">↩ Undo</button><button data-a="redo">↪ Redo</button>
        <button data-a="snap">🧲 Сетка: ВКЛ</button><button class="save" data-a="save">💾 СОХРАНИТЬ КАРТУ</button>
      </div>
      <small>ЛКМ — выбрать/тащить · Q/E — поворот · Delete — удалить · Ctrl+S — сохранить</small>`;
    const style=document.createElement('style');style.textContent=`
      #mfzStudioEditor{position:fixed;z-index:999999;left:14px;top:14px;width:340px;background:#111722f2;
      border:2px solid #d5aa3d;border-radius:12px;color:#fff;font:13px Segoe UI,Arial;padding:12px;
      box-shadow:0 14px 45px #000b;display:none}
      #mfzStudioEditor .head{display:flex;justify-content:space-between;color:#ffd76b;font-size:15px;margin-bottom:8px}
      #mfzStudioEditor .tabs,#mfzStudioEditor .actions{display:grid;grid-template-columns:1fr 1fr;gap:6px}
      #mfzStudioEditor button{background:#29384b;color:#fff;border:1px solid #41536a;border-radius:6px;padding:7px;cursor:pointer}
      #mfzStudioEditor button:hover{background:#3a5270}
      #mfzStudioInfo{background:#1d2634;padding:8px;border-radius:7px;margin:8px 0;color:#bfe6ff}
      .catalog{display:grid;grid-template-columns:1fr 1fr;gap:5px;max-height:220px;overflow:auto}
      .actions{margin-top:9px}.actions .save{grid-column:1/3;background:#876814;border-color:#d4aa37;font-weight:700}
      #mfzStudioEditor small{display:block;color:#9facbd;margin-top:8px} body.mfz-studio-edit canvas{cursor:crosshair!important}`;
    document.head.appendChild(style);document.body.appendChild(panel);info=panel.querySelector('#mfzStudioInfo');
    const cat=panel.querySelector('#mfzCatalog');
    DECOR_TYPES.forEach(([k,l])=>{const b=document.createElement('button');b.textContent=l;b.onclick=()=>addDecor(k);cat.appendChild(b);});
    panel.onclick=e=>{
      const l=e.target.dataset.layer;if(l){layer=l;cat.style.display=l==='decor'?'grid':'none';selected=null;updateInfo();}
      const a=e.target.dataset.a;
      if(a==='rotL')rotateSelected(-Math.PI/12);
      if(a==='rotR')rotateSelected(Math.PI/12);
      if(a==='dup')duplicateSelected();if(a==='del')deleteSelected();if(a==='undo')undo();if(a==='redo')redo();if(a==='save')saveAll();
      if(a==='snap'){snap=!snap;e.target.textContent=`🧲 Сетка: ${snap?'ВКЛ':'ВЫКЛ'}`;}
    };
  }

  function toggle(){if(!LOCAL_DEV)return;editorOn=!editorOn;panel.style.display=editorOn?'block':'none';document.body.classList.toggle('mfz-studio-edit',editorOn);}

  function init() {
    buildPanel();
    const wait=setInterval(async()=>{
      if(!ready())return;clearInterval(wait);await loadOverrides();
      requestAnimationFrame(function loop(){try{drawOverlay();}catch(_){}requestAnimationFrame(loop);});
      if(!LOCAL_DEV)return;
      window.addEventListener('keydown',e=>{
        if(e.key==='F8'){e.preventDefault();toggle();}
        if(!editorOn)return;
        if(e.key.toLowerCase()==='q'){e.preventDefault();rotateSelected(-Math.PI/12);}
        if(e.key.toLowerCase()==='e'){e.preventDefault();rotateSelected(Math.PI/12);}
        if((e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==='s'){e.preventDefault();saveAll();}
        if((e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==='z'){e.preventDefault();undo();}
        if((e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==='y'){e.preventDefault();redo();}
        if((e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==='d'){e.preventDefault();duplicateSelected();}
        if(e.key==='Delete'){e.preventDefault();deleteSelected();}
      },true);
      canvas.addEventListener('pointerdown',e=>{
        if(!editorOn)return;e.preventDefault();e.stopImmediatePropagation();selected=pick(e);updateInfo();
        if(selected){pushUndo();dragging=true;canvas.setPointerCapture(e.pointerId);}
      },true);
      canvas.addEventListener('pointermove',e=>{if(!editorOn||!dragging||!selected)return;e.preventDefault();e.stopImmediatePropagation();moveSelected(e);},true);
      canvas.addEventListener('pointerup',e=>{if(!editorOn||!dragging)return;e.preventDefault();e.stopImmediatePropagation();dragging=false;if(selected?.kind==='building')commitBuildingMove();},true);
    },300);
  }
  init();
})();
</script>
"""

text = text.replace("</body>", script + "\n</body>", 1)
WORLD.write_text(text, encoding="utf-8", newline="")
print("ГОТОВО: Mafiozy World Editor 1.1 установлен.")
print("Добавлен поворот объектов Q/E и кнопками ±15°.")
