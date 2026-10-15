"""New independent harness directory; never changes archived V4 files."""
from pathlib import Path
H=Path(__file__).resolve().parent
old=H.parent/'qa58_merged_v4';new=H.parent/'qa58_merged_v5'
new.mkdir(exist_ok=False)
for p in old.iterdir():
    if p.is_file() and p.suffix in ['.gd','.py']:(new/p.name).write_bytes(p.read_bytes())
p=new/'entry_soak31_extended.gd';s=p.read_text(encoding='utf-8').replace('observer_soak58_v4.gd','observer_soak58_v5.gd');p.write_text(s,encoding='utf-8')
p=new/'run58.py';s=p.read_text(encoding='utf-8').replace("assembly_path = ROOT / 'outputs/coordinator31_release57/ASSEMBLY.json'",'assembly_path = args.expected_source.resolve()')
s=s.replace("OUT / 'observer_soak58_v4.gd',", "OUT / 'observer_soak58_v5.gd', OUT / 'observer_soak58_v4.gd',")
s=s.replace("flags = ordinary_flags(read(assembly_path), args.residents, args.extra)","flags = ordinary_flags(read(assembly_path), args.residents, args.extra)\n    need('--city-player-shop=1' in flags, 'Final combined observer requires real player shop')")
p.write_text(s,encoding='utf-8')
