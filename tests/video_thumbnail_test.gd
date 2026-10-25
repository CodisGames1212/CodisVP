extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not ClassDB.class_exists("VideoStreamCodisVP"):
		push_error("CodisVP extension is not loaded")
		quit(1)
		return
	var thumbnail: Texture2D = await VideoThumbnail.extract("res://tests/media/sample.mp4")
	if thumbnail == null:
		push_error("Thumbnail extraction failed")
		quit(1)
		return
	print("Thumbnail size: ", thumbnail.get_size())
	print("Thumbnail pixel: ", thumbnail.get_image().get_pixel(160, 90))
	quit(0)
