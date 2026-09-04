extends RefCounted
## Procedural texture generation -- everything here builds Image/NoiseTexture2D
## resources at runtime (noise fields, hand-rolled radial gradients, layered
## multi-tone camo) so materials, decals and particles have real surface
## detail without a single external art asset.

static func make_noise_material(base_color: Color, roughness: float = 0.85, contrast: float = 0.18, uv_scale: float = 4.0) -> StandardMaterial3D:
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.055
	noise.fractal_octaves = 3

	var noise_tex := NoiseTexture2D.new()
	noise_tex.width = 128
	noise_tex.height = 128
	noise_tex.seamless = true
	noise_tex.generate_mipmaps = true
	noise_tex.noise = noise
	noise_tex.color_ramp = _make_gradient(base_color, contrast)

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = noise_tex
	mat.roughness = roughness
	mat.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
	return mat

static func _make_gradient(base_color: Color, contrast: float) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, base_color.darkened(contrast))
	g.set_color(1, base_color.lightened(contrast * 0.6))
	g.add_point(0.55, base_color)
	return g

static func make_camo_material(colors: Array, roughness: float = 0.92, uv_scale: float = 2.0) -> StandardMaterial3D:
	var size := 64
	var noise_a := FastNoiseLite.new()
	noise_a.seed = randi()
	noise_a.frequency = 0.1
	var noise_b := FastNoiseLite.new()
	noise_b.seed = randi()
	noise_b.frequency = 0.2

	var img := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	for y in range(size):
		for x in range(size):
			var n: float = noise_a.get_noise_2d(x, y) * 0.65 + noise_b.get_noise_2d(x, y) * 0.35
			var t: float = clamp((n + 1.0) * 0.5, 0.0, 0.9999)
			var idx: int = int(t * colors.size())
			img.set_pixel(x, y, colors[idx])

	var tex := ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = roughness
	mat.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
	return mat

static func make_glow_texture(color: Color, size: int = 32, falloff: float = 1.6) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)
	var max_dist := size / 2.0
	for y in range(size):
		for x in range(size):
			var dist: float = Vector2(x + 0.5, y + 0.5).distance_to(center) / max_dist
			var alpha: float = clamp(1.0 - dist, 0.0, 1.0)
			alpha = pow(alpha, falloff)
			img.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
	return ImageTexture.create_from_image(img)

static func make_scorch_texture(size: int = 48) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.35
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)
	var max_dist := size / 2.0
	for y in range(size):
		for x in range(size):
			var dist: float = Vector2(x + 0.5, y + 0.5).distance_to(center) / max_dist
			var jitter: float = noise.get_noise_2d(x, y) * 0.18
			var alpha: float = clamp(1.0 - (dist + jitter) * 1.15, 0.0, 1.0)
			alpha = pow(alpha, 1.3)
			img.set_pixel(x, y, Color(0.02, 0.02, 0.02, alpha * 0.85))
	return ImageTexture.create_from_image(img)

static func spawn_decal(parent: Node, position: Vector3, normal: Vector3, texture: Texture2D, size: Vector3, lifetime: float = 25.0) -> void:
	var decal := Decal.new()
	parent.add_child(decal)
	var basis := Basis(Quaternion(Vector3.UP, normal))
	decal.global_transform = Transform3D(basis, position + normal * 0.01)
	decal.size = size
	decal.texture_albedo = texture
	decal.get_tree().create_timer(lifetime).timeout.connect(decal.queue_free)

static func spawn_spark_burst(parent: Node, position: Vector3, normal: Vector3, color: Color, count: int = 10) -> void:
	var particles := GPUParticles3D.new()
	parent.add_child(particles)
	particles.global_position = position
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = count
	particles.lifetime = 0.4
	particles.speed_scale = 1.0

	var pmat := ParticleProcessMaterial.new()
	var dir: Vector3 = normal if normal.length() > 0.01 else Vector3.UP
	pmat.direction = dir
	pmat.spread = 50.0
	pmat.initial_velocity_min = 1.5
	pmat.initial_velocity_max = 4.0
	pmat.gravity = Vector3(0, -7.0, 0)
	pmat.scale_min = 0.35
	pmat.scale_max = 0.9
	pmat.color = color
	particles.process_material = pmat

	var qm := QuadMesh.new()
	qm.size = Vector2(0.045, 0.045)
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.albedo_color = color
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.material = pm
	particles.draw_pass_1 = qm

	particles.emitting = true
	particles.get_tree().create_timer(1.5).timeout.connect(particles.queue_free)

static func make_blood_texture(size: int = 40) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.4
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)
	var max_dist := size / 2.0
	for y in range(size):
		for x in range(size):
			var dist: float = Vector2(x + 0.5, y + 0.5).distance_to(center) / max_dist
			var jitter: float = noise.get_noise_2d(x, y) * 0.22
			var alpha: float = clamp(1.0 - (dist + jitter) * 1.2, 0.0, 1.0)
			alpha = pow(alpha, 1.1)
			img.set_pixel(x, y, Color(0.35, 0.02, 0.02, alpha * 0.8))
	return ImageTexture.create_from_image(img)
