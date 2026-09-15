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
