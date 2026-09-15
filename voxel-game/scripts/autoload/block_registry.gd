extends Node
## Autoload singleton "BlockRegistry". Single source of truth for all block
## data and the shared texture atlas / material used by every chunk mesh.
## Game code must never branch on a raw block id — always go through here.

const AIR_ID := 0

const TILE_DIRT := 0
const TILE_STONE := 1
const TILE_GRASS_TOP := 2
const TILE_GRASS_SIDE := 3

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

func _build_atlas() -> void:
	var image: Image = TextureAtlasBuilder.build_atlas_image()
	TextureAtlasBuilder.paint_noisy_tile(image, TILE_DIRT, Color(0.42, 0.28, 0.16), 0.18)
	TextureAtlasBuilder.paint_noisy_tile(image, TILE_STONE, Color(0.5, 0.5, 0.52), 0.14)
	TextureAtlasBuilder.paint_noisy_tile(image, TILE_GRASS_TOP, Color(0.32, 0.58, 0.22), 0.18)
	TextureAtlasBuilder.paint_grass_side_tile(image, TILE_GRASS_SIDE, Color(0.32, 0.58, 0.22), Color(0.42, 0.28, 0.16), 0.18)
	atlas_texture = ImageTexture.create_from_image(image)

func _build_material() -> void:
	chunk_material = StandardMaterial3D.new()
	chunk_material.albedo_texture = atlas_texture
	chunk_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	chunk_material.roughness = 1.0
	chunk_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
