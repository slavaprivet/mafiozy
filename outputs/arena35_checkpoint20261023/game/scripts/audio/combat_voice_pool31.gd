extends Node3D
## Scene-wide voice budget. A reset releases only the requesting sound owner.
const LIMIT:=32
var voices:Array[AudioStreamPlayer3D]=[]
var owners:Array[WeakRef]=[]
var refused:=0
func _ready():
 for i in LIMIT:
  var voice:=AudioStreamPlayer3D.new()
  voice.name="CombatVoice%02d"%i;voice.bus=&"Combat30"
  voice.unit_size=3.0;voice.max_distance=32.0
  voice.max_db=0.0;voice.panning_strength=.75
  add_child(voice);voice.top_level=true
  voices.append(voice);owners.append(null)
 set_process(false)
func claim(source:Node,at:Vector3)->AudioStreamPlayer3D:
 var camera:=get_viewport().get_camera_3d()
 # Inaudible distant effects cannot consume voices needed for nearby impacts.
 if is_instance_valid(camera) and camera.global_position.distance_squared_to(at)>1024.:
  refused+=1;return null
 for i in LIMIT:
  var owner:Node=owners[i].get_ref() if owners[i]!=null else null
  if voices[i].playing and is_instance_valid(owner):continue
  if voices[i].playing:voices[i].stop()
  owners[i]=weakref(source);set_process(true)
  return voices[i]
 refused+=1;return null
func release(source:Node):
 for i in LIMIT:
  if owners[i]!=null and owners[i].get_ref()==source:
   voices[i].stop();owners[i]=null
func _process(_delta:float):
 var active:=false
 for i in LIMIT:
  if not voices[i].playing:owners[i]=null;continue
  if owners[i]==null or not is_instance_valid(owners[i].get_ref()):
   voices[i].stop();owners[i]=null;continue
  active=true
 if not active:set_process(false)
