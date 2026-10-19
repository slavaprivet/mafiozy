from pathlib import Path
import json

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]
OLD = ROOT/'outputs/coordinator29_npc53/proposals/ambient29/qa'

def replace(s,a,b):
    assert s.count(a)==1,a[:100]
    return s.replace(a,b,1)

def main():
    # Historical one-time port. Later adapted QA files are authoritative.
    if (OUT/'qa/fixture30.gd').exists():
        raise RuntimeError('Refusing to overwrite the adapted fixture. Use the saved qa sources.')
    (OUT/'qa').mkdir(exist_ok=True)
    s=(OLD/'fixture29.gd').read_text(encoding='utf-8')
    s=replace(s,'var _walk_start := Vector3.ZERO','var _walk_start := Vector3.ZERO\nvar _requested_kinds30: Array = []\nvar _max_foot_error30 := 0.0\nvar _max_body_step30 := 0.0\nvar _rig_report30: Dictionary = {}')
    s=replace(s,'\t\tif arg.begins_with("--qa-kind="): _cancel_kind = arg.trim_prefix("--qa-kind=")','\t\tif arg.begins_with("--qa-kind="): _cancel_kind = arg.trim_prefix("--qa-kind=")\n\t\tif arg.begins_with("--qa-kinds="): _requested_kinds30 = Array(arg.trim_prefix("--qa-kinds=").split(","))')
    s=replace(s,'\t_identity = FixtureIdentity.new();','\tfor bone: int in _rig.get_bone_count():\n\t\t_rig_report30[_rig.get_bone_name(bone)] = {"parent":_rig.get_bone_parent(bone),"local":str(_gait._rest_poses[bone]),"global":str(_pose._global[bone]),"global_position":_rig.to_global(_pose._global[bone].origin)}\n\t_rig_report30["reach"] = _pose._reach\n\t_rig_report30["rig_global"] = str(_rig.global_transform)\n\t_identity = FixtureIdentity.new();')
    s=replace(s,'var kinds: Array = Pose.KINDS if _cancel_phase.is_empty() else [_cancel_kind]','var kinds: Array = (Pose.KINDS if _requested_kinds30.is_empty() else _requested_kinds30) if _cancel_phase.is_empty() else [_cancel_kind]')
    s=replace(s,'\tif not value.is_empty(): selected = _pose.compose(selected,value)','\tvar foot_targets30: Dictionary = {}\n\tif not value.is_empty() and value.get("kind") == "bench":\n\t\t_pose._working = selected.poses.duplicate(); _pose._compose_globals()\n\t\tfor side30: String in ["l","r"]: foot_targets30[side30] = _rig.to_global(_pose._point("foot_"+side30))\n\tif not value.is_empty(): selected = _pose.compose(selected,value)')
    s=replace(s,'\tvar state: Dictionary = _ambient.snapshot()\n\tif state.phase == "ACTING"','\tfor side30: String in foot_targets30:\n\t\tvar actual30: Vector3 = _rig.to_global(_rig.get_bone_global_pose(_rig.find_bone("foot_"+side30)).origin)\n\t\t_max_foot_error30 = maxf(_max_foot_error30,actual30.distance_to(foot_targets30[side30]))\n\t_max_body_step30 = maxf(_max_body_step30,measured.length())\n\tvar state: Dictionary = _ambient.snapshot()\n\tif state.phase == "ACTING"')
    s=replace(s,'for view: String in ["full","side","hands"]:','for view: String in ["front","side","hands"]:')
    s=replace(s,'{"full":1.2,"side":2.2,"hands":3.2}[view]','{"front":1.2,"side":2.2,"hands":3.2}[view]')
    s=replace(s,'\tif view == "side": offset = side*3.6 + forward*.4 + Vector3.UP*1.6','\tif view == "front": offset = forward*3.4 + Vector3.UP*1.5\n\tif view == "side": offset = side*3.6 + Vector3.UP*1.6')
    s=replace(s,'"checks":_checks,"cancel_phase"','"rig_report30":_rig_report30,"max_foot_error30":_max_foot_error30,"max_body_step30":_max_body_step30,"requested_kinds30":_requested_kinds30,"checks":_checks,"cancel_phase"')
    (OUT/'qa/fixture30.gd').write_text(s,encoding='utf-8')
    s=(OLD/'entry_fixture29.gd').read_text(encoding='utf-8').replace('fixture29.gd','fixture30.gd')
    (OUT/'qa/entry_fixture30.gd').write_text(s,encoding='utf-8')
    print('fixture30 prepared; runtime unchanged')

if __name__=='__main__':main()
