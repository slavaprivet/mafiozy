"""Adapt the frozen owner's native lamp QA to ordinary integrated 25a, without overlay hooks."""
import difflib
from common34 import *


def prepare_rear():
    source = REPO / 'outputs/coordinator24_rear_lights31/test_rear_lights31.gd'
    target = HERE / 'test_rear34.gd'
    original = source.read_bytes()
    require(original.count(OLD_REVISION.encode()) == 1, 'Accepted rear revision anchor changed')
    updated = original.replace(OLD_REVISION.encode(), REVISION.encode(), 1)
    if target.exists():
        require(target.read_bytes() == updated, 'Preserve reviewed rear fixture; unexpected edits')
    else:
        target.write_bytes(updated)
    (HERE / 'REAR_QA34_DELTA.patch').write_text(''.join(difflib.unified_diff(
        original.decode('utf-8-sig').splitlines(True), updated.decode('utf-8-sig').splitlines(True),
        fromfile='accepted31/test_rear_lights31.gd', tofile='root34/test_rear34.gd')), encoding='utf-8')
    receipt = {'status': 'PREPARED_NOT_RUN', 'source': str(source), 'source_sha256': sha(source),
               'qa_sha256': sha(target), 'only_change': OLD_REVISION + ' -> ' + REVISION,
               'scope': 'Exact accepted native rear fixture; GPU intentionally rejected by original script.'}
    write(HERE / 'REAR_QA34.json', receipt)
    return receipt


