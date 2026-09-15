class_name TextureAtlasBuilder
extends RefCounted
## Builds a single procedural texture atlas (pixel-art style, 16x16 tiles)
## used by every chunk mesh. No image files on disk — tiles are painted
## pixel-by-pixel with a small deterministic RNG so each block gets a
## noisy, hand-painted look instead of a flat color.

const TILE_SIZE := 16
const TILES_PER_ROW := 8
const ATLAS_PIXELS := TILE_SIZE * TILES_PER_ROW

static func build_atlas_image() -> Image:
	var image := Image.create(ATLAS_PIXELS, ATLAS_PIXELS, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 0.0, 1.0, 0.0))
	return image

static func tile_uv_rect(tile_index: int) -> Rect2:
	var col: int = tile_index % TILES_PER_ROW
	var row: int = tile_index / TILES_PER_ROW
	var tile_uv: float = 1.0 / float(TILES_PER_ROW)
	return Rect2(col * tile_uv, row * tile_uv, tile_uv, tile_uv)

## Fills a tile with a noisy grid of 3 shades around base_color, imitating
## hand-drawn pixel-art texture variation (like vanilla dirt/stone).
static func paint_noisy_tile(image: Image, tile_index: int, base_color: Color, variation: float) -> void:
	var col: int = tile_index % TILES_PER_ROW
	var row: int = tile_index / TILES_PER_ROW
	var origin_x: int = col * TILE_SIZE
	var origin_y: int = row * TILE_SIZE
	var rng := RandomNumberGenerator.new()
	rng.seed = tile_index * 7919 + 17
	var dark_color: Color = base_color.darkened(variation)
	var light_color: Color = base_color.lightened(variation * 0.6)
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			var roll: float = rng.randf()
			var pixel_color: Color = base_color
			if roll < 0.28:
				pixel_color = dark_color
			elif roll > 0.82:
				pixel_color = light_color
			image.set_pixel(origin_x + x, origin_y + y, pixel_color)

## Grass-side tile: dirt texture on the lower part, a jagged grass-green
## band along the top, matching the classic dirt-with-grass-fringe look.
static func paint_grass_side_tile(image: Image, tile_index: int, grass_color: Color, dirt_color: Color, variation: float) -> void:
	var col: int = tile_index % TILES_PER_ROW
	var row: int = tile_index / TILES_PER_ROW
	var origin_x: int = col * TILE_SIZE
	var origin_y: int = row * TILE_SIZE
	var rng := RandomNumberGenerator.new()
	rng.seed = tile_index * 7919 + 31
	var dirt_dark: Color = dirt_color.darkened(variation)
	var dirt_light: Color = dirt_color.lightened(variation * 0.6)
	var grass_dark: Color = grass_color.darkened(variation)
	var grass_light: Color = grass_color.lightened(variation * 0.6)
	var fringe_depth: PackedInt32Array = PackedInt32Array()
	for x in range(TILE_SIZE):
		fringe_depth.append(3 + rng.randi_range(0, 2))
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			var roll: float = rng.randf()
			var pixel_color: Color
			if y < fringe_depth[x]:
				pixel_color = grass_color
				if roll < 0.28:
					pixel_color = grass_dark
				elif roll > 0.82:
					pixel_color = grass_light
			else:
				pixel_color = dirt_color
				if roll < 0.28:
					pixel_color = dirt_dark
				elif roll > 0.82:
					pixel_color = dirt_light
			image.set_pixel(origin_x + x, origin_y + y, pixel_color)
