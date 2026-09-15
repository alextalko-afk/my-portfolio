class_name ProceduralSound
extends RefCounted
## Generates short WAV clips entirely in code (noise bursts and simple tone
## blips with a decay envelope) — a lightweight stand-in for real sound
## assets, which this project doesn't have any of.

const SAMPLE_RATE := 22050

static func _make_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v: int = clampi(int(samples[i] * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, v)
	stream.data = data
	return stream

## Filtered noise burst with a decaying envelope — footsteps, digging,
## block placement all come from this with different smoothing/duration.
static func noise_burst(duration: float, seed_value: int, smoothing: float = 0.3, volume: float = 0.5) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var count: int = maxi(1, int(SAMPLE_RATE * duration))
	var samples := PackedFloat32Array()
	samples.resize(count)
	var prev: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(count)
		var envelope: float = pow(1.0 - t, 2.0)
		var raw: float = rng.randf_range(-1.0, 1.0)
		prev = lerpf(prev, raw, smoothing)
		samples[i] = prev * envelope * volume
	return _make_stream(samples)

## Short tone with a decaying envelope — used for attack/hurt blips where a
## noise burst would sound too much like a footstep.
static func tone_blip(duration: float, frequency: float, volume: float = 0.4) -> AudioStreamWAV:
	var count: int = maxi(1, int(SAMPLE_RATE * duration))
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var envelope: float = pow(1.0 - float(i) / float(count), 1.5)
		var phase: float = fmod(t * frequency, 1.0)
		var v: float = 1.0 if phase < 0.5 else -1.0
		samples[i] = v * envelope * volume
	return _make_stream(samples)