def prepare_dashboard(audio):
    source = HERE / 'dashboard_snapshot/test_dashboard.gd'
    target = HERE / 'test_dashboard34.gd'
    base_source = REPO / 'outputs/rear_lights_20260930/delivery24d/test_rear_lights.gd'
    base_target = HERE / 'dashboard_base34.gd'
    require(sha(base_source) == '1c595b05f900cf05ecefd739598782182021e6ac0edc26b1dd0ca94e29b971f9', 'Dashboard inherited fixture changed')
    original = source.read_text(encoding='utf-8-sig')
    text = original
    replacements = {
        'extends "../../rear_lights_20260930/delivery24d/test_rear_lights.gd"': 'extends "dashboard_base34.gd"',
        'const DashboardInstaller = preload("install.gd")\n': '',
        '\troot.child_entered_tree.connect(DashboardInstaller.install)\n': '',
        '\tDashboardInstaller.install(game)\n': '',
        'game.PREVIEW_RUNTIME_REVISION=="' + OLD_REVISION + '"': 'game.PREVIEW_RUNTIME_REVISION=="' + REVISION + '"',
        '"exact24f_base_retained"': '"exact_integrated25a_revision"',
        '\tvar notes := game.find_child("PreviewUpdates",true,false)': '\troot34_dashboard_guards()\n\tvar notes := game.find_child("PreviewUpdates",true,false)',
        '\tcheck(notes!=null and notes.get_status().get("notes",{}).get("title","")=="30.09 · Приборы и фонари · 24f","current_combined_update_notes_visible")':
            '\tvar packed_notes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/preview_updates.json"))\n\tcheck(notes!=null and not notes.get_status().get("restart_required",true) and notes.get_status().get("notes",{}).get("title","")==packed_notes.get("title") and notes.get_status().get("notes",{}).get("items",[])==packed_notes.get("items",[]),"current_integrated25a_notes_visible_without_overlay")',
    }
    for before, after in replacements.items():
        require(text.count(before) == 1, 'Dashboard fixture adaptation anchor changed: ' + before)
        text = text.replace(before, after, 1)
    base_original = base_source.read_text(encoding='utf-8-sig')
    base = base_original
    for line in ['const Installer = preload("install.gd")\n', '\troot.child_entered_tree.connect(Installer.install)\n', '\tInstaller.install(game)\n']:
        require(base.count(line) == 1, 'Inherited dashboard installer anchor changed')
        base = base.replace(line, '', 1)
    require(all(word not in text + base for word in ('Installer', 'install.gd', 'package/scripts', 'notes.setup(', 'load_resource_pack(')), 'External dashboard overlay remains reachable')
    checks = ['func root34_dashboard_guards() -> void:',
              '\tvar lamps: Node = controls.street_lamps',
              '\tcheck(game.get_node("QuickControlsHook").get_script().resource_path == "res://scripts/quick_controls/scene_hook.gd", "dashboard_integrated_hook")',
              '\tcheck(controls.get_script().resource_path == "res://scripts/quick_controls/quick_controls.gd", "dashboard_integrated_controls")',
              '\tcheck(dashboard.get_script().resource_path == "res://scripts/quick_controls/car_dashboard.gd", "dashboard_integrated_owner")',
              '\tcheck(lamps.get_script().resource_path == "res://scripts/quick_controls/street_lamps.gd", "dashboard_integrated_lamps")',
              '\tcheck(lamps.sound.get_script().resource_path == "res://scripts/quick_controls/street_glass_sound.gd", "dashboard_integrated_sound")',
              '\tvar lantern: Script = lamps.get_script().get_script_constant_map().get("Lantern")',
              '\tcheck(lantern != null and lantern.resource_path == "res://scripts/quick_controls/street_lamp_visual.gd", "dashboard_integrated_lantern")',
              '\tvar notes: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/preview_updates.json"))',
              '\tcheck(notes is Dictionary and notes.get("runtime_revision") == "' + REVISION + '" and notes.get("items", []).size() == 5, "dashboard_notes_match_integrated_revision")',
              '\tcheck(notes is Dictionary and notes.get("items", []).size() > 0 and "фонар" in str(notes.items[0]).to_lower(), "dashboard_first_note_has_lamps")',
              '\tcheck(game._block.buildings.size() == 8 and game.preview_population.hit_owners.size() == 3, "dashboard_full_eight_building_three_resident_scene")']
    for member, filename in [('headlights','car_headlights'), ('rear_lights','car_rear_lights'), ('horn','car_horn'), ('day_night','day_night'), ('day_clock','day_night_clock')]:
        checks.append('\tcheck(controls.' + member + '.get_script().resource_path == "res://scripts/quick_controls/' + filename + '.gd", "dashboard_integrated_' + member + '")')
    checks += ['\tcheck(FileAccess.get_sha256("res://' + n + '") == "' + digest + '", "dashboard_packed_audio:' + n + '")' for n, digest in audio.items()]
    added_checks = sum(line.startswith('\tcheck(') for line in checks)
    text += '\n' + '\n'.join(checks) + '\n'
    require(not target.exists() and not base_target.exists(), 'Preserve prepared dashboard fixtures')
    target.write_text(text, encoding='utf-8', newline='\n')
    base_target.write_text(base, encoding='utf-8', newline='\n')
    (HERE / 'DASHBOARD_QA34_DELTA.patch').write_text(''.join(difflib.unified_diff(original.splitlines(True), text.splitlines(True), fromfile='frozen_dashboard/test_dashboard.gd', tofile='root34/test_dashboard34.gd')) + ''.join(difflib.unified_diff(base_original.splitlines(True), base.splitlines(True), fromfile='accepted24d/test_rear_lights.gd', tofile='root34/dashboard_base34.gd')), encoding='utf-8')
    receipt = {'status': 'PREPARED_NOT_RUN', 'owner_qa_sha256': sha(source), 'qa_sha256': sha(target),
               'base_source': str(base_source), 'base_source_sha256': sha(base_source), 'base_qa_sha256': sha(base_target),
               'added_checks': added_checks, 'native_min_checks': 73 + added_checks, 'gpu_min_checks': 88 + added_checks,
               'physical_space_required': True,
               'scope': 'Final owner GPU88 fixture unchanged native E/F/W/Space/driver/passenger/speed/reload and real notes-overlap checks; both external installers removed. Owner headless73 used older source and is not final-source native proof.'}
    write(HERE / 'DASHBOARD_QA34.json', receipt)
    return receipt


