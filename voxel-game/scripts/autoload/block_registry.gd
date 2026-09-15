extends Node
## Autoload singleton "BlockRegistry". Single source of truth for all block
## data and the shared texture atlas / material used by every chunk mesh.
## Game code must never branch on a raw block id — always go through here.

const AIR_ID := 0

const TILE_DIRT := 0
const TILE_STONE := 1
const TILE_GRASS_TOP := 2
const TILE_GRASS_SIDE := 3
const TILE_WOOD_TOP := 4
const TILE_WOOD_SIDE := 5
const TILE_LEAVES := 6
const TILE_SAND := 7
const TILE_PLANKS := 8
const TILE_COBBLESTONE := 9

var blocks: Array[BlockType] = []
var atlas_texture: ImageTexture
var chunk_material: StandardMaterial3D

var _id_to_block: Dictionary = {}
var _name_to_id: Dictionary = {}

func _ready() -> void:
	_register_blocks()
	_build_atlas()
	_build_material()

func register_block(block: BlockType) -> void:
	blocks.append(block)
	_id_to_block[block.id] = block
	_name_to_id[block.block_name] = block.id

func get_block(id: int) -> BlockType:
	return _id_to_block.get(id, null) as BlockType

func get_id_by_name(block_name: String) -> int:
	return _name_to_id.get(block_name, AIR_ID) as int

func is_air(id: int) -> bool:
	return id == AIR_ID

func is_transparent(id: int) -> bool:
	if id == AIR_ID:
		return true
	var block: BlockType = get_block(id)
	if block == null:
		return true
	return block.is_transparent

func is_solid(id: int) -> bool:
	if id == AIR_ID:
		return false
	var block: BlockType = get_block(id)
	if block == null:
		return false
	return block.is_solid

func get_uv_rect(tile_index: int) -> Rect2:
	return TextureAtlasBuilder.tile_uv_rect(tile_index)

## Small icon for UI (hotbar/inventory slots), cropped from the same atlas
## used for chunk meshes so it always matches the in-world texture.
func get_icon_texture(id: int) -> AtlasTexture:
	var block: BlockType = get_block(id)
	if block == null:
		return null
	var uv_rect: Rect2 = get_uv_rect(block.texture_top)
	var pixels: float = float(TextureAtlasBuilder.ATLAS_PIXELS)
	var atlas_tex := AtlasTexture.new()
	atlas_tex.atlas = atlas_texture
	atlas_tex.region = Rect2(uv_rect.position * pixels, uv_rect.size * pixels)
	return atlas_tex

