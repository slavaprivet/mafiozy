extends RefCounted
## Small shared kit for the gate-top defence props: merged box geometry, a lathe mesh
## for the cauldron, procedural soft particles and short procedural sounds.
##
## Everything here is built once at install time and then reused. No per-frame mesh,
## material or audio allocation is performed by this file.

const RATE := 22050


## ------------------------------------------------------------------ materials

static func tinted(base: Color, roughness: float, metallic: float = 0.0,
		vertex_color: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = base
	material.roughness = roughness
	material.metallic = metallic
	material.vertex_color_use_as_albedo = vertex_color
	return material


static func bright(base: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := tinted(base, roughness, metallic)
	material.emission_enabled = true
	material.emission = base
	material.emission_energy_multiplier = 0.35
	return material


## ------------------------------------------------------------------ merged boxes

## parts: [{ "at": Vector3, "size": Vector3, "rot": Vector3, "color": Color }] or
##        [{ "xf": Transform3D, "color": Color }]
static func box_batch(parts: Array, material: Material) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var arrays: Array = box.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for part: Dictionary in parts:
		var xf: Transform3D
		if part.has("xf"):
			xf = part["xf"]
		else:
			var at: Vector3 = part.get("at", Vector3.ZERO)
			var size: Vector3 = part.get("size", Vector3.ONE)
			var rot: Vector3 = part.get("rot", Vector3.ZERO)
			xf = Transform3D(Basis.from_euler(rot) * Basis.IDENTITY.scaled(size), at)
		var color: Color = part.get("color", Color.WHITE)
		surface.set_color(color)
		for index: int in indices:
			surface.add_vertex(xf * vertices[index])
	surface.generate_normals()
	var mesh := surface.commit()
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	return node


## A beam between two points. `width` is across the run, `depth` is the other side.
static func beam(a: Vector3, b: Vector3, width: float, depth: float,
		color: Color) -> Dictionary:
	var delta := b - a
	var length := delta.length()
	if length < 0.0001:
		return {"xf": Transform3D(Basis.IDENTITY, a), "color": color}
	var basis := Basis(Quaternion(Vector3.UP, delta.normalized())) * Basis.IDENTITY.scaled(
		Vector3(width, length, depth))
	return {"xf": Transform3D(basis, (a + b) * 0.5), "color": color}


static func box(at: Vector3, size: Vector3, color: Color,
		rot: Vector3 = Vector3.ZERO) -> Dictionary:
	return {"at": at, "size": size, "rot": rot, "color": color}


## Merge arbitrary primitive meshes under one material. Vertex colours are kept when
## the source mesh carries them; parts without colours use white.
static func merge_meshes(parts: Array, material: Material) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part: Dictionary in parts:
		var mesh: Mesh = part.get("mesh")
		if mesh == null:
			continue
		var xf: Transform3D = part.get("xf", Transform3D.IDENTITY)
		surface.append_from(mesh, 0, xf)
	surface.generate_normals()
	var merged := surface.commit()
	var node := MeshInstance3D.new()
	node.mesh = merged
	node.material_override = material
	return node


## ------------------------------------------------------------------ cauldron lathe

## A lumpy low-poly stone: a sphere whose ring radius is perturbed per vertex. One
## shared mesh is instanced by every falling stone, so a dozen rocks cost one draw.
static func rock_mesh(seed_value: int = 7, rings: int = 5, segments: int = 8) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array = []
	for ring: int in rings + 1:
		var latitude: float = -PI * 0.5 + PI * float(ring) / float(rings)
		var row: Array[Vector3] = []
		for segment: int in segments:
			var longitude: float = TAU * float(segment) / float(segments)
			var wobble: float = 1.0 + rng.randf_range(-0.18, 0.18)
			var radius: float = cos(latitude) * 0.5 * wobble
			row.append(Vector3(cos(longitude) * radius, sin(latitude) * 0.5 * wobble,
				sin(longitude) * radius))
		grid.append(row)
	for ring: int in rings:
		var a: Array = grid[ring]
		var b: Array = grid[ring + 1]
		for segment: int in segments:
			var next: int = (segment + 1) % segments
			_triangle(surface, a[segment], b[segment], a[next])
			_triangle(surface, a[next], b[segment], b[next])
	return surface.commit()

static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	var centre := (a + b + c) / 3.0
	if normal.dot(centre) < 0.0:
		normal = -normal
	surface.set_normal(normal)
	surface.set_color(Color.WHITE)
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)


## profile: [(radius, y), ...] from the bottom centre outward and up to the rim, then
## back down the inside. Segments are around Y. Vertex colour gives soot and wear
## without a texture.
static func lathe(profile: Array, segments: int, colors: Array) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: int = profile.size()
	for ring: int in rings - 1:
		var a: Vector2 = profile[ring]
		var b: Vector2 = profile[ring + 1]
		var ca: Color = colors[ring]
		var cb: Color = colors[ring + 1]
		for segment: int in segments:
			var a0 := TAU * float(segment) / float(segments)
			var a1 := TAU * float(segment + 1) / float(segments)
			var p00 := Vector3(cos(a0) * a.x, a.y, sin(a0) * a.x)
			var p01 := Vector3(cos(a1) * a.x, a.y, sin(a1) * a.x)
			var p10 := Vector3(cos(a0) * b.x, b.y, sin(a0) * b.x)
			var p11 := Vector3(cos(a1) * b.x, b.y, sin(a1) * b.x)
			surface.set_color(ca)
			surface.add_vertex(p00)
			surface.set_color(cb)
			surface.add_vertex(p10)
			surface.set_color(ca)
			surface.add_vertex(p01)
			surface.set_color(ca)
			surface.add_vertex(p01)
			surface.set_color(cb)
			surface.add_vertex(p10)
			surface.set_color(cb)
			surface.add_vertex(p11)
	surface.generate_normals()
	return surface.commit()


## ------------------------------------------------------------------ particles

static func soft_texture(size: int = 64) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var centre := float(size - 1) * 0.5
	for y: int in size:
		for x: int in size:
			var dx := (float(x) - centre) / centre
			var dy := (float(y) - centre) / centre
			var r := sqrt(dx * dx + dy * dy)
			var alpha: float = clampf(1.0 - r, 0.0, 1.0)
			alpha = alpha * alpha * (3.0 - 2.0 * alpha)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)


