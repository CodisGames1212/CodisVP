class_name VideoThumbnail
extends RefCounted

const THUMBNAIL_SIZE: Vector2i = Vector2i(320, 180)


static func extract(path: String) -> Texture2D:
	if not ClassDB.class_exists("VideoStreamCodisVP") or not FileAccess.file_exists(path):
		return null
	var stream: VideoStream = ClassDB.instantiate("VideoStreamCodisVP") as VideoStream
	if stream == null:
		return null
	stream.file = path
	stream.set("hardware_decoding", false)
	var main_loop: SceneTree = Engine.get_main_loop() as SceneTree
	if main_loop == null or main_loop.root == null:
		return null
	var viewport: SubViewport = SubViewport.new()
	viewport.size = THUMBNAIL_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var player: VideoStreamPlayer = VideoStreamPlayer.new()
	player.expand = true
	player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(player)
	main_loop.root.add_child(viewport)
	player.stream = stream
	await Engine.get_main_loop().process_frame
	player.play()
	var deadline_msec: int = Time.get_ticks_msec() + 1800
	var texture: Texture2D = null
	while Time.get_ticks_msec() < deadline_msec:
		await Engine.get_main_loop().process_frame
		if player.get_video_texture() != null and player.is_playing():
			texture = player.get_video_texture()
			if texture.get_width() > 0 and texture.get_height() > 0:
				break
	if texture == null or texture.get_width() == 0 or texture.get_height() == 0:
		player.stop()
		viewport.queue_free()
		return null
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		player.stop()
		viewport.queue_free()
		return null
	var target_ratio: float = float(THUMBNAIL_SIZE.x) / float(THUMBNAIL_SIZE.y)
	var source_ratio: float = float(image.get_width()) / float(image.get_height())
	var crop_rect: Rect2i = Rect2i(Vector2i.ZERO, image.get_size())
	if source_ratio > target_ratio:
		var crop_width: int = int(float(image.get_height()) * target_ratio)
		crop_rect.position.x = (image.get_width() - crop_width) / 2
		crop_rect.size.x = crop_width
	else:
		var crop_height: int = int(float(image.get_width()) / target_ratio)
		crop_rect.position.y = (image.get_height() - crop_height) / 2
		crop_rect.size.y = crop_height
	image = image.get_region(crop_rect)
	image.resize(THUMBNAIL_SIZE.x, THUMBNAIL_SIZE.y, Image.INTERPOLATE_LANCZOS)
	var thumbnail: ImageTexture = ImageTexture.create_from_image(image)
	player.stop()
	viewport.queue_free()
	return thumbnail
