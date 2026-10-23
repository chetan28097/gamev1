extends Node
## Plays every sound in the game. Samples come from Kenney's CC0 packs; the
## sonar ping, heartbeat, drips and the ambient drone are synthesized here at
## startup so they can be tuned in code (and need no extra downloads).
##
## Buses: Master <- SFX (cave reverb), Enemy (cave reverb), Ambience, UI.

const SFX := "res://assets/sfx/"
const BANK := {
	"step": ["impact-sounds/footstep_concrete_000.ogg", "impact-sounds/footstep_concrete_001.ogg", "impact-sounds/footstep_concrete_002.ogg", "impact-sounds/footstep_concrete_003.ogg", "impact-sounds/footstep_concrete_004.ogg"],
	"rock": ["impact-sounds/impactMining_000.ogg", "impact-sounds/impactMining_001.ogg", "impact-sounds/impactMining_002.ogg", "impact-sounds/impactMining_003.ogg"],
	"throw": ["interface-sounds/drop_001.ogg", "interface-sounds/drop_002.ogg"],
	"pickup": ["impact-sounds/impactPlate_light_000.ogg", "impact-sounds/impactPlate_light_001.ogg"],
	"empty": ["interface-sounds/error_004.ogg"],
	"deep_layer": ["sci-fi-sounds/lowFrequency_explosion_000.ogg", "sci-fi-sounds/lowFrequency_explosion_001.ogg"],
	"stalker_growl": ["sci-fi-sounds/slime_000.ogg", "sci-fi-sounds/slime_001.ogg"],
	"stalker_alert": ["sci-fi-sounds/laserLarge_000.ogg", "sci-fi-sounds/laserLarge_002.ogg"],
	"stalker_step": ["impact-sounds/impactSoft_heavy_000.ogg", "impact-sounds/impactSoft_heavy_001.ogg", "impact-sounds/impactSoft_heavy_002.ogg", "impact-sounds/impactSoft_heavy_003.ogg"],
	"death": ["sci-fi-sounds/explosionCrunch_000.ogg", "sci-fi-sounds/explosionCrunch_002.ogg"],
	"glitch": ["interface-sounds/glitch_001.ogg", "interface-sounds/glitch_002.ogg", "interface-sounds/glitch_003.ogg"],
	"radio": ["digital-audio/twoTone1.ogg"],
	"type": ["interface-sounds/tick_001.ogg", "interface-sounds/tick_002.ogg"],
	"clear": ["digital-audio/threeTone1.ogg"],
	"ui_move": ["interface-sounds/select_001.ogg"],
	"ui_ok": ["interface-sounds/confirmation_001.ogg"],
	"ui_back": ["interface-sounds/back_001.ogg"],
	"exit_hum": ["sci-fi-sounds/spaceEngineLow_000.ogg"],
}
## Default (volume_db, bus) per sound; play() arguments are added on top.
const MIX := {
	"step": [-12.0, "SFX"], "rock": [-2.0, "SFX"], "throw": [-14.0, "SFX"], "pickup": [-6.0, "SFX"],
	"empty": [-10.0, "UI"], "ping": [-6.0, "SFX"], "deep": [-3.0, "SFX"], "deep_layer": [-14.0, "SFX"],
	"stalker_growl": [-4.0, "Enemy"], "stalker_alert": [-6.0, "Enemy"], "stalker_step": [-6.0, "Enemy"],
	"death": [-2.0, "SFX"], "glitch": [-8.0, "UI"], "radio": [-12.0, "UI"], "type": [-22.0, "UI"],
	"clear": [-6.0, "UI"], "ui_move": [-14.0, "UI"], "ui_ok": [-10.0, "UI"], "ui_back": [-12.0, "UI"],
	"heartbeat": [-6.0, "SFX"], "drip": [-16.0, "Ambience"],
}

var _streams := {}  # name -> Array[AudioStream]
var _pool2d: Array[AudioStreamPlayer2D] = []
var _pool: Array[AudioStreamPlayer] = []
var _next2d := 0
var _next := 0
var _drone: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for key in BANK:
		var list: Array[AudioStream] = []
		for f in BANK[key]:
			list.append(load(SFX + f))
		_streams[key] = list
	_streams["ping"] = [_synth_ping(1700.0, 600.0, 0.9, 6.5)]
	_streams["deep"] = [_synth_ping(420.0, 85.0, 1.9, 2.4)]
	_streams["heartbeat"] = [_synth_heartbeat()]
	_streams["drip"] = [_synth_drip()]
	_streams["drone"] = [_synth_drone()]
	for i in 24:
		var p := AudioStreamPlayer2D.new()
		p.max_distance = 1100.0
		p.attenuation = 1.6
		add_child(p)
		_pool2d.append(p)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_drone = AudioStreamPlayer.new()
	_drone.stream = _streams["drone"][0]
	_drone.bus = &"Ambience"
	_drone.volume_db = -15.0
	add_child(_drone)


