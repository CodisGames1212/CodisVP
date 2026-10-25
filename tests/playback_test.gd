extends SceneTree

var failures := 0
var player: VideoStreamPlayer
var capture: AudioEffectCapture


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	check(ClassDB.class_exists("VideoStreamCodisVP"), "Native class not registered")
	if failures:
		quit(1)
		return
	AudioServer.add_bus()
	var bus := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus, "CodisVPTest")
	capture = AudioEffectCapture.new()
	AudioServer.add_bus_effect(bus, capture)
	player = VideoStreamPlayer.new()
	player.bus = &"CodisVPTest"
	root.add_child(player)
	for extension in ["mp4", "webm", "mkv", "avi", "mov"]:
		var stream := load("res://tests/media/sample." + extension) as VideoStream
		check(stream != null, extension + ": resource loading")
		if not stream:
			continue
		stream.set("hardware_decoding", false)
		player.stream = stream
		capture.clear_buffer()
		player.play()
		await create_timer(0.35).timeout
		check(player.is_playing(), extension + ": playing")
		check(absf(player.get_stream_length() - 2.0) < 0.15, extension + ": duration")
		check(player.stream_position > 0.1, extension + ": clock advancement")
		var texture := player.get_video_texture()
		check(texture != null and texture.get_width() == 160, extension + ": texture size")
		if texture and DisplayServer.get_name() != "headless":
			var pixel := texture.get_image().get_pixel(80, 45)
			check(pixel.r > 0.7 and pixel.b < 0.2, extension + ": first red frame")
		var samples := capture.get_buffer(capture.get_frames_available())
		var peak := 0.0
		for sample in samples:
			peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
		check(peak > 0.01, extension + ": decoded audio reaches selected bus")
		player.paused = true
		var paused_at := player.stream_position
		await create_timer(0.15).timeout
		check(is_equal_approx(paused_at, player.stream_position), extension + ": pause")
		player.stream_position = 1.3
		player.paused = false
		await create_timer(0.15).timeout
		check(player.stream_position >= 1.3 and player.stream_position < 1.7, extension + ": seek")
		if texture and DisplayServer.get_name() != "headless":
			var pixel := texture.get_image().get_pixel(80, 45)
			check(pixel.b > 0.7 and pixel.r < 0.2, extension + ": sought blue frame")
		player.stream_position = 0.2
		await create_timer(0.15).timeout
		check(player.stream_position >= 0.2 and player.stream_position < 0.6, extension + ": backward seek")
		player.stream_position = 1.8
		await create_timer(0.4).timeout
		check(not player.is_playing(), extension + ": end of stream")
		player.play()
		await create_timer(0.15).timeout
		check(player.is_playing() and player.stream_position < 0.5, extension + ": replay")
		player.stop()
		check(not player.is_playing() and is_zero_approx(player.stream_position), extension + ": stop resets")
		print("Checked ", extension)
	var silent := load("res://tests/media/silent.mp4") as VideoStream
	player.stream = silent
	player.play()
	await create_timer(0.2).timeout
	check(player.is_playing() and player.stream_position > 0, "Silent video playback")
	player.stop()
	var accelerated := load("res://tests/media/hardware.mp4") as VideoStream
	player.stream = accelerated
	player.play()
	await create_timer(0.35).timeout
	check(player.is_playing(), "H.264 hardware-enabled playback")
	var playback: VideoStreamPlayback = accelerated.call("get_last_playback")
	check(playback != null, "Playback diagnostics available")
	if playback:
		print("H.264 decoder backend: ", playback.call("get_decoder_backend"))
		check(str(playback.call("get_last_error")).is_empty(), "Hardware decoder error")
	player.stream_position = 1.3
	await create_timer(0.15).timeout
	if DisplayServer.get_name() != "headless":
		var pixel := player.get_video_texture().get_image().get_pixel(80, 45)
		check(pixel.b > 0.7 and pixel.r < 0.2, "Hardware sought blue frame")
	player.stop()
	playback = null
	player.stream = null
	player.queue_free()
	await process_frame
	AudioServer.remove_bus(bus)
	print("CodisVP test failures: ", failures)
	quit(0 if failures == 0 else 1)
