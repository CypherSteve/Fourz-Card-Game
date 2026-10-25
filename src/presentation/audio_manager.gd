class_name AudioManager
extends Node

## AudioManager: Synthesizes and plays procedural audio effects for Fours.
## 100% self-contained with zero external audio file dependencies.

var is_muted: bool = false

var _stream_card_snap: AudioStreamWAV
var _stream_card_slide: AudioStreamWAV
var _stream_burn_boom: AudioStreamWAV
var _stream_pickup: AudioStreamWAV
var _stream_click: AudioStreamWAV
var _stream_victory: AudioStreamWAV
var _stream_defeat: AudioStreamWAV

var _players: Array[AudioStreamPlayer] = []
var _player_index: int = 0
const POOL_SIZE: int = 6

func _init() -> void:
	_generate_sound_effects()

func _ready() -> void:
	# Create pool of AudioStreamPlayers for polyphonic sound
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)

func _play_stream(stream: AudioStreamWAV, volume_db: float = 0.0) -> void:
	if is_muted or stream == null or _players.is_empty():
		return
	var player: AudioStreamPlayer = _players[_player_index]
	_player_index = (_player_index + 1) % POOL_SIZE
	player.stream = stream
	player.volume_db = volume_db
	player.play()

# Public Sound Triggers
func play_card_snap() -> void:
	_play_stream(_stream_card_snap, -2.0)

func play_card_slide() -> void:
	_play_stream(_stream_card_slide, -4.0)

func play_burn_boom() -> void:
	_play_stream(_stream_burn_boom, 2.0)

func play_pickup() -> void:
	_play_stream(_stream_pickup, -3.0)

func play_click() -> void:
	_play_stream(_stream_click, -6.0)

func play_victory() -> void:
	_play_stream(_stream_victory, 0.0)

func play_defeat() -> void:
	_play_stream(_stream_defeat, 0.0)

# ==========================================
# PROCEDURAL SOUND SYNTHESIS
# ==========================================

func _generate_sound_effects() -> void:
	_stream_card_snap = _synth_card_snap()
	_stream_card_slide = _synth_card_slide()
	_stream_burn_boom = _synth_burn_boom()
	_stream_pickup = _synth_pickup()
	_stream_click = _synth_click()
	_stream_victory = _synth_victory()
	_stream_defeat = _synth_defeat()

## Snappy card snap (felt slap impact)
func _synth_card_snap() -> AudioStreamWAV:
	var rate: int = 22050
	var duration: float = 0.05
	var total_samples: int = int(rate * duration)
	var bytes := PackedByteArray()
	
	for i in range(total_samples):
		var t: float = float(i) / float(total_samples)
		var env: float = exp(-t * 28.0) # Sharp exponential decay
		var pop: float = sin(float(i) * 0.15) * 0.4
		var noise: float = (randf() * 2.0 - 1.0) * 0.6
		var sample: float = (pop + noise) * env
		_append_sample(bytes, sample)
	
	return _create_wav(bytes, rate)

## Card slide / deal swoosh
func _synth_card_slide() -> AudioStreamWAV:
	var rate: int = 22050
	var duration: float = 0.09
	var total_samples: int = int(rate * duration)
	var bytes := PackedByteArray()
	
	for i in range(total_samples):
		var t: float = float(i) / float(total_samples)
		# Arc envelope: swell and fade
		var env: float = sin(t * PI)
		var noise: float = (randf() * 2.0 - 1.0) * 0.5
		var sample: float = noise * env
		_append_sample(bytes, sample)
	
	return _create_wav(bytes, rate)

## Dramatic burn explosion / bass drop
func _synth_burn_boom() -> AudioStreamWAV:
	var rate: int = 22050
	var duration: float = 0.45
	var total_samples: int = int(rate * duration)
	var bytes := PackedByteArray()
	
	for i in range(total_samples):
		var t: float = float(i) / float(total_samples)
		var env: float = exp(-t * 6.5)
		# Descending bass sweep from 140Hz down to 40Hz
		var freq: float = 140.0 - (t * 100.0)
		var phase: float = float(i) * freq * (2.0 * PI / float(rate))
		var bass: float = sin(phase) * 0.7
		# Subtle sizzle noise in initial impact
		var sizzle: float = (randf() * 2.0 - 1.0) * exp(-t * 22.0) * 0.4
		var sample: float = (bass + sizzle) * env
		_append_sample(bytes, sample)
	
	return _create_wav(bytes, rate)

## Multi-card pickup rustle
func _synth_pickup() -> AudioStreamWAV:
	var rate: int = 22050
	var duration: float = 0.18
	var total_samples: int = int(rate * duration)
	var bytes := PackedByteArray()
	
	for i in range(total_samples):
		var t: float = float(i) / float(total_samples)
		# Two overlapping sliding waves
		var env: float = sin(t * PI * 2.0) * exp(-t * 4.0)
		var noise: float = (randf() * 2.0 - 1.0) * 0.45
		var sample: float = noise * abs(env)
		_append_sample(bytes, sample)
	
	return _create_wav(bytes, rate)

## UI click
func _synth_click() -> AudioStreamWAV:
	var rate: int = 22050
	var duration: float = 0.02
	var total_samples: int = int(rate * duration)
	var bytes := PackedByteArray()
	
	for i in range(total_samples):
		var t: float = float(i) / float(total_samples)
		var env: float = exp(-t * 40.0)
		var tone: float = sin(float(i) * 0.3)
		var sample: float = tone * env * 0.6
		_append_sample(bytes, sample)
	
	return _create_wav(bytes, rate)

## Victory fanfare arpeggio (C5 - E5 - G5 - C6)
func _synth_victory() -> AudioStreamWAV:
	var rate: int = 22050
	var notes: Array[float] = [523.25, 659.25, 783.99, 1046.50]
	var note_duration: float = 0.14
	var total_samples: int = int(rate * note_duration * notes.size())
	var bytes := PackedByteArray()
	
	for idx in range(notes.size()):
		var freq: float = notes[idx]
		var note_samples: int = int(rate * note_duration)
		for i in range(note_samples):
			var t: float = float(i) / float(note_samples)
			var env: float = exp(-t * 5.0)
			var phase: float = float(i) * freq * (2.0 * PI / float(rate))
			# Warm flute/chime tone: fundamental + subtle 2nd harmonic
			var tone: float = sin(phase) * 0.6 + sin(phase * 2.0) * 0.2
			_append_sample(bytes, tone * env)
	
	return _create_wav(bytes, rate)

## Defeat melancholy descending tone
func _synth_defeat() -> AudioStreamWAV:
	var rate: int = 22050
	var notes: Array[float] = [440.0, 415.3, 392.0, 349.23] # A - G# - G - F
	var note_duration: float = 0.18
	var bytes := PackedByteArray()
	
	for idx in range(notes.size()):
		var freq: float = notes[idx]
		var note_samples: int = int(rate * note_duration)
		for i in range(note_samples):
			var t: float = float(i) / float(note_samples)
			var env: float = exp(-t * 4.5)
			var phase: float = float(i) * freq * (2.0 * PI / float(rate))
			var tone: float = sin(phase) * 0.55 + sin(phase * 0.5) * 0.25
			_append_sample(bytes, tone * env)
	
	return _create_wav(bytes, rate)

func _append_sample(bytes: PackedByteArray, val_float: float) -> void:
	var s: int = clampi(int(val_float * 32767.0), -32768, 32767)
	bytes.append(s & 0xFF)
	bytes.append((s >> 8) & 0xFF)

func _create_wav(data: PackedByteArray, mix_rate: int) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = data
	return wav
