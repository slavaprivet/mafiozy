"""User rule: hospital at 50 percent health or lower; preserve living-body ownership."""
from pathlib import Path
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
GAME = HERE.parents[1] / 'game'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def replace_once(text, old, new):
    assert text.count(old) == 1, old
    return text.replace(old, new)

def main():
    assert not (HERE / 'PATCH.json').exists()
    life_path = 'scripts/npc_daily_life.gd'
    catalog_path = 'scripts/npc_needs_catalog.gd'
    life = (GAME / life_path).read_text(encoding='utf-8')
    life = replace_once(life, 'const MEDICAL_THRESHOLD := .75', 'const MEDICAL_THRESHOLD := .5')
    old = life[life.index('func _needs_hospital('):life.index('func _new_goal(')]
    new = '''func _needs_hospital(row: Dictionary) -> bool:
	if _now < _next_medical: return false
	if row.get("dead", false) or row.get("_medicalDowned", false) or row.get("_forcedCrawl", false) or float(row.get("max_hp", 0)) <= 0.0: return false
	if _dsh_simple_on(): return _hospital51_below_threshold(row)
	var threshold: float = _dsh_threshold() if _dsh_med_on() else MEDICAL_THRESHOLD
	var hp: float = _dsh_effective_hp(row) if _dsh_med_on() else float(row.get("hp", 0))
	return NeedsCatalog.health_at_or_below(row, hp, threshold)

func _hospital51_below_threshold(row: Dictionary) -> bool:
	# Existing callers share the user's inclusive half-health rule.
	if row.get("dead", false) or row.get("_medicalDowned", false) or row.get("_forcedCrawl", false) or float(row.get("max_hp", 0)) <= 0.0: return false
	return NeedsCatalog.health_at_or_below(row, _dsh_effective_hp(row), .5)

'''
    life = replace_once(life, old, new)
    life = replace_once(life, '_dsh_effective_hp(row) < float(row.get("max_hp",0))*_dsh_threshold()',
                        'NeedsCatalog.health_at_or_below(row, _dsh_effective_hp(row), _dsh_threshold())')
    life = life.replace('hp_pct < threshold_pct      (exactly 50.0 % with a 50 % threshold never goes)',
                        'hp_pct <= threshold_pct     (50.0 % is included by the user rule)')
    life = life.replace('strict_lt=true', 'strict_lt=false inclusive_lte=true')
    life = life.replace('hp_not_strictly_below_threshold', 'hp_above_threshold')
    life = life.replace('hp_strictly_below_threshold', 'hp_at_or_below_threshold')
    life = life.replace('the strict threshold was not crossed', 'HP remained above the threshold')
    catalog = (GAME / catalog_path).read_text(encoding='utf-8')
    catalog = catalog.replace('hp_below_max_fraction', 'hp_at_or_below_max_fraction')
    catalog = catalog.replace('hp < max_hp * fraction   (STRICTLY less: equals never)', '0 < hp <= max_hp * fraction (includes the boundary)')
    catalog = catalog.replace("owner's step 3: below half of its own bar the resident takes the hospital first", "user rule: at half of its own bar or lower the resident takes the hospital first")
    old_block = '''		var maximum: float = float(row.get("max_hp", 0))
		if maximum <= 0.0: return false
		# STRICTLY less, by the owner's rule: exactly the threshold never triggers.
		if not (float(row.get("hp", 0)) < maximum * float(condition["hp_at_or_below_max_fraction"])): return false
'''
    catalog = replace_once(catalog, old_block,
        '\t\tif not health_at_or_below(row, float(row.get("hp", 0)), float(condition["hp_at_or_below_max_fraction"])): return false\n')
    helper = '''## Shared by the schedule, immediate hit reaction, and medical queue.
static func health_at_or_below(row: Dictionary, hp: float, fraction: float) -> bool:
	var maximum: float = float(row.get("max_hp", 0))
	if row.get("dead", false) or row.get("_medicalDowned", false) or row.get("_forcedCrawl", false): return false
	if not is_finite(hp) or not is_finite(maximum) or not is_finite(fraction): return false
	return maximum > 0.0 and hp > 0.0 and fraction >= 0.0 and fraction <= 1.0 and hp <= maximum * fraction

'''
    catalog = replace_once(catalog, 'static func _matches(', helper + 'static func _matches(')
    changes = {}
    for relative, content in [(life_path, life), (catalog_path, catalog)]:
        target = HERE / 'patch' / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding='utf-8', newline='\n')
        changes[relative] = {'base_sha256': sha(GAME / relative), 'candidate_sha256': sha(target)}
    (HERE / 'PATCH.json').write_text(json.dumps(changes, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'prepared': True, 'files': len(changes), 'rule': 'living HP <= 50%'}))

if __name__ == '__main__':
    main()