def main():
    m = load_assembly()
    source = HERE / 'owner_snapshot/test_street_lamps.gd'
    target = HERE / 'test_street34.gd'
    require(not target.exists() and not (HERE / 'QA34.json').exists(), 'Preserve existing QA artifacts')
    text = source.read_text(encoding='utf-8-sig')
    original = text
    replacements = {
        'const Installer = preload("install.gd")\n': '',
        '\troot.child_entered_tree.connect(Installer.install)\n': '',
        '\tInstaller.install(game)\n': '',
        'game.PREVIEW_RUNTIME_REVISION == "' + OLD_REVISION + '"': 'game.PREVIEW_RUNTIME_REVISION == "' + REVISION + '"',
        '"latest_quality24f_building_corpse_and_rear_base"': '"integrated_quality25a_accepted31_base"',
    }
    for before, after in replacements.items():
        require(text.count(before) == 1, 'Owner QA changed; review adaptation anchor: ' + before)
        text = text.replace(before, after)
    require('Installer' not in text and 'package/scripts' not in text, 'Owner overlay still reachable')
    audio_rows = read(HERE / 'owner_snapshot/MANIFEST.json')['pins']
    audio = {r['destination']: r['sha256'] for r in audio_rows if r.get('destination') in NEW_AUDIO}
    require(set(audio) == set(NEW_AUDIO), 'All three audio payload guards required')
    checks = ['func root34_guards() -> void:',
              '\tcheck(game.get_node("QuickControlsHook").get_script().resource_path == "res://scripts/quick_controls/scene_hook.gd", "ordinary_integrated_hook")',
              '\tcheck(controls.get_script().resource_path == "res://scripts/quick_controls/quick_controls.gd", "ordinary_integrated_controls_no_external_overlay")',
              '\tcheck(lamps.get_script().resource_path == "res://scripts/quick_controls/street_lamps.gd", "ordinary_integrated_street_owner")',
              '\tcheck(lamps.sound.get_script().resource_path == "res://scripts/quick_controls/street_glass_sound.gd", "ordinary_integrated_glass_sound")',
              '\tcheck(controls.dashboard.get_script().resource_path == "res://scripts/quick_controls/car_dashboard.gd", "ordinary_integrated_dashboard")',
              '\tvar lantern: Script = lamps.get_script().get_script_constant_map().get("Lantern")',
              '\tcheck(lantern != null and lantern.resource_path == "res://scripts/quick_controls/street_lamp_visual.gd", "ordinary_integrated_lantern_helper")',
              '\tvar notes: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/preview_updates.json"))',
              '\tcheck(notes is Dictionary and notes.get("runtime_revision") == "' + REVISION + '" and notes.get("items", []).size() == 5, "five_visible_notes_match_running_revision")',
              '\tcheck(notes is Dictionary and notes.get("items", []).size() > 0 and "фонар" in str(notes.items[0]).to_lower(), "first_visible_note_describes_street_lamps")']
    for member, filename in [('headlights','car_headlights'), ('rear_lights','car_rear_lights'),
                             ('horn','car_horn'), ('day_night','day_night'), ('day_clock','day_night_clock')]:
        checks.append('\tcheck(controls.' + member + '.get_script().resource_path == "res://scripts/quick_controls/' + filename + '.gd", "ordinary_integrated_' + member + '")')
    checks += ['\tcheck(FileAccess.get_sha256("res://' + n + '") == "' + digest + '", "packed_audio_exact:' + n + '")'
               for n, digest in audio.items()]
    anchor = 'func count_preserved() -> void:'
    require(text.count(anchor) == 1 and text.count('\tcount_preserved()\n') == 1, 'Owner QA count anchors changed')
    text = text.replace(anchor, '\n'.join(checks) + '\n\n' + anchor)
    text = text.replace('\tcount_preserved()\n', '\troot34_guards()\n\tcount_preserved()\n', 1)
    target.write_text(text, encoding='utf-8', newline='\n')
    (HERE / 'QA34_DELTA.patch').write_text(''.join(difflib.unified_diff(original.splitlines(True), text.splitlines(True),
                        fromfile='frozen_owner/test_street_lamps.gd', tofile='root34/test_street34.gd')), encoding='utf-8')
    rear = prepare_rear()
    dashboard = prepare_dashboard(audio)
    write(HERE / 'QA34.json', {'status': 'PREPARED_NOT_RUN', 'assembly_sha256': sha(ASSEMBLY),
          'owner_qa_sha256': sha(source), 'qa_sha256': sha(target), 'prepare_sha256': sha(Path(__file__)),
          'rear_qa_sha256': rear['qa_sha256'],
          'dashboard_qa_sha256': dashboard['qa_sha256'], 'dashboard_base_sha256': dashboard['base_qa_sha256'],
          'dashboard_native_min_checks': dashboard['native_min_checks'], 'dashboard_gpu_min_checks': dashboard['gpu_min_checks'],
          'scope': 'Final owner real-TT lamp and driver dashboard suites retained; all subclass/base installers removed; real integrated revision/notes/resources/audio guarded. Dashboard native and GPU require actual accepted Space input, not fallback control fixture.',
          'performance_accepted': False})


if __name__ == '__main__':
    main()
