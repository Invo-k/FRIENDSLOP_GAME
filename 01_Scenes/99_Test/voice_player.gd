extends AudioStreamPlayer3D

var _playback: AudioStreamGeneratorPlayback

func _ready() -> void:
	if is_multiplayer_authority():
		# Es MI personaje: envío mi voz, no la reproduzco
		VoiceCapture.frame_ready.connect(_on_local_frame)
	else:
		# Es el personaje de otro: reproduzco lo que me llega
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = VoiceCapture.VOICE_RATE
		gen.buffer_length = 0.3
		stream = gen
		play()
		_playback = get_stream_playback() as AudioStreamGeneratorPlayback

func _on_local_frame(bytes: PackedByteArray) -> void:
	if multiplayer.get_peers().is_empty():
		return
	receive_voice.rpc(bytes)

@rpc("authority", "call_remote", "unreliable")
func receive_voice(data: PackedByteArray) -> void:
	if _playback == null:
		return
	var count := data.size() / 2
	if _playback.get_frames_available() < count:
		return   # buffer lleno: descartamos para no acumular retraso
	var frames := PackedVector2Array()
	frames.resize(count)
	for i in count:
		var s := data.decode_s16(i * 2) / 32768.0
		frames[i] = Vector2(s, s)
	_playback.push_buffer(frames)