func _register_blocks() -> void:
	var air := BlockType.new()
	air.id = AIR_ID
	air.block_name = "air"
	air.is_transparent = true
	air.is_solid = false
	air.hardness = 0.0
	air.drop_item = ""
	register_block(air)

	var dirt := BlockType.new()
	dirt.id = 1
	dirt.block_name = "dirt"
	dirt.texture_top = TILE_DIRT
	dirt.texture_side = TILE_DIRT
	dirt.texture_bottom = TILE_DIRT
	dirt.is_transparent = false
	dirt.is_solid = true
	dirt.hardness = 0.5
	dirt.drop_item = "dirt"
	register_block(dirt)

	var stone := BlockType.new()
	stone.id = 2
	stone.block_name = "stone"
	stone.texture_top = TILE_STONE
	stone.texture_side = TILE_STONE
	stone.texture_bottom = TILE_STONE
	stone.is_transparent = false
	stone.is_solid = true
	stone.hardness = 1.5
	stone.drop_item = "stone"
	register_block(stone)

	var grass := BlockType.new()
	grass.id = 3
	grass.block_name = "grass"
	grass.texture_top = TILE_GRASS_TOP
	grass.texture_side = TILE_GRASS_SIDE
	grass.texture_bottom = TILE_DIRT
	grass.is_transparent = false
	grass.is_solid = true
	grass.hardness = 0.6
	grass.drop_item = "dirt"
	register_block(grass)

	var wood := BlockType.new()
	wood.id = 4
	wood.block_name = "wood"
	wood.texture_top = TILE_WOOD_TOP
	wood.texture_side = TILE_WOOD_SIDE
	wood.texture_bottom = TILE_WOOD_TOP
	wood.is_transparent = false
	wood.is_solid = true
	wood.hardness = 2.0
	wood.drop_item = "wood"
	register_block(wood)

	var leaves := BlockType.new()
	leaves.id = 5
	leaves.block_name = "leaves"
	leaves.texture_top = TILE_LEAVES
	leaves.texture_side = TILE_LEAVES
	leaves.texture_bottom = TILE_LEAVES
	leaves.is_transparent = true
	leaves.is_solid = true
	leaves.hardness = 0.2
	leaves.drop_item = "leaves"
	register_block(leaves)

	var sand := BlockType.new()
	sand.id = 6
	sand.block_name = "sand"
	sand.texture_top = TILE_SAND
	sand.texture_side = TILE_SAND
	sand.texture_bottom = TILE_SAND
	sand.is_transparent = false
	sand.is_solid = true
	sand.hardness = 0.5
	sand.drop_item = "sand"
	register_block(sand)

	var planks := BlockType.new()
	planks.id = 7
	planks.block_name = "planks"
	planks.texture_top = TILE_PLANKS
	planks.texture_side = TILE_PLANKS
	planks.texture_bottom = TILE_PLANKS
	planks.is_transparent = false
	planks.is_solid = true
	planks.hardness = 2.0
	planks.drop_item = "planks"
	register_block(planks)

	var cobblestone := BlockType.new()
	cobblestone.id = 8
	cobblestone.block_name = "cobblestone"
	cobblestone.texture_top = TILE_COBBLESTONE
	cobblestone.texture_side = TILE_COBBLESTONE
	cobblestone.texture_bottom = TILE_COBBLESTONE
	cobblestone.is_transparent = false
	cobblestone.is_solid = true
	cobblestone.hardness = 2.0
	cobblestone.drop_item = "cobblestone"
	register_block(cobblestone)

func _build_atlas() -> void:
	var image: Image = TextureAtlasBuilder.build_atlas_image()
	TextureAtlasBuilder.paint_noisy_tile(image, TILE_DIRT, Color(0.42, 0.28, 0.16), 0.18)
	TextureAtlasBuilder.paint_noisy_tile(image, TILE_STONE, Color(0.5, 0.5, 0.52), 0.14)
	TextureAtlasBuilder.paint_noisy_tile(image, TILE_GRASS_TOP, Color(0.32, 0.58, 0.22), 0.18)
	TextureAtlasBuilder.paint_grass_side_tile(image, TILE_GRASS_SIDE, Color(0.32, 0.58, 0.22), Color(0.42, 0.28, 0.16), 0.18)
	TextureAtlasBuilder.paint_wood_rings_tile(image, TILE_WOOD_TOP, Color(0.55, 0.38, 0.2), Color(0.36, 0.24, 0.12))
	TextureAtlasBuilder.paint_wood_bark_tile(image, TILE_WOOD_SIDE, Color(0.4, 0.27, 0.14), 0.16)
	TextureAtlasBuilder.paint_noisy_tile(image, TILE_LEAVES, Color(0.18, 0.42, 0.14), 0.28)
	TextureAtlasBuilder.paint_noisy_tile(image, TILE_SAND, Color(0.82, 0.74, 0.5), 0.12)
	TextureAtlasBuilder.paint_noisy_tile(image, TILE_PLANKS, Color(0.68, 0.5, 0.28), 0.14)
	TextureAtlasBuilder.paint_noisy_tile(image, TILE_COBBLESTONE, Color(0.45, 0.45, 0.47), 0.22)
	atlas_texture = ImageTexture.create_from_image(image)

func _build_material() -> void:
	chunk_material = StandardMaterial3D.new()
	chunk_material.albedo_texture = atlas_texture
	chunk_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	chunk_material.roughness = 1.0
	chunk_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
