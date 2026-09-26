extends RefCounted
## Native Walk dry-surface material port. No geometry, lighting or texture changes.
## Source: environment_surface_materials.mjs, environment_visuals.mjs, terrain().

const TILE_KIND: Dictionary = {0: "asphalt", 8: "grass", 9: "paving", 14: "sand", 16: "water", 19: "asphalt"}
const PRESETS: Dictionary = {
	"grass": {"color": "#748d68", "roughness": 0.95, "mode": 0, "bump": 0.010},
	"asphalt": {"color": "#525b59", "roughness": 0.9, "mode": 2, "bump": 0.005},
	"paving": {"color": "#c0bda7", "roughness": 0.89, "mode": 3, "bump": 0.006},
	"sand": {"color": "#cfbd96", "roughness": 0.97, "mode": 4, "bump": 0.021},
}
const ASPHALT_DESCRIPTOR_ID: String = "MAT_CLAY_ASPHALT_CLEAN"

# Shader is shared by all dry material instances. Its formulas and numeric
# coefficients come from Walk's environment_surface_materials.mjs revision 4.
# source_origin_m restores source-world coordinates after preview recentering.
const DRY_SHADER: String = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;
uniform vec4 walk_albedo : source_color = vec4(1.0);
uniform float source_roughness = 0.9;
uniform float source_bump = 0.005;
uniform int surface_mode = 2;
uniform vec3 source_origin_m = vec3(0.0);
varying vec3 environment_world;

