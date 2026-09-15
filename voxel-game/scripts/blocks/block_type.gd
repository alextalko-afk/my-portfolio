class_name BlockType
extends Resource
## Data definition for a single block type. Blocks are never hardcoded by id
## in game logic — everything queries BlockRegistry for this data instead.

@export var id: int = 0
@export var block_name: String = ""
@export var texture_top: int = 0
@export var texture_side: int = 0
@export var texture_bottom: int = 0
@export var is_transparent: bool = false
@export var is_solid: bool = true
@export var hardness: float = 1.0
@export var drop_item: String = ""
## False for inventory-only items (sticks, tools) that exist for crafting
## but were never meant to be placed as a world voxel.
@export var is_placeable: bool = true
## True only for water: its faces go into the chunk's separate alpha-
## blended surface/material instead of the shared opaque one, so it's
## actually see-through rather than merely face-culled like leaves.
@export var render_transparent: bool = false
