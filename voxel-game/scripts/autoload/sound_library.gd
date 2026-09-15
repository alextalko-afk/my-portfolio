extends Node
## Autoload singleton "SoundLibrary". Generates every game sound once at
## startup (see ProceduralSound) and hands out the same cached
## AudioStreamWAV to every caller instead of regenerating per play.

var footstep: AudioStreamWAV
var block_break: AudioStreamWAV
var block_place: AudioStreamWAV
var mob_attack: AudioStreamWAV
var player_hurt: AudioStreamWAV

func _ready() -> void:
	footstep = ProceduralSound.noise_burst(0.09, 1, 0.5, 0.35)
	block_break = ProceduralSound.noise_burst(0.18, 2, 0.15, 0.55)
	block_place = ProceduralSound.noise_burst(0.12, 3, 0.6, 0.45)
	mob_attack = ProceduralSound.tone_blip(0.16, 110.0, 0.45)
	player_hurt = ProceduralSound.tone_blip(0.2, 180.0, 0.4)