static func particle_material(texture: Texture2D, additive: bool,
		alpha: float = 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive \
		else BaseMaterial3D.BLEND_MODE_MIX
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.albedo_texture = texture
	material.albedo_color = Color(1.0, 1.0, 1.0, alpha)
	material.vertex_color_use_as_albedo = true
	material.disable_receive_shadows = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


static func quad(material: Material, size: float = 1.0) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	plane.orientation = PlaneMesh.FACE_Z
	var node := MeshInstance3D.new()
	node.mesh = plane
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## A compact sprite particle system. `colors` is a list of [offset, Color] points.
static func particles(amount: int, lifetime: float, texture: Texture2D,
		additive: bool, colors: Array, velocity: Vector2, spread: float,
		gravity: Vector3, sizes: Vector2, one_shot: bool = false,
		emitting: bool = true, radius: float = 0.12) -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = radius
	process.direction = Vector3.UP
	process.spread = spread
	process.initial_velocity_min = velocity.x
	process.initial_velocity_max = velocity.y
	process.gravity = gravity
	process.scale_min = sizes.x
	process.scale_max = sizes.y
	process.angle_min = -180.0
	process.angle_max = 180.0
	process.lifetime_randomness = 0.35
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array()
	gradient.colors = PackedColorArray()
	for point: Array in colors:
		gradient.add_point(float(point[0]), point[1] as Color)
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.65))
	curve.add_point(Vector2(0.25, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var curve_texture := CurveTexture.new()
	curve_texture.curve = curve
	process.scale_curve = curve_texture
	var node := GPUParticles3D.new()
	node.amount = amount
	node.lifetime = lifetime
	node.one_shot = one_shot
	node.explosiveness = 0.92 if one_shot else 0.0
	node.fixed_fps = 30
	node.emitting = emitting
	node.process_material = process
	var sprite := PlaneMesh.new()
	sprite.size = Vector2(1.0, 1.0)
	sprite.orientation = PlaneMesh.FACE_Z
	sprite.surface_set_material(0, particle_material(texture, additive))
	node.draw_pass_1 = sprite
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_aabb = AABB(Vector3(-6, -6, -6), Vector3(12, 12, 12))
	return node


static func dust(parent: Node3D, at: Vector3, texture: Texture2D,
		color: Color = Color(0.52, 0.47, 0.38)) -> GPUParticles3D:
	var node := particles(20, 1.1, texture, false,
		[[0.0, Color(color.r, color.g, color.b, 0.0)],
		[0.12, Color(color.r, color.g, color.b, 0.34)],
		[0.45, Color(color.r, color.g, color.b, 0.20)],
		[1.0, Color(color.r, color.g, color.b, 0.0)]],
		Vector2(0.7, 2.4), 48.0, Vector3(0.0, -2.0, 0.0), Vector2(0.25, 0.85),
		true, false, 0.22)
	node.position = at
	parent.add_child(node)
	node.emitting = true
	return node


## ------------------------------------------------------------------ sound

## Short mono procedural sound. `sweep` bends the tone over the duration.
static func sfx(duration: float, base_hz: float, noise: float, decay: float,
		sweep: float = 0.0, seed_value: int = 1) -> AudioStreamWAV:
	var frames: int = maxi(8, int(duration * RATE))
	var data := PackedByteArray()
	data.resize(frames * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var phase := 0.0
	for i: int in frames:
		var t := float(i) / float(RATE)
		var envelope: float = exp(-t * decay)
		var frequency: float = base_hz * (1.0 + sweep * t)
		phase += TAU * frequency / float(RATE)
		var tone: float = sin(phase)
		var grit: float = rng.randf_range(-1.0, 1.0)
		var sample: float = (tone * (1.0 - noise) + grit * noise) * envelope
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream


static func looped_sfx(duration: float, base_hz: float, noise: float,
		seed_value: int = 1) -> AudioStreamWAV:
	var stream := sfx(duration, base_hz, noise, 0.0, 0.0, seed_value)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(duration * RATE)
	return stream


static func play_3d(parent: Node, stream: AudioStream, at: Vector3,
		volume_db: float = 0.0, pitch: float = 1.0,
		max_distance: float = 48.0) -> AudioStreamPlayer3D:
	if stream == null or not is_instance_valid(parent):
		return null
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.unit_size = 5.0
	player.max_distance = max_distance
	player.volume_db = volume_db
	player.pitch_scale = pitch
	parent.add_child(player)
	player.global_position = at
	player.play()
	player.finished.connect(player.queue_free)
	return player