## Plays a named sound. Pass a world position for positional (2D) audio.
func play(sound: String, at: Variant = null, volume_db := 0.0, pitch := 1.0) -> void:
	var list: Array = _streams.get(sound, [])
	if list.is_empty():
		push_warning("Audio: unknown sound '%s'" % sound)
		return
	var mix: Array = MIX.get(sound, [0.0, "SFX"])
	var stream: AudioStream = list[randi() % list.size()]
	var jitter := randf_range(0.96, 1.04)
	if at is Vector2:
		var p := _pool2d[_next2d]
		_next2d = (_next2d + 1) % _pool2d.size()
		p.global_position = at
		_start(p, stream, mix, volume_db, pitch * jitter)
	else:
		var p := _pool[_next]
		_next = (_next + 1) % _pool.size()
		_start(p, stream, mix, volume_db, pitch * jitter)


func stream(sound: String) -> AudioStream:
	var list: Array = _streams.get(sound, [])
	return list[0] if not list.is_empty() else null


func _exit_tree() -> void:
	_drone.stop()
	for p in _pool2d:
		p.stop()
	for p in _pool:
		p.stop()


func start_ambience() -> void:
	if not _drone.playing:
		_drone.play()


func stop_ambience() -> void:
	_drone.stop()


func _start(p: Node, s: AudioStream, mix: Array, volume_db: float, pitch: float) -> void:
	p.stream = s
	p.bus = StringName(mix[1])
	p.volume_db = mix[0] + volume_db
	p.pitch_scale = pitch
	p.play()


func _setup_buses() -> void:
	for bus in ["SFX", "Enemy", "Ambience", "UI"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, &"Master")
	# A flooded concrete station: long, damp reverb on world sounds.
	for bus in ["SFX", "Enemy"]:
		var i := AudioServer.get_bus_index(bus)
		if AudioServer.get_bus_effect_count(i) == 0:
			var rv := AudioEffectReverb.new()
			rv.room_size = 0.78
			rv.damping = 0.45
			rv.spread = 0.8
			rv.wet = 0.24
			rv.dry = 1.0
			AudioServer.add_bus_effect(i, rv)


# ---------------------------------------------------------------------------
# Synthesis

const RATE := 22050


func _to_wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


## Sonar ping: a falling sine sweep with two quieter "returns" baked in.
func _synth_ping(f_hi: float, f_lo: float, dur: float, decay: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var dry := PackedFloat32Array()
	dry.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := f_lo + (f_hi - f_lo) * exp(-t * 7.0)
		phase += TAU * f / RATE
		var env := minf(t / 0.004, 1.0) * exp(-t * decay)
		dry[i] = sin(phase) * env * 0.8 + sin(phase * 2.01) * env * 0.12
	var out := dry.duplicate()
	for tap in [[0.11, 0.32], [0.26, 0.16], [0.43, 0.07]]:
		var off := int(tap[0] * RATE)
		for i in range(off, n):
			out[i] += dry[i - off] * tap[1]
	return _to_wav(out)


func _synth_heartbeat() -> AudioStreamWAV:
	var n := int(0.55 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for beat in [[0.0, 1.0], [0.17, 0.7]]:
		var off := int(beat[0] * RATE)
		var phase := 0.0
		for i in range(off, n):
			var t := float(i - off) / RATE
			phase += TAU * lerpf(62.0, 38.0, minf(t * 8.0, 1.0)) / RATE
			out[i] += sin(phase) * exp(-t * 16.0) * beat[1] * 0.9
	return _to_wav(out)


func _synth_drip() -> AudioStreamWAV:
	var n := int(0.35 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += TAU * (700.0 + 1500.0 * minf(t / 0.03, 1.0)) / RATE
		out[i] = sin(phase) * exp(-t * 28.0) * 0.7
	return _to_wav(out)


## A seamless 8 s loop: low detuned hum, slow swell, and damp brown noise.
func _synth_drone() -> AudioStreamWAV:
	var dur := 8.0
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	# Whole-number cycles per loop so the seam is silent.
	var freqs := [[55.0, 0.30], [55.375, 0.22], [82.5, 0.12], [110.125, 0.05]]
	var brown := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# Generate a little extra noise and crossfade it into the start, so the
	# sample after the loop's last one continues smoothly.
	var xfade := int(0.5 * RATE)
	var noise := PackedFloat32Array()
	noise.resize(n + xfade)
	for i in n + xfade:
		brown = clampf(brown * 0.995 + rng.randf_range(-1.0, 1.0) * 0.02, -1.0, 1.0)
		noise[i] = brown
	for i in xfade:
		var k := float(i) / xfade
		noise[i] = noise[i] * k + noise[n + i] * (1.0 - k)
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		for f in freqs:
			s += sin(TAU * f[0] * t) * f[1]
		var swell := 0.75 + 0.25 * sin(TAU * t / dur)
		out[i] = s * swell * 0.6 + noise[i] * 0.5
	return _to_wav(out, true)
