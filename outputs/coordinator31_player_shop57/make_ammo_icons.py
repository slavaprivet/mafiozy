"""Build six small vector cartridge pictures used by the shop and inventory."""
from pathlib import Path
from html import escape

out = Path(__file__).resolve().parent / "game/assets/shop_icons"
out.mkdir(parents=True, exist_ok=True)


def bullet(x, width, body_top, body_bottom, tip_top, brass, tip, rim=True):
    mid = x + width / 2
    shoulder = body_top + 10
    parts = [
        f'<path d="M {x} {body_top} L {mid-3} {tip_top+5} Q {mid} {tip_top-3} {mid+3} {tip_top+5} L {x+width} {body_top} Z" fill="{tip}" stroke="#151d24" stroke-width="3"/>',
        f'<rect x="{x}" y="{body_top}" width="{width}" height="{body_bottom-body_top}" rx="4" fill="{brass}" stroke="#151d24" stroke-width="3"/>',
        f'<path d="M {x+7} {shoulder} V {body_bottom-8}" stroke="#fff2c4" stroke-opacity=".48" stroke-width="4" stroke-linecap="round"/>',
        f'<path d="M {x+width-6} {body_top+5} V {body_bottom-5}" stroke="#675235" stroke-opacity=".55" stroke-width="3"/>',
    ]
    if rim:
        parts.append(f'<rect x="{x-2}" y="{body_bottom-7}" width="{width+4}" height="8" rx="2" fill="#9d7545" stroke="#151d24" stroke-width="2"/>')
    return "\n".join(parts)


def shell(x, color):
    return f'''<rect x="{x}" y="30" width="34" height="72" rx="7" fill="{color}" stroke="#151d24" stroke-width="3"/>
<rect x="{x+2}" y="26" width="30" height="12" rx="3" fill="#bf995a" stroke="#151d24" stroke-width="2"/>
<rect x="{x-2}" y="97" width="38" height="11" rx="2" fill="#cba968" stroke="#151d24" stroke-width="2"/>
<path d="M {x+8} 45 V 88" stroke="#fbd2ab" stroke-opacity=".55" stroke-width="4" stroke-linecap="round"/>'''


art = {
    "ammo_9mm": "\n".join(bullet(x, 26, 48, 103, 18, "#c19a57", "#b9744e") for x in (70, 115, 160)),
    "ammo_magnum": "\n".join(bullet(x, 32, 42, 105, 11, "#d0a363", "#b56848") for x in (89, 139)),
    "ammo_shell": "\n".join(shell(x, "#a94138") for x in (72, 116, 160)),
    "ammo_rifle": "\n".join(bullet(x, 27, 54, 105, 8, "#b99a61", "#927455") for x in (70, 115, 160)),
    "ammo_sniper": "\n".join(bullet(x, 33, 49, 108, 5, "#bca06e", "#876b5a") for x in (87, 138)),
    "ammo_rocket": '''<path d="M 46 64 L 79 42 L 192 42 L 224 64 L 192 86 L 79 86 Z" fill="#65774c" stroke="#151d24" stroke-width="4"/>
<path d="M 79 42 L 92 28 L 117 42 M 79 86 L 92 100 L 117 86" fill="#556646" stroke="#151d24" stroke-width="3"/>
<path d="M 52 64 H 189" stroke="#9eaf74" stroke-width="7" stroke-linecap="round"/>
<rect x="77" y="43" width="9" height="42" fill="#2d3936"/>
<rect x="157" y="43" width="9" height="42" fill="#2d3936"/>''',
}

for name, shapes in art.items():
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="256" height="128" viewBox="0 0 256 128">
<g opacity=".27"><ellipse cx="132" cy="113" rx="88" ry="8" fill="#030609"/></g>
{shapes}
</svg>\n'''
    (out / f"{escape(name)}.svg").write_text(svg, encoding="utf-8")
print(f"ammo_icons={len(art)} output={out}")