float environment_hash(vec2 p) {
 vec3 p3 = fract(vec3(p.xyx) * vec3(.1031,.1030,.0973));
 p3 += dot(p3,p3.yzx+33.33);
 return fract((p3.x+p3.y)*p3.z);
}
float environment_noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(environment_hash(i),environment_hash(i+vec2(1.0,0.0)),f.x),
            mix(environment_hash(i+vec2(0.0,1.0)),environment_hash(i+vec2(1.0,1.0)),f.x),f.y);
}
void vertex() {
 environment_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz+source_origin_m;
}
void fragment() {
 vec2 xz=environment_world.xz;
 float footprint=max(length(dFdx(xz)),length(dFdy(xz)));
 float broad=environment_noise(xz*.055);
 float frequency=surface_mode==0 ? .55 : (surface_mode==2 ? .19 : .53);
 float mottling=environment_noise(xz*frequency+vec2(17.3,9.1));
 float relief=(mottling-.5)*.20;
 float surface_roughness=0.0;
 float shade=1.0;
 vec3 diffuse=walk_albedo.rgb;
 if (surface_mode==0) {
  float field=broad*.62+mottling*.38;
  float clump=smoothstep(.27,.76,field);
  float soil=smoothstep(.73,.91,broad)*smoothstep(.59,.78,1.0-mottling);
  vec3 tint=mix(vec3(.86,.94,.82),vec3(1.09,1.01,.79),clump);
  shade=.94+.15*(broad-.5)+.10*(mottling-.5);
  diffuse*=tint;
  diffuse=mix(diffuse,vec3(.255,.205,.125),soil*.34);
  relief=(mottling-.5)*.55+(broad-.5)*.18-soil*.16;
  surface_roughness=.018*(mottling-.5)+soil*.045;
 } else if (surface_mode==2) {
  vec2 grain_coord=xz*55.0;
  float grain_footprint=max(fwidth(grain_coord.x),fwidth(grain_coord.y));
  float fine_fade=1.0-smoothstep(.10,.40,grain_footprint);
  float grain=environment_noise(grain_coord);
  float wear=smoothstep(.57,.83,mottling)*smoothstep(.30,.68,broad);
  float crack_field=abs(fract(mottling*2.73+broad*1.41)-.5);
  float crack_aa=max(fwidth(crack_field),.003);
  float crack=(1.0-smoothstep(.014,.030+crack_aa,crack_field))*smoothstep(.42,.76,broad)*fine_fade;
  vec2 patch_coord=mat2(vec2(.940,-.342),vec2(.342,.940))*xz/8.4;
  vec2 patch_cell=floor(patch_coord),patch_local=fract(patch_coord)-.5;
  float patch_seed=environment_hash(patch_cell+vec2(71.3,19.7));
  vec2 patch_size=vec2(.17+.11*patch_seed,.12+.07*environment_hash(patch_cell+vec2(9.2,83.6)));
  vec2 patch_delta=abs(patch_local)-patch_size;
  float patch_distance=length(max(patch_delta,vec2(0.0)))+min(max(patch_delta.x,patch_delta.y),0.0);
  float patch_aa=max(fwidth(patch_distance),.002);
  float patch=(1.0-smoothstep(-.006,.018+patch_aa,patch_distance))*step(.84,patch_seed);
  float patch_edge=(1.0-smoothstep(.0,.020+patch_aa,abs(patch_distance)))*step(.84,patch_seed);
  shade=.985+.045*(broad-.5)+.042*wear+.055*(grain-.5)*fine_fade-crack*.13-patch*.065-patch_edge*.055;
  relief=(grain-.5)*.13*fine_fade-crack*.18-patch_edge*.12;
  surface_roughness=crack*.045+patch*.075-wear*.018;
 } else if (surface_mode==3) {
  vec2 tile=xz/vec2(1.45,.90);
  tile.x+=mod(floor(tile.y),2.0)*.5;
  vec2 cell=floor(tile),local=fract(tile);
  vec2 edge=min(local,vec2(1.0)-local)*vec2(1.45,.90);
  float distance=min(edge.x,edge.y);
  float aa=max(footprint*.7,.001);
  float joint=1.0-smoothstep(.004,.012+aa,distance);
  float bevel=1.0-smoothstep(.008,.034+aa,distance);
  float stone_fade=1.0-smoothstep(.08,.38,footprint);
  float stone_tone=environment_hash(cell+vec2(43.1,71.7))-.5;
  shade=.99+.075*stone_tone*stone_fade+.022*(broad-.5)+.014*(mottling-.5)-joint*.095*stone_fade;
  relief=-bevel*.45*stone_fade;
 } else if (surface_mode==4) {
  float phase=xz.x*4.8+xz.y*.9+mottling*1.6;
  float ridge=sin(phase);
  float fade=1.0-smoothstep(.30,1.30,fwidth(phase));
  shade=.98+.08*(broad-.5)+.014*ridge*fade;
  relief+=ridge*.07*fade;
 }
 ALBEDO=diffuse*shade;
 ROUGHNESS=clamp(source_roughness+(mottling-.5)*.055+surface_roughness,.75,1.0);
 METALLIC=0.0;
 SPECULAR=0.5;
 vec3 dx=dFdx(VERTEX),dy=dFdy(VERTEX);
 vec3 r1=cross(dy,NORMAL),r2=cross(NORMAL,dx);
 float det=dot(dx,r1);
 vec3 gradient=sign(det)*(dFdx(relief)*r1+dFdy(relief)*r2);
 NORMAL=normalize(abs(det)*NORMAL-gradient*source_bump+NORMAL*1e-8);
}
"""

static var _shared_dry_shader: Shader


static func surface_kind(tile_id: int, protected_cell: bool = false) -> String:
	# terrain() maps the special protected key to nativeTerrainKind='paving'.
	return "paving" if protected_cell else str(TILE_KIND.get(tile_id, ""))


static func create_material(surface: Dictionary, tile_id: int, source_origin: Vector3 = Vector3.ZERO, protected_cell: bool = false, detail: bool = true) -> Material:
	var kind: String = surface_kind(tile_id, protected_cell)
	if kind.is_empty() or not surface.get("palette", {}).has(str(tile_id)):
		push_error("Unmapped source surface tile: %d" % tile_id)
		return null
	var base: StandardMaterial3D = create_base_material(surface, tile_id, protected_cell)
	if base == null or not detail or kind == "water":
		if base != null and kind == "water":
			base.set_meta("migration_limit", "Base native water only; depth, ripples and absorption not migrated")
		return base
	if _shared_dry_shader == null:
		_shared_dry_shader = Shader.new()
		_shared_dry_shader.code = DRY_SHADER
	var preset: Dictionary = PRESETS[kind]
	var material := ShaderMaterial.new()
	material.shader = _shared_dry_shader
	material.resource_name = "Walk environment surface - " + kind
	material.set_shader_parameter("walk_albedo", Color(str(preset.color)))
	material.set_shader_parameter("source_roughness", float(preset.roughness))
	material.set_shader_parameter("source_bump", float(preset.bump))
	material.set_shader_parameter("surface_mode", int(preset.mode))
	material.set_shader_parameter("source_origin_m", source_origin)
	material.set_meta("source_kind", kind)
	material.set_meta("source_environment_revision", 4)
	material.set_meta("source_base_material", base)
	material.set_meta("source_layer", "environment_surface_materials.mjs replaces the native base material")
	return material


static func create_base_material(surface: Dictionary, tile_id: int, protected_cell: bool = false) -> StandardMaterial3D:
	var palette: Dictionary = surface.get("palette", {})
	if not TILE_KIND.has(tile_id) or not palette.has(str(tile_id)):
		return null
	var material := StandardMaterial3D.new()
	var water: bool = tile_id == 16 and not protected_cell
	material.resource_name = "Walk native base - " + surface_kind(tile_id, protected_cell)
	material.albedo_color = Color(str(surface.get("protectedColorSrgb", "#9a9990") if protected_cell else palette[str(tile_id)].colorSrgb))
	material.roughness = 0.22 if water else 0.88
	material.metallic = 0.14 if water else 0.0
	# Exact terrain() scope: only unprotected tile 0 uses the asphalt descriptor.
	# Tile 19 receives its native palette, then the same environment asphalt layer.
	if tile_id == 0 and not protected_cell:
		var descriptor: Dictionary = {}
		for item: Dictionary in surface.get("materialDescriptors", []):
			if str(item.get("id", "")) == ASPHALT_DESCRIPTOR_ID:
				descriptor = item
				break
		if not descriptor.is_empty():
			var factor: Variant = descriptor.get("baseColorFactor")
			if str(descriptor.get("colorSpace", "")) != "linear_srgb" or not factor is Array or factor.size() != 4:
				push_error("Unsupported source asphalt colour descriptor")
				return null
			for channel: Variant in factor:
				if not (channel is float or channel is int) or not is_finite(float(channel)) or float(channel) < 0.0 or float(channel) > 1.0:
					push_error("Invalid source asphalt colour channel")
					return null
			var linear := Color(float(factor[0]), float(factor[1]), float(factor[2]), float(factor[3]))
			material.albedo_color = linear.linear_to_srgb()
			material.roughness = float(descriptor.get("roughnessFactor", 0.8))
			material.metallic = float(descriptor.get("metallicFactor", 0.0))
			material.set_meta("source_descriptor_id", ASPHALT_DESCRIPTOR_ID)
			material.set_meta("source_base_color_linear", linear)
	# The original terrain() does not adopt descriptor.doubleSided; preserve its
	# front-side material rather than adding a new two-sided surface cost.
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.set_meta("source_kind", surface_kind(tile_id, protected_cell))
	material.set_meta("source_layer", "walk_preview.mjs terrain() intermediate base")
	return material
