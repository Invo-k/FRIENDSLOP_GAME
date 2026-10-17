extends Node

signal devices_changed
signal input_changing
signal input_changed
signal output_changed

const SAVE_PATH := "user://audio_settings.cfg"

var preferred_input := "Default"
var preferred_output := "Default"

var _inputs := PackedStringArray()
var _outputs := PackedStringArray()
var _switch_id := 0

const HIDDEN_DEVICES := ["steam streaming"]

func get_input_devices() -> PackedStringArray:
	return _filter(AudioServer.get_input_device_list())

func get_output_devices() -> PackedStringArray:
	return _filter(AudioServer.get_output_device_list())

func _filter(list: PackedStringArray) -> PackedStringArray:
	var result := PackedStringArray()
	for d in list:
		var lower := d.to_lower()
		var hidden := false
		for h in HIDDEN_DEVICES:
			if lower.contains(h):
				hidden = true
				break
		if not hidden and d not in result:
			result.append(d)
	return result

func _ready() -> void:
	_load()
	_inputs = get_input_devices()
	_outputs = get_output_devices()
	#Al arrancar aún no hay micro activo, así que se puede asignar directamente
	if preferred_input != "Default" and preferred_input in _inputs:
		AudioServer.input_device = preferred_input
	if preferred_output != "Default" and preferred_output in _outputs:
		AudioServer.output_device = preferred_output

	var timer := Timer.new()
	timer.wait_time = 2.0
	timer.timeout.connect(_poll)
	add_child(timer)
	timer.start()

## Lo llama el menú cuando el jugador elige un micrófono
func set_input(device: String) -> void:
	preferred_input = device
	_save()
	_switch_input(device)

## Lo llama el menú cuando el jugador elige una salida
func set_output(device: String) -> void:
	preferred_output = device
	_save()
	AudioServer.output_device = device if device in get_output_devices() else "Default"
	output_changed.emit()

func _switch_input(device: String) -> void:
	var target := device if device in get_input_devices() else "Default"
	if target == AudioServer.input_device:
		return
	_switch_id += 1
	var id := _switch_id
	input_changing.emit()
	AudioServer.input_device = target
	await get_tree().create_timer(0.3).timeout
	if id != _switch_id:
		return
	input_changed.emit()

func _poll() -> void:
	var i := get_input_devices()
	var o := get_output_devices()
	if i == _inputs and o == _outputs:
		return
	_inputs = i
	_outputs = o

	# Si el preferido se desconectó -> Default. Si vuelve a conectarse -> se restaura.
	var wanted_in := preferred_input if preferred_input in i else "Default"
	if AudioServer.input_device != wanted_in:
		_switch_input(wanted_in)
	var wanted_out := preferred_output if preferred_output in o else "Default"
	if AudioServer.output_device != wanted_out:
		AudioServer.output_device = wanted_out
		output_changed.emit()

	devices_changed.emit()

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		preferred_input = cfg.get_value("audio", "input", "Default")
		preferred_output = cfg.get_value("audio", "output", "Default")
	else:
		# Primera ejecución: seguir los dispositivos predeterminados de Windows
		preferred_input = "Default"
		preferred_output = "Default"

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "input", preferred_input)
	cfg.set_value("audio", "output", preferred_output)
	cfg.save(SAVE_PATH)
