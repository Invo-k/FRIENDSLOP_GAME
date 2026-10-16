extends Control

@onready var input_option: OptionButton = %InputOption
@onready var output_option: OptionButton = %OutputOption
@onready var level_bar: ProgressBar = %MicLevel
@onready var mute_mic: CheckButton = %MuteMic
@onready var status_label: Label = %MicStatus
@onready var server_id_text: Label = %SERVER_ID_TEXT


func _ready() -> void:
	AudioDevices.devices_changed.connect(_refresh)
	input_option.item_selected.connect(func(i): AudioDevices.set_input(input_option.get_item_text(i)))
	output_option.item_selected.connect(func(i): AudioDevices.set_output(output_option.get_item_text(i)))
	mute_mic.toggled.connect(func(on): VoiceCapture.enabled = not on)
	_refresh()
	
	if SteamManager.lobby_id == 0:
		server_id_text.hide()

func _refresh() -> void:
	_fill(input_option, AudioDevices.get_input_devices(), AudioServer.input_device)
	_fill(output_option, AudioDevices.get_output_devices(), AudioServer.output_device)

func _fill(opt: OptionButton, list: PackedStringArray, current: String) -> void:
	opt.clear()
	for d in list:
		opt.add_item(d)
		if d == current:
			opt.select(opt.item_count - 1)

func _process(_delta: float) -> void:
	level_bar.value = VoiceCapture.level
	if not VoiceCapture.enabled:
		status_label.text = "Micrófono silenciado"
	elif VoiceCapture.mic_active:
		status_label.text = "Micrófono: recibiendo audio"
	else:
		status_label.text = "Micrófono: sin señal del dispositivo"


func _on_exit_pressed() -> void:
	if !GlobalData.is_on_menu:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	queue_free()


func _on_copy_button_pressed() -> void:
	DisplayServer.clipboard_set(str(SteamManager.lobby_id))
