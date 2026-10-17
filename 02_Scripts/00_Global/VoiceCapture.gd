extends Node

signal frame_ready(bytes: PackedByteArray)

const VOICE_RATE := 16000
const FRAME_SAMPLES := 320        # 20 ms a 16 kHz
const HOLD_TIME := 0.4
const MAX_RETRIES := 3

var enabled := true               # false = micrófono silenciado
var threshold := 0.015
var level := 0.0                  # nivel actual (medidor del menú)
var mic_active := false           # true si el dispositivo está entregando audio

var _capture: AudioEffectCapture
var _mic_player: AudioStreamPlayer
var _src := PackedFloat32Array()
var _out := PackedFloat32Array()
var _pos := 0.0
var _hold := 0.0
var _no_data_time := 0.0
var _retries := 0
var _restarting := false
var _gen := 0                     # invalida reinicios pendientes si cambia el dispositivo

func _ready() -> void:
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, "Mic")
	AudioServer.set_bus_mute(idx, true)
	_capture = AudioEffectCapture.new()
	AudioServer.add_bus_effect(idx, _capture)

	_mic_player = AudioStreamPlayer.new()
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = "Mic"
	add_child(_mic_player)

	AudioDevices.input_changing.connect(_on_input_changing)
	AudioDevices.input_changed.connect(_start_mic)
	await get_tree().create_timer(0.5).timeout
	_start_mic()

func _on_input_changing() -> void:
	_gen += 1
	_restarting = false
	_mic_player.stop()
	_reset_buffers()
	_retries = 0
	_no_data_time = 0.0
	mic_active = false
	level = 0.0

func _start_mic() -> void:
	if not _mic_player.playing:
		_mic_player.play()
	_capture.clear_buffer()

func _restart_mic() -> void:
	if _restarting:
		return
	_restarting = true
	var gen := _gen
	_mic_player.stop()
	await get_tree().create_timer(0.3).timeout
	if gen != _gen:
		return              # cambió el dispositivo; AudioDevices se encarga
	_reset_buffers()
	_start_mic()
	_restarting = false

func _reset_buffers() -> void:
	_src.clear()
	_out.clear()
	_pos = 0.0
	_hold = 0.0

func _process(delta: float) -> void:
	var n := _capture.get_frames_available()
	if n > 0:
		_no_data_time = 0.0
		_retries = 0
		mic_active = true
		for v in _capture.get_buffer(n):
			_src.append((v.x + v.y) * 0.5)
		_resample()
	elif _mic_player.playing:
		_no_data_time += delta
		if _no_data_time > 1.0:
			mic_active = false
			level = 0.0
			_no_data_time = 0.0
			if _retries < MAX_RETRIES:
				_retries += 1
				_restart_mic()

	while _out.size() >= FRAME_SAMPLES:
		var frame := _out.slice(0, FRAME_SAMPLES)
		_out = _out.slice(FRAME_SAMPLES)
		_handle_frame(frame)

func _resample() -> void:
	var ratio := AudioServer.get_mix_rate() / float(VOICE_RATE)
	while int(_pos) + 1 < _src.size():
		var i := int(_pos)
		_out.append(lerpf(_src[i], _src[i + 1], _pos - i))
		_pos += ratio
	var consumed := int(_pos)
	_src = _src.slice(consumed)
	_pos -= consumed

func _handle_frame(frame: PackedFloat32Array) -> void:
	var sum := 0.0
	for s in frame:
		sum += s * s
	var rms := sqrt(sum / frame.size())
	level = rms if enabled else 0.0

	if not enabled:
		_hold = 0.0
		return
	if rms > threshold:
		_hold = HOLD_TIME
	else:
		_hold -= FRAME_SAMPLES / float(VOICE_RATE)
	if _hold <= 0.0:
		return

	var bytes := PackedByteArray()
	bytes.resize(FRAME_SAMPLES * 2)
	for i in FRAME_SAMPLES:
		bytes.encode_s16(i * 2, int(clampf(frame[i], -1.0, 1.0) * 32767.0))
	frame_ready.emit(bytes)
