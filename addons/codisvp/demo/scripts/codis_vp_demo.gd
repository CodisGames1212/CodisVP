extends Control


var player: VideoStreamPlayer
var status: Label
var timeline: HSlider
var timeline_dragging: bool = false
var time_label: Label
var dialog: FileDialog
var pause_button: Button
var hardware: CheckBox


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 20)
	add_child(margin)
	var layout := VBoxContainer.new()
	margin.add_child(layout)
	var title := Label.new()
	title.text = "CodisVP · FFmpeg video player"
	title.add_theme_font_size_override("font_size", 26)
	layout.add_child(title)
	var bar := HBoxContainer.new()
	layout.add_child(bar)
	var open_button := Button.new()
	open_button.text = "Open video"
	open_button.pressed.connect(func(): dialog.popup_centered_ratio(0.75))
	bar.add_child(open_button)
	pause_button = Button.new()
	pause_button.text = "Pause"
	pause_button.pressed.connect(func():
		if player.stream:
			if not player.is_playing():
				player.play()
				player.paused = false
			else:
				player.paused = not player.paused
			pause_button.text = "Resume" if player.paused else "Pause")
	bar.add_child(pause_button)
	var stop_button := Button.new()
	stop_button.text = "Stop"
	stop_button.pressed.connect(func(): player.stop())
	bar.add_child(stop_button)
	hardware = CheckBox.new()
	hardware.text = "Try hardware decoding"
	hardware.button_pressed = true
	bar.add_child(hardware)
	var bus_picker := OptionButton.new()
	for index in AudioServer.bus_count:
		bus_picker.add_item(AudioServer.get_bus_name(index))
	bus_picker.item_selected.connect(func(index: int): player.bus = bus_picker.get_item_text(index))
	bar.add_child(bus_picker)
	player = VideoStreamPlayer.new()
	player.expand = true
	player.size_flags_vertical = Control.SIZE_EXPAND_FILL
	player.custom_minimum_size = Vector2(320, 180)
	player.finished.connect(func(): status.text = "Playback finished")
	layout.add_child(player)
	timeline = HSlider.new()
	timeline.step = 0.01
	timeline.drag_started.connect(func(): timeline_dragging = true)
	timeline.drag_ended.connect(func(changed: bool):
		timeline_dragging = false
		if changed and player.stream:
			player.stream_position = timeline.value)
	layout.add_child(timeline)
	time_label = Label.new()
	layout.add_child(time_label)
	status = Label.new()
	status.text = "Choose an MP4, WebM, MKV, AVI, MOV, or another FFmpeg video."
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(status)
	dialog = FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.mp4,*.webm,*.mkv,*.avi,*.mov,*.m4v,*.mpg,*.mpeg,*.ts,*.flv,*.wmv ; Videos", "* ; All files"])
	dialog.file_selected.connect(_open_video)
	add_child(dialog)
	if not ClassDB.class_exists("VideoStreamCodisVP"):
		status.text = "Native extension unavailable. See README.md for build instructions."
		open_button.disabled = true


func _open_video(path: String) -> void:
	player.stop()
	var stream := ClassDB.instantiate("VideoStreamCodisVP") as VideoStream
	stream.file = path
	stream.set("hardware_decoding", hardware.button_pressed)
	player.stream = stream
	player.paused = false
	pause_button.text = "Pause"
	player.play()
	status.text = path.get_file() if player.is_playing() else "Could not play this file. Check the Output panel."


func _process(_delta: float) -> void:
	if not player or not player.stream:
		return
	var length := player.get_stream_length()
	timeline.max_value = maxf(length, 0.01)
	if not timeline_dragging:
		timeline.set_value_no_signal(player.stream_position)
	time_label.text = "%.2f / %.2f seconds · Audio bus: %s" % [player.stream_position, length, player.bus]
	var playback: VideoStreamPlayback = player.stream.call("get_last_playback")
	if playback:
		time_label.text += " · Decoder: " + str(playback.call("get_decoder_backend"))
		var error := str(playback.call("get_last_error"))
		if not error.is_empty():
			status.text = error
