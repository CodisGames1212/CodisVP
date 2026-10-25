extends Control

const LIBRARY_CARD_SCENE: PackedScene = preload("res://addons/codisvp/demo/scenes/library_video_card.tscn")
const HDR_SHADER: Shader = preload("res://addons/codisvp/demo/shaders/hdr_adjustment.gdshader")
const PORTRAIT_BREAKPOINT: float = 900.0
const PHONE_BREAKPOINT: float = 560.0
const SCAN_BATCH_SIZE: int = 96
const LIBRARY_PAGE_SIZE: int = 24
const LIBRARY_SCROLL_PREFETCH: float = 240.0
const LIBRARY_CARD_ESTIMATED_HEIGHT: float = 100.0
const LIBRARY_VIRTUAL_BUFFER: int = 4
const SIDEBAR_WIDTH: float = 330.0
const MOBILE_PLAYER_HEIGHT: float = 248.0
const MOBILE_TOUCH_TARGET: float = 52.0
const DOUBLE_TAP_INTERVAL_MS: int = 450
const DOUBLE_TAP_DISTANCE: float = 48.0
const GESTURE_SEEK_SECONDS: float = 10.0
const FULLSCREEN_CONTROLS_HIDE_SECONDS: float = 5.0
const LEGACY_LIBRARY_CONFIG_PATH: String = "user://codisvp_library.cfg"
const SETTINGS_FILENAME: String = "codisvp_library.cfg"
const THEME_NAMES: PackedStringArray = ["Codis Teal", "Midnight Violet", "Paper Light", "Ember"]
const MEDIA_SCAN_EXCLUSIONS: Array[String] = ["$RECYCLE.BIN", "System Volume Information", "Windows", "Program Files", "Program Files (x86)", "ProgramData", "$WinREAgent", "Recovery", "PerfLogs", ".git", ".godot", "node_modules", "WindowsApps", "Android", "Android SDK", "Library", "AppData", "$Extend", "Config.Msi", "OneDriveTemp", "Boot", "EFI", "XboxGames", "Users"]
const VIDEO_FILE_EXTENSIONS: Array[String] = ["3g2", "3gp", "3gpp", "3gpp2", "amv", "asf", "avi", "divx", "dv", "dvr-ms", "f4v", "flv", "m2t", "m2ts", "m2v", "m4v", "mkv", "mov", "mp2", "mp4", "mpe", "mpeg", "mpg", "mpv", "mts", "mxf", "nut", "ogv", "ogx", "rm", "rmvb", "roq", "tod", "ts", "vob", "vro", "webm", "wmv", "y4m"]
const DEFAULT_VIDEO_RATIO: float = 16.0 / 9.0

var content_scroll: ScrollContainer
var content_row: BoxContainer
var featured_column: VBoxContainer
var header_row: HBoxContainer
var header_spacer: Control
var guest_label: Label
var settings_button: Button
var settings_popup: PopupPanel
var theme_option: OptionButton
var ui_scale_slider: HSlider
var ui_scale_label: Label
var ui_scale_factor: float = 1.0
var settings_path: String = ""
var current_theme_name: String = "Codis Teal"
var library_toolbar: HBoxContainer
var library_heading: Label
var scan_button: Button
var top_bar: HBoxContainer
var bottom_bar: HBoxContainer
var speed_label: Label
var bottom_spacer: Control
var scrub_bar: HBoxContainer
var seek_zone_control: Control
var fullscreen_controls_tween: Tween
var fullscreen_controls_visible: bool = true
var is_phone_layout: bool = false
var featured_title: Label
var overlay_title: Label
var featured_subtitle: Label
var video_player: VideoStreamPlayer
var artwork: TextureRect
var player_surface: Control
var gesture_hint: Label
var touch_points: Dictionary[int, Vector2] = {}
var touch_start_positions: Dictionary[int, Vector2] = {}
var touch_gesture_mode: String = ""
var pinch_start_distance: float = 0.0
var pinch_start_zoom: float = 1.0
var player_zoom: float = 1.0
var overlay_timeline: HSlider
var overlay_timeline_dragging: bool = false
var overlay_elapsed_label: Label
var overlay_duration_label: Label
var overlay_play_button: Button
var overlay_speed_button: Button
var gesture_hint_tween: Tween
var playback_speed: float = 1.0
var playback_speeds: Array[float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
var volume_level: float = 0.8
var brightness_level: float = 1.0
var previous_volume: float = 0.8
var speed_cycle_index: int = 2
var fullscreen_active: bool = false
var fullscreen_controls_timer: Timer
var saved_window_mode: Window.Mode = Window.MODE_WINDOWED
var saved_window_size: Vector2i = Vector2i.ZERO
var saved_window_position: Vector2i = Vector2i.ZERO
var audio_track_button: Button
var fullscreen_button: Button
var fullscreen_host: Control
var fullscreen_player_host: Control
var player_stack: Control
var normal_player_parent: Node
var normal_player_index: int = -1
var normal_window_mode: Window.Mode = Window.MODE_WINDOWED
var normal_window_size: Vector2i = Vector2i.ZERO
var normal_window_position: Vector2i = Vector2i.ZERO
var available_audio_tracks: int = 0
var current_audio_track: int = 0
var has_saved_window_state: bool = false
var normal_surface_index: int = -1
var normal_surface_layout_mode: int = 1
var overlay_interactive_controls: Array[Control] = []
var mouse_gesture_active: bool = false
var mouse_gesture_mode: String = ""
var mouse_last_position: Vector2 = Vector2.ZERO
var mouse_press_position: Vector2 = Vector2.ZERO
var mouse_press_was_dragged: bool = false
var mouse_last_click_time: int = 0
var mouse_last_click_position: Vector2 = Vector2.ZERO
var mouse_native_double_handled: bool = false
var library_list: VBoxContainer
var library_scroll: ScrollContainer
var library_search: LineEdit
var library_status: Label
var directory_dialog: FileDialog
var library_entries: Array[Dictionary] = []
var filtered_library_entries: Array[Dictionary] = []
var virtualized_cards: Dictionary[int, LibraryVideoCard] = {}
var top_library_spacer: Control
var bottom_library_spacer: Control
var library_range_start: int = -1
var library_range_end: int = -1
var thumbnail_queue: Array[LibraryVideoCard] = []
var thumbnail_queue_active: bool = false
var scan_stack: Array[String] = []
var scan_roots: Array[String] = []
var scanned_paths: Dictionary[String, bool] = {}
var scan_serial: int = 0
var scanned_directories: int = 0
var scanned_files: int = 0
var scan_active: bool = false
var is_full_device_scan: bool = false
var is_portrait_layout: bool = false
var last_playback_error: String = ""
var video_aspect_container: AspectRatioContainer
var video_aspect_ratio: float = 16.0 / 9.0
var playback_was_active_before_fullscreen: bool = false
var normal_player_surface_parent: Node
var normal_video_aspect_ratio: float = 16.0 / 9.0
var hdr_material: ShaderMaterial
var hdr_cycle_index: int = 0
var hdr_multipliers: Array[float] = [0.5, 1.05, 1.1, 1.0]
var original_hdr_contrast: float = 1.0
var original_hdr_saturation: float = 1.0


func _ready() -> void:
	_resolve_scene_nodes()
	_configure_hdr_filter()
	_configure_pointer_behavior()
	_setup_fullscreen_controls_timer()
	_connect_scene_controls()
	settings_path = _get_settings_path()
	_load_user_settings()
	_create_settings_popup()
	_apply_theme(current_theme_name, false)
	resized.connect(_on_layout_size_changed)
	get_viewport().size_changed.connect(_on_layout_size_changed)
	call_deferred("_refresh_layout_after_resize")
	get_window().files_dropped.connect(_on_files_dropped)
	call_deferred("_start_automatic_scan")


func _configure_pointer_behavior() -> void:
	_apply_pointer_behavior(self)
	for node: Node in find_children("*", "ScrollBar", true, false):
		var scrollbar: ScrollBar = node as ScrollBar
		if scrollbar == null:
			continue
		var track: StyleBoxFlat = StyleBoxFlat.new()
		track.bg_color = Color("#1a2530")
		track.corner_radius_top_left = 0
		track.corner_radius_top_right = 0
		track.corner_radius_bottom_left = 0
		track.corner_radius_bottom_right = 0
		var thumb: StyleBoxFlat = StyleBoxFlat.new()
		thumb.bg_color = Color("#6d7885")
		thumb.corner_radius_top_left = 0
		thumb.corner_radius_top_right = 0
		thumb.corner_radius_bottom_left = 0
		thumb.corner_radius_bottom_right = 0
		scrollbar.add_theme_stylebox_override("scroll", track)
		scrollbar.add_theme_stylebox_override("scroll_focus", track)
		scrollbar.add_theme_stylebox_override("grabber", thumb)
		scrollbar.add_theme_stylebox_override("grabber_highlight", thumb)
		scrollbar.add_theme_stylebox_override("grabber_pressed", thumb)
		scrollbar.add_theme_constant_override("minimum_grabber_size", 18)


func _apply_pointer_behavior(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Control:
			var control: Control = child as Control
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if control is BaseButton or control is LineEdit or control is ScrollBar or control is ScrollContainer or control is Range:
				control.mouse_filter = Control.MOUSE_FILTER_STOP
		_apply_pointer_behavior(child)


func _setup_fullscreen_controls_timer() -> void:
	fullscreen_controls_timer = Timer.new()
	fullscreen_controls_timer.one_shot = true
	fullscreen_controls_timer.wait_time = FULLSCREEN_CONTROLS_HIDE_SECONDS
	fullscreen_controls_timer.timeout.connect(_hide_fullscreen_controls)
	add_child(fullscreen_controls_timer)


func _get_fullscreen_overlay_controls() -> Array[Control]:
	return [top_bar, bottom_bar, scrub_bar, seek_zone_control]


func _show_fullscreen_controls() -> void:
	if not fullscreen_active:
		return
	if is_instance_valid(fullscreen_controls_tween) and fullscreen_controls_tween.is_running():
		fullscreen_controls_tween.kill()
	fullscreen_controls_visible = true
	for overlay_control: Control in _get_fullscreen_overlay_controls():
		overlay_control.show()
		overlay_control.mouse_filter = Control.MOUSE_FILTER_STOP
	fullscreen_controls_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for overlay_control: Control in _get_fullscreen_overlay_controls():
		fullscreen_controls_tween.tween_property(overlay_control, "modulate:a", 1.0, 0.18)
	fullscreen_controls_timer.start(FULLSCREEN_CONTROLS_HIDE_SECONDS)


func _hide_fullscreen_controls() -> void:
	if not fullscreen_active or not fullscreen_controls_visible:
		return
	fullscreen_controls_visible = false
	if is_instance_valid(fullscreen_controls_tween) and fullscreen_controls_tween.is_running():
		fullscreen_controls_tween.kill()
	for overlay_control: Control in _get_fullscreen_overlay_controls():
		overlay_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fullscreen_controls_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	for overlay_control: Control in _get_fullscreen_overlay_controls():
		fullscreen_controls_tween.tween_property(overlay_control, "modulate:a", 0.0, 0.24)
	fullscreen_controls_tween.finished.connect(_finish_hiding_fullscreen_controls)


func _finish_hiding_fullscreen_controls() -> void:
	if fullscreen_active and not fullscreen_controls_visible:
		for overlay_control: Control in _get_fullscreen_overlay_controls():
			overlay_control.hide()


func _handle_fullscreen_surface_interaction(surface_local_position: Vector2) -> void:
	if not fullscreen_active or player_surface == null:
		return
	if surface_local_position.x < 0.0 or surface_local_position.y < 0.0 or surface_local_position.x > player_surface.size.x or surface_local_position.y > player_surface.size.y:
		return
	_show_fullscreen_controls()


func _on_layout_size_changed() -> void:
	call_deferred("_refresh_layout_after_resize")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		call_deferred("_refresh_layout_after_resize")


func _sync_page_rect() -> void:
	_fill_rect(self)
	var background: Control = get_node_or_null("Background") as Control
	if background != null:
		_fill_rect(background)
	var margin_container: MarginContainer = get_node("Margin") as MarginContainer
	_fill_rect(margin_container)
	margin_container.queue_sort()


func _fill_rect(control: Control) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


func _refresh_layout_after_resize() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_sync_page_rect()
	_update_responsive_layout()
	content_row.queue_sort()
	featured_column.queue_sort()
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_sync_page_rect()
	_update_responsive_layout()
	if fullscreen_active:
		_sync_fullscreen_player_rect()
	else:
		_sync_normal_player_rect()
	content_row.queue_sort()
	featured_column.queue_sort()
	player_stack.queue_redraw()


func _set_full_rect(control: Control, target_size: Vector2) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0
	if control.get_parent() is not Container and target_size.x > 0.0 and target_size.y > 0.0:
		control.size = target_size
		control.position = Vector2.ZERO


func _sync_fullscreen_player_rect() -> void:
	if not is_instance_valid(fullscreen_host) or not is_instance_valid(fullscreen_player_host) or not is_instance_valid(video_aspect_container):
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_set_full_rect(fullscreen_host, viewport_size)
	_set_full_rect(fullscreen_player_host, viewport_size)
	video_aspect_container.size_flags_horizontal = Control.SIZE_FILL
	video_aspect_container.size_flags_vertical = Control.SIZE_FILL
	video_aspect_container.anchor_left = 0.0
	video_aspect_container.anchor_top = 0.0
	video_aspect_container.anchor_right = 1.0
	video_aspect_container.anchor_bottom = 1.0
	video_aspect_container.offset_left = 0.0
	video_aspect_container.offset_top = 0.0
	video_aspect_container.offset_right = 0.0
	video_aspect_container.offset_bottom = 0.0
	video_aspect_container.position = Vector2.ZERO
	video_aspect_container.size = fullscreen_player_host.size
	video_aspect_container.queue_redraw()


func _sync_normal_player_rect() -> void:
	if not is_instance_valid(player_stack) or not is_instance_valid(video_aspect_container):
		return
	video_aspect_container.size_flags_horizontal = Control.SIZE_FILL
	video_aspect_container.size_flags_vertical = Control.SIZE_FILL
	player_stack.queue_redraw()
	video_aspect_container.queue_redraw()
	player_surface.queue_redraw()


func _finish_fullscreen_layout() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(self):
		return
	if fullscreen_active:
		_sync_fullscreen_player_rect()
	else:
		_sync_normal_player_rect()
		if is_instance_valid(normal_player_parent) and normal_player_parent is Container:
			(normal_player_parent as Container).queue_sort()
	if playback_was_active_before_fullscreen and video_player.stream != null:
		video_player.paused = false
		if not video_player.is_playing():
			video_player.play()


func _maximize_window_for_desktop() -> void:
	if not is_inside_tree() or Engine.is_embedded_in_editor():
		return
	get_window().mode = Window.MODE_MAXIMIZED
	await get_tree().process_frame
	await _refresh_layout_after_resize()


func _resolve_scene_nodes() -> void:
	content_scroll = get_node("Margin/Page/ContentScroll") as ScrollContainer
	content_row = get_node("Margin/Page/ContentScroll/ContentRow") as BoxContainer
	header_row = get_node("Margin/Page/Header/HeaderRow") as HBoxContainer
	header_spacer = get_node("Margin/Page/Header/HeaderRow/HeaderSpacer") as Control
	guest_label = get_node("Margin/Page/Header/HeaderRow/GuestLabel") as Label
	settings_button = get_node("Margin/Page/ContentScroll/ContentRow/FeaturedColumn/FeaturedDetails/DetailsRow/SettingsButton") as Button
	settings_popup = get_node("SettingsPopup") as PopupPanel
	theme_option = get_node("SettingsPopup/SettingsMargin/SettingsColumn/ThemeOption") as OptionButton
	ui_scale_slider = get_node("SettingsPopup/SettingsMargin/SettingsColumn/UIScaleSlider") as HSlider
	ui_scale_label = get_node("SettingsPopup/SettingsMargin/SettingsColumn/ScaleLabel") as Label
	library_toolbar = get_node("Margin/Page/ContentScroll/ContentRow/RightSidebar/LibraryPanel/LibraryColumn/LibraryToolbar") as HBoxContainer
	library_heading = get_node("Margin/Page/ContentScroll/ContentRow/RightSidebar/LibraryPanel/LibraryColumn/LibraryToolbar/LibraryHeading") as Label
	scan_button = get_node("Margin/Page/ContentScroll/ContentRow/RightSidebar/LibraryPanel/LibraryColumn/LibraryToolbar/ScanButton") as Button
	featured_column = get_node("Margin/Page/ContentScroll/ContentRow/FeaturedColumn") as VBoxContainer
	player_stack = get_node("Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack") as Control
	video_aspect_container = get_node("Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer") as AspectRatioContainer
	video_aspect_ratio = video_aspect_container.ratio
	player_surface = get_node("Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface") as Control
	top_bar = get_node("Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/TopBar") as HBoxContainer
	bottom_bar = get_node("Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/BottomBar") as HBoxContainer
	speed_label = get_node("Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/BottomBar/SpeedLabel") as Label
	bottom_spacer = get_node("Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/BottomBar/BottomSpacer") as Control
	scrub_bar = get_node("Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/ScrubBar") as HBoxContainer
	seek_zone_control = get_node("Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/SeekZoneButton") as Control
	featured_title = get_node("Margin/Page/ContentScroll/ContentRow/FeaturedColumn/FeaturedDetails/DetailsRow/DetailsCopy/FeaturedTitle") as Label
	overlay_title = get_node("Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/TopBar/OverlayTitle") as Label
	featured_subtitle = get_node("Margin/Page/ContentScroll/ContentRow/FeaturedColumn/FeaturedDetails/DetailsRow/DetailsCopy/FeaturedSubtitle") as Label
	video_player = get_node("Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/VideoPlayer") as VideoStreamPlayer
	artwork = get_node("Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/Artwork") as TextureRect
	gesture_hint = get_node("Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/GestureHint") as Label
	overlay_timeline = get_node("Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/ScrubBar/OverlayTimeline") as HSlider
	overlay_elapsed_label = get_node("Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/ScrubBar/ElapsedLabel") as Label
	overlay_duration_label = get_node("Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/ScrubBar/DurationLabel") as Label
	overlay_play_button = get_node("Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/BottomBar/OverlayPlayButton") as Button
	overlay_speed_button = get_node("Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/BottomBar/OverlaySpeedButton") as Button
	audio_track_button = get_node("Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/TopBar/AudioButton") as Button
	fullscreen_button = get_node("Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/BottomBar/FullscreenButton") as Button
	fullscreen_host = get_node("FullscreenLayer/FullscreenHost") as Control
	fullscreen_player_host = get_node("FullscreenLayer/FullscreenHost/PlayerHost") as Control
	library_list = get_node("Margin/Page/ContentScroll/ContentRow/RightSidebar/LibraryPanel/LibraryColumn/LibraryScroll/LibraryList") as VBoxContainer
	library_scroll = get_node("Margin/Page/ContentScroll/ContentRow/RightSidebar/LibraryPanel/LibraryColumn/LibraryScroll") as ScrollContainer
	library_search = get_node("Margin/Page/ContentScroll/ContentRow/RightSidebar/LibraryPanel/LibraryColumn/LibrarySearch") as LineEdit
	library_status = get_node("Margin/Page/ContentScroll/ContentRow/RightSidebar/LibraryPanel/LibraryColumn/LibraryStatus") as Label
	directory_dialog = get_node("DirectoryDialog") as FileDialog
	normal_player_parent = video_aspect_container.get_parent()
	normal_player_index = video_aspect_container.get_index()
	normal_player_surface_parent = player_surface.get_parent()
	normal_surface_index = player_surface.get_index()
	normal_surface_layout_mode = player_surface.layout_mode
	normal_video_aspect_ratio = video_aspect_container.ratio


func _connect_scene_controls() -> void:
	(get_node("Margin/Page/ContentScroll/ContentRow/RightSidebar/LibraryPanel/LibraryColumn/LibraryToolbar/ScanButton") as Button).pressed.connect(_open_directory_picker)
	library_search.text_changed.connect(_filter_library_cards)
	library_scroll.get_v_scroll_bar().value_changed.connect(_on_library_scroll_changed)
	settings_button.pressed.connect(_open_settings_popup)
	theme_option.item_selected.connect(_on_theme_selected)
	ui_scale_slider.value_changed.connect(_on_ui_scale_changed)
	directory_dialog.access = FileDialog.ACCESS_FILESYSTEM
	directory_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	directory_dialog.dir_selected.connect(_on_directory_selected)
	(get_node("Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/TopBar/BackButton") as Button).pressed.connect(func() -> void: _update_gesture_hint("Player overlay"))
	(get_node("Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/TopBar/HDRButton") as Button).pressed.connect(_cycle_hdr)
	(get_node("Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/TopBar/CaptionsButton") as Button).pressed.connect(func() -> void: _update_gesture_hint("Captions are not provided by this demo"))
	audio_track_button.pressed.connect(_show_audio_track_menu)
	(get_node("Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/TopBar/MenuButton") as Button).pressed.connect(_show_player_menu)
	(get_node("Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/SeekZoneButton") as Button).pressed.connect(func() -> void: _handle_double_tap(player_surface.size * 0.5))
	(get_node("Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/BottomBar/OverlayPlayButton") as Button).pressed.connect(_toggle_playback)
	(get_node("Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/BottomBar/RewindButton") as Button).pressed.connect(_seek_video.bind(-GESTURE_SEEK_SECONDS))
	(get_node("Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/BottomBar/ForwardButton") as Button).pressed.connect(_seek_video.bind(GESTURE_SEEK_SECONDS))
	(get_node("Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/BottomBar/OverlaySpeedButton") as Button).pressed.connect(_show_playback_speed_popup)
	(get_node("Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/BottomBar/FullscreenButton") as Button).pressed.connect(_toggle_fullscreen)
	overlay_timeline.drag_started.connect(func() -> void: overlay_timeline_dragging = true)
	overlay_timeline.drag_ended.connect(_on_overlay_timeline_drag_ended)
	for control_path: NodePath in [
		"Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/TopBar/BackButton",
		"Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/TopBar/HDRButton",
		"Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/TopBar/CaptionsButton",
		"Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/TopBar/AudioButton",
		"Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/TopBar/MenuButton",
		"Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/SeekZoneButton",
		"Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/ScrubBar/OverlayTimeline",
		"Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/BottomBar/OverlayPlayButton",
		"Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/BottomBar/RewindButton",
		"Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/BottomBar/ForwardButton",
		"Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/BottomBar/OverlaySpeedButton",
		"Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/BottomBar/FullscreenButton",
	]:
		overlay_interactive_controls.append(get_node(control_path) as Control)
	overlay_interactive_controls.append(audio_track_button)
	overlay_interactive_controls.append(fullscreen_button)


func _on_files_dropped(files: PackedStringArray) -> void:
	if files.is_empty():
		return
	var dropped_path: String = files[0]
	if not FileAccess.file_exists(dropped_path):
		library_status.text = "Could not access dropped file: " + dropped_path.get_file()
		return
	_play_library_entry(dropped_path)
	if files.size() > 1:
		library_status.text += " - Only the first dropped file was opened."


func _enforce_page_rect() -> void:
	var margin_container: MarginContainer = get_node_or_null("Margin") as MarginContainer
	if margin_container == null:
		return
	if not is_zero_approx(margin_container.offset_right) or not is_zero_approx(margin_container.offset_bottom) or not is_zero_approx(margin_container.offset_left) or not is_zero_approx(margin_container.offset_top):
		_sync_page_rect()


func _process(_delta: float) -> void:
	_enforce_page_rect()
	_update_virtualized_library()
	if not is_instance_valid(video_player):
		return
	if video_player.stream != null:
		var playback: VideoStreamPlayback = video_player.stream.call("get_last_playback") as VideoStreamPlayback
		if playback == null and video_player.is_playing():
			video_player.stop()
			video_player.visible = false
			artwork.visible = true
			last_playback_error = "The video decoder did not start. Check that the CodisVP native extension and its FFmpeg libraries loaded."
			library_status.text = "Could not play %s: %s" % [overlay_title.text, last_playback_error]
			_update_gesture_hint("Video decoder unavailable")
		if playback != null and playback.has_method("get_last_error"):
			var playback_error: String = str(playback.call("get_last_error"))
			if not playback_error.is_empty() and playback_error != last_playback_error:
				last_playback_error = playback_error
				video_player.stop()
				video_player.visible = false
				artwork.visible = true
				library_status.text = "Could not play %s: %s" % [overlay_title.text, playback_error]
				_update_gesture_hint("Video playback failed")
		if playback != null and playback.has_method("get_texture"):
			var playback_texture: Texture2D = playback.call("get_texture") as Texture2D
			if playback_texture != null and playback_texture.get_width() > 0 and playback_texture.get_height() > 0:
				var detected_ratio: float = float(playback_texture.get_width()) / float(playback_texture.get_height())
				if not is_equal_approx(video_aspect_ratio, detected_ratio):
					video_aspect_ratio = detected_ratio
					video_aspect_container.ratio = detected_ratio
	var duration: float = video_player.get_stream_length() if video_player.stream != null else 0.0
	if overlay_timeline != null:
		overlay_timeline.max_value = maxf(duration, 0.01)
		if not overlay_timeline_dragging:
			overlay_timeline.set_value_no_signal(video_player.stream_position)
		overlay_timeline.editable = video_player.stream != null
	if overlay_elapsed_label != null:
		overlay_elapsed_label.text = _format_time(video_player.stream_position)
	if overlay_duration_label != null:
		overlay_duration_label.text = _format_time(duration)
	_update_overlay_state()


func _format_time(seconds: float) -> String:
	var total_seconds: int = maxi(0, int(seconds))
	return "%02d:%02d" % [int(total_seconds / 60), total_seconds % 60]


func _is_device_root(path: String) -> bool:
	var normalized_path: String = path.replace("\\", "/").simplify_path()
	if normalized_path.is_empty() or normalized_path == "." or normalized_path == "/":
		return true
	if OS.get_name() == "Windows":
		var without_trailing_slash: String = normalized_path.trim_suffix("/")
		return without_trailing_slash.length() == 2 and without_trailing_slash.ends_with(":")
	return false


func _on_directory_selected(directory_path: String) -> void:
	if _is_device_root(directory_path):
		library_status.text = "Please choose a folder inside the drive, not the drive root."
		return
	var config: ConfigFile = ConfigFile.new()
	var load_result: Error = config.load(settings_path)
	var saved_roots: PackedStringArray = []
	if load_result == OK:
		saved_roots = config.get_value("library", "scan_roots", PackedStringArray())
	if not saved_roots.has(directory_path):
		saved_roots.append(directory_path)
	config.set_value("library", "scan_roots", saved_roots)
	var save_result: Error = config.save(settings_path)
	if save_result != OK:
		push_warning("Could not save the selected video scan folder.")
	_scan_roots([directory_path], false)


func _get_settings_path() -> String:
	var documents_path: String = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if not documents_path.is_empty():
		var codis_directory: String = documents_path.path_join("CodisGames").path_join("CodisVP")
		var directory_error: Error = DirAccess.make_dir_recursive_absolute(codis_directory)
		if directory_error == OK or DirAccess.dir_exists_absolute(codis_directory):
			return codis_directory.path_join(SETTINGS_FILENAME)
	push_warning("Documents settings folder is not writable; using Godot's per-user settings directory.")
	return "user://" + SETTINGS_FILENAME


func _load_user_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	var load_result: Error = config.load(settings_path)
	if load_result != OK and FileAccess.file_exists(LEGACY_LIBRARY_CONFIG_PATH):
		var legacy_config: ConfigFile = ConfigFile.new()
		if legacy_config.load(LEGACY_LIBRARY_CONFIG_PATH) == OK:
			config = legacy_config
			config.save(settings_path)
	if config.load(settings_path) == OK:
		current_theme_name = str(config.get_value("settings", "theme", "Codis Teal"))
		if not THEME_NAMES.has(current_theme_name):
			current_theme_name = "Codis Teal"
		volume_level = clampf(float(config.get_value("settings", "volume", volume_level)), 0.0, 1.0)
		ui_scale_factor = clampf(float(config.get_value("settings", "ui_scale", ui_scale_factor)), 0.8, 1.4)


func _save_user_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	var load_result: Error = config.load(settings_path)
	if load_result != OK:
		var legacy_config: ConfigFile = ConfigFile.new()
		if legacy_config.load(LEGACY_LIBRARY_CONFIG_PATH) == OK:
			config = legacy_config
	config.set_value("settings", "theme", current_theme_name)
	config.set_value("settings", "volume", volume_level)
	config.set_value("settings", "ui_scale", ui_scale_factor)
	var save_result: Error = config.save(settings_path)
	if save_result != OK:
		push_warning("Could not save CodisVP settings to " + settings_path)


func _create_settings_popup() -> void:
	theme_option.clear()
	for theme_name: String in THEME_NAMES:
		theme_option.add_item(theme_name)
	theme_option.select(maxi(0, THEME_NAMES.find(current_theme_name)))
	ui_scale_slider.set_value_no_signal(ui_scale_factor)
	_apply_ui_scale(ui_scale_factor)


func _apply_ui_scale(scale_factor: float) -> void:
	ui_scale_factor = clampf(scale_factor, 0.8, 1.4)
	get_tree().root.content_scale_factor = ui_scale_factor
	ui_scale_label.text = "UI scale · %d%%" % roundi(ui_scale_factor * 100.0)
	call_deferred("_refresh_layout_after_resize")


func _on_ui_scale_changed(value: float) -> void:
	_apply_ui_scale(value)
	_save_user_settings()


func _open_settings_popup() -> void:
	settings_popup.popup_centered()


func _on_theme_selected(index: int) -> void:
	if index < 0 or index >= THEME_NAMES.size():
		return
	current_theme_name = THEME_NAMES[index]
	_apply_theme(current_theme_name, true)
	_save_user_settings()


func _apply_theme(theme_name: String, show_feedback: bool) -> void:
	var background_color: Color = Color("#101820")
	var panel_color: Color = Color("#172533")
	var accent_color: Color = Color("#28c7b7")
	var text_color: Color = Color("#f2f5f8")
	var muted_color: Color = Color("#aab4c2")
	match theme_name:
		"Midnight Violet":
			background_color = Color("#100e1d")
			panel_color = Color("#1e1933")
			accent_color = Color("#b59aff")
			text_color = Color("#f3efff")
			muted_color = Color("#bcb4d0")
		"Paper Light":
			background_color = Color("#e8edf2")
			panel_color = Color("#ffffff")
			accent_color = Color("#167d76")
			text_color = Color("#17212b")
			muted_color = Color("#586676")
		"Ember":
			background_color = Color("#21120f")
			panel_color = Color("#35201a")
			accent_color = Color("#ff9b52")
			text_color = Color("#fff2e8")
			muted_color = Color("#d0b4a4")
	(get_node("Background") as ColorRect).color = background_color
	var panels: Array[PanelContainer] = [
		get_node("Margin/Page/Header") as PanelContainer,
		get_node("Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame") as PanelContainer,
		get_node("Margin/Page/ContentScroll/ContentRow/FeaturedColumn/FeaturedDetails") as PanelContainer,
		get_node("Margin/Page/ContentScroll/ContentRow/RightSidebar/LibraryPanel") as PanelContainer,
	]
	for panel: PanelContainer in panels:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = panel_color
		style.border_color = accent_color.darkened(0.72)
		style.set_border_width_all(1)
		style.set_corner_radius_all(10)
		panel.add_theme_stylebox_override("panel", style)
	for label_path: NodePath in [
		"Margin/Page/Header/HeaderRow/BrandFlow",
		"Margin/Page/ContentScroll/ContentRow/FeaturedColumn/FeaturedDetails/DetailsRow/DetailsCopy/FeaturedTitle",
		"Margin/Page/ContentScroll/ContentRow/RightSidebar/LibraryPanel/LibraryColumn/LibraryToolbar/LibraryHeading",
	]:
		(get_node(label_path) as Label).add_theme_color_override("font_color", text_color)
	(get_node("Margin/Page/Header/HeaderRow/BrandStream") as Label).add_theme_color_override("font_color", accent_color)
	for label_path: NodePath in [
		"Margin/Page/Header/HeaderRow/GuestLabel",
		"Margin/Page/ContentScroll/ContentRow/FeaturedColumn/FeaturedDetails/DetailsRow/DetailsCopy/FeaturedSubtitle",
		"Margin/Page/ContentScroll/ContentRow/RightSidebar/LibraryPanel/LibraryColumn/LibraryStatus",
	]:
		(get_node(label_path) as Label).add_theme_color_override("font_color", muted_color)
	settings_button.add_theme_color_override("font_color", accent_color)
	if show_feedback:
		_update_gesture_hint("Theme: " + theme_name)


func _start_automatic_scan() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(settings_path) != OK:
		library_status.text = "Choose a folder to scan for local videos."
		return
	var last_played_path: String = str(config.get_value("playback", "last_path", ""))
	if not last_played_path.is_empty():
		if FileAccess.file_exists(last_played_path):
			_play_library_entry(last_played_path)
		else:
			library_status.text = "Previously played file is unavailable: " + last_played_path.get_file()
	var saved_roots: PackedStringArray = config.get_value("library", "scan_roots", PackedStringArray())
	var roots: Array[String] = []
	for saved_path: String in saved_roots:
		if not saved_path.is_empty() and not roots.has(saved_path):
			roots.append(saved_path)
	if not roots.is_empty():
		_scan_roots(roots, false)
	elif last_played_path.is_empty():
		library_status.text = "Choose a folder to scan for local videos."


func _open_directory_picker() -> void:
	directory_dialog.popup_centered_ratio(0.8)


func _show_playback_formats() -> void:
	var format_text: String = ", ".join(_get_supported_formats())
	if ClassDB.class_exists("VideoStreamCodisVP"):
		library_status.text = "Registered video formats: " + format_text + ". Codec support can still depend on the individual file."
	else:
		library_status.text = "CodisVP is not loaded. Godot core recognized formats: " + format_text + "."


func _get_supported_formats() -> PackedStringArray:
	var formats: PackedStringArray = ResourceLoader.get_recognized_extensions_for_type("VideoStream")
	if ClassDB.class_exists("VideoStreamCodisVP"):
		var custom_video_formats: PackedStringArray = ["mp4", "m4v", "webm", "mkv", "avi", "mov", "mpeg", "mpg", "ts", "m2ts", "flv", "wmv"]
		for extension: String in custom_video_formats:
			if not formats.has(extension):
				formats.append(extension)
	return formats


func _on_library_scroll_changed(_value: float) -> void:
	_update_virtualized_library()


func _clear_virtualized_cards() -> void:
	thumbnail_queue.clear()
	if not is_instance_valid(library_list):
		virtualized_cards.clear()
		return
	for child: Node in library_list.get_children():
		if child is LibraryVideoCard or child == top_library_spacer or child == bottom_library_spacer:
			library_list.remove_child(child)
			child.queue_free()
	virtualized_cards.clear()
	top_library_spacer = null
	bottom_library_spacer = null


func _create_library_spacer(height: float) -> Control:
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0.0, maxf(0.0, height))
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func _update_virtualized_library() -> void:
	if not is_node_ready() or library_scroll == null or not is_instance_valid(library_list):
		return
	var total: int = filtered_library_entries.size()
	if total == 0:
		if library_range_start != 0 or library_range_end != 0:
			_clear_virtualized_cards()
			library_range_start = 0
			library_range_end = 0
		return
	var row_pitch: float = LIBRARY_CARD_ESTIMATED_HEIGHT + float(library_list.get_theme_constant("separation"))
	if row_pitch <= 0.0:
		row_pitch = LIBRARY_CARD_ESTIMATED_HEIGHT
	var scroll_top: float = float(library_scroll.scroll_vertical)
	var visible_height: float = maxf(library_scroll.size.y, LIBRARY_CARD_ESTIMATED_HEIGHT)
	var first_visible: int = maxi(0, int(floor(maxf(0.0, scroll_top - LIBRARY_SCROLL_PREFETCH) / row_pitch)))
	var last_visible: int = mini(total, int(ceil((scroll_top + visible_height + LIBRARY_SCROLL_PREFETCH) / row_pitch)))
	var wanted_start: int = maxi(0, first_visible - LIBRARY_VIRTUAL_BUFFER)
	var wanted_end: int = mini(total, maxi(wanted_start + LIBRARY_PAGE_SIZE, last_visible + LIBRARY_VIRTUAL_BUFFER))
	if wanted_end - wanted_start > LIBRARY_PAGE_SIZE + LIBRARY_VIRTUAL_BUFFER * 2:
		wanted_end = wanted_start + LIBRARY_PAGE_SIZE + LIBRARY_VIRTUAL_BUFFER * 2
	if wanted_start == library_range_start and wanted_end == library_range_end:
		return
	_clear_virtualized_cards()
	library_range_start = wanted_start
	library_range_end = wanted_end
	top_library_spacer = _create_library_spacer(float(wanted_start) * row_pitch)
	library_list.add_child(top_library_spacer)
	for index: int in range(wanted_start, wanted_end):
		var data: Dictionary = filtered_library_entries[index]
		var card: LibraryVideoCard = LIBRARY_CARD_SCENE.instantiate() as LibraryVideoCard
		card.configure_video(str(data.get("path", "")), str(data.get("extension", "")), bool(data.get("supported", false)))
		card.double_clicked.connect(_play_library_entry)
		library_list.add_child(card)
		virtualized_cards[index] = card
		thumbnail_queue.append(card)
	bottom_library_spacer = _create_library_spacer(float(total - wanted_end) * row_pitch)
	library_list.add_child(bottom_library_spacer)
	if not thumbnail_queue_active:
		_process_thumbnail_queue.call_deferred()


func _process_thumbnail_queue() -> void:
	if thumbnail_queue_active:
		return
	thumbnail_queue_active = true
	while not thumbnail_queue.is_empty():
		var card: LibraryVideoCard = thumbnail_queue.pop_front()
		if is_instance_valid(card) and card.is_visible_in_tree():
			card.request_thumbnail()
			await get_tree().create_timer(0.15).timeout
	thumbnail_queue_active = false


func _filter_library_cards(query: String) -> void:
	filtered_library_entries.clear()
	var normalized_query: String = query.strip_edges().to_lower()
	for entry: Dictionary in library_entries:
		var entry_path: String = str(entry.get("path", ""))
		var search_text: String = (entry_path.get_file().get_basename() + " " + entry_path.get_base_dir()).to_lower()
		if normalized_query.is_empty() or search_text.contains(normalized_query):
			filtered_library_entries.append(entry)
	_clear_virtualized_cards()
	library_range_start = -1
	library_range_end = -1
	_update_virtualized_library()


func _scan_roots(roots: Array[String], full_device_scan: bool = false) -> void:
	scan_serial += 1
	is_full_device_scan = full_device_scan
	scan_stack.clear()
	scanned_paths.clear()
	scan_roots = roots.duplicate()
	scanned_directories = 0
	scanned_files = 0
	scan_active = true
	library_entries.clear()
	filtered_library_entries.clear()
	library_range_start = -1
	library_range_end = -1
	_clear_virtualized_cards()
	var rejected_device_root: bool = false
	for root_path: String in roots:
		var normalized_path: String = root_path.replace("\\", "/").simplify_path()
		if not is_full_device_scan and _is_device_root(normalized_path):
			rejected_device_root = true
			continue
		if DirAccess.dir_exists_absolute(normalized_path) and not scanned_paths.has(normalized_path):
			scanned_paths[normalized_path] = true
			scan_stack.append(normalized_path)
	if scan_stack.is_empty():
		library_status.text = "Scanning the entire device root is disabled. Choose a specific media folder." if rejected_device_root else "No readable selected folders found."
		scan_active = false
		return
	library_status.text = "Scanning %d selected folder(s)..." % scan_stack.size()
	_process_scan_batch.call_deferred(scan_serial)


func _process_scan_batch(active_scan: int) -> void:
	if not scan_active or active_scan != scan_serial:
		return
	var files_this_batch: int = 0
	var directories_this_batch: int = 0
	var recognized: PackedStringArray = _get_supported_formats()
	while not scan_stack.is_empty() and directories_this_batch < 8:
		if active_scan != scan_serial:
			return
		var current_path: String = scan_stack.pop_back()
		var current_directory: DirAccess = DirAccess.open(current_path)
		if current_directory == null:
			continue
		scanned_directories += 1
		directories_this_batch += 1
		for file_name: String in current_directory.get_files():
			files_this_batch += 1
			scanned_files += 1
			var extension: String = file_name.get_extension().to_lower()
			if not VIDEO_FILE_EXTENSIONS.has(extension):
				continue
			if not is_full_device_scan and not recognized.has(extension):
				continue
			var file_path: String = current_path.path_join(file_name)
			var entry: Dictionary = {"path": file_path, "extension": extension, "supported": recognized.has(extension)}
			library_entries.append(entry)
			if library_search != null:
				_filter_library_cards(library_search.text)
			if files_this_batch >= SCAN_BATCH_SIZE:
				files_this_batch = 0
				library_status.text = "Found %d videos · checked %d folders · %d files" % [library_entries.size(), scanned_directories, scanned_files]
				await get_tree().process_frame
				if active_scan != scan_serial:
					return
		for subdirectory_name: String in current_directory.get_directories():
			if subdirectory_name.begins_with("."):
				continue
			if is_full_device_scan and MEDIA_SCAN_EXCLUSIONS.has(subdirectory_name):
				continue
			var subdirectory_path: String = current_path.path_join(subdirectory_name).simplify_path()
			if scanned_paths.has(subdirectory_path):
				continue
			scanned_paths[subdirectory_path] = true
			scan_stack.append(subdirectory_path)
	if not scan_stack.is_empty():
		library_status.text = "Found %d videos · checked %d folders · %d files" % [library_entries.size(), scanned_directories, scanned_files]
		await get_tree().process_frame
		if active_scan == scan_serial and scan_active:
			_process_scan_batch(active_scan)
		return
	if is_full_device_scan:
		library_status.text = "%d candidate videos found across %d folders on %d drive(s). Green = recognized extension; amber = not registered." % [library_entries.size(), scanned_directories, scan_roots.size()]
	else:
		library_status.text = "%d candidate videos found in the selected folder. Extension recognition does not guarantee codec compatibility." % library_entries.size()
	scan_active = false


func _play_library_entry(path: String) -> void:
	if not FileAccess.file_exists(path):
		library_status.text = "Could not access file: " + path.get_file()
		return
	if not ClassDB.class_exists("VideoStreamCodisVP"):
		library_status.text = "Native video loader unavailable; cannot try " + path.get_file()
		return
	var stream: VideoStream = ClassDB.instantiate("VideoStreamCodisVP") as VideoStream
	if stream == null:
		library_status.text = "Could not create a video stream for " + path.get_file()
		return
	var config: ConfigFile = ConfigFile.new()
	config.load(settings_path)
	config.set_value("playback", "last_path", path)
	var save_result: Error = config.save(settings_path)
	if save_result != OK:
		push_warning("Could not save the last played video path.")
	last_playback_error = ""
	stream.file = path
	video_player.stream = stream
	video_player.visible = true
	current_audio_track = 0
	video_player.audio_track = current_audio_track
	video_player.speed_scale = playback_speed
	video_player.volume = volume_level
	video_player.volume_db = linear_to_db(maxf(volume_level, 0.0001))
	video_player.modulate = Color(brightness_level, brightness_level, brightness_level, 1.0)
	video_player.paused = false
	video_player.play()
	featured_title.text = path.get_file().get_basename().to_upper()
	overlay_title.text = path.get_file().get_basename().to_upper()
	featured_subtitle.text = path.get_base_dir()
	library_status.text = "Attempting playback of %s · Extension and codec compatibility are checked by the loader." % path.get_file()



func _seek_video(offset_seconds: float) -> void:
	if video_player == null or video_player.stream == null:
		return
	var duration: float = video_player.get_stream_length()
	video_player.stream_position = clampf(video_player.stream_position + offset_seconds, 0.0, maxf(duration, 0.0))
	_update_gesture_hint("Rewind 10s" if offset_seconds < 0.0 else "Forward 10s")


func _set_player_zoom(value: float) -> void:
	player_zoom = clampf(value, 1.0, 2.5)
	if video_player != null:
		video_player.scale = Vector2(player_zoom, player_zoom)
	if artwork != null:
		artwork.scale = Vector2(player_zoom, player_zoom)
	_update_gesture_hint("Zoom %d%%" % int(round(player_zoom * 100.0)))


func _update_gesture_hint(message: String) -> void:
	if gesture_hint == null:
		return
	gesture_hint.text = message
	gesture_hint.show()
	if gesture_hint_tween != null and gesture_hint_tween.is_running():
		gesture_hint_tween.kill()
	gesture_hint_tween = create_tween()
	gesture_hint_tween.tween_interval(2.2)
	gesture_hint_tween.tween_callback(func() -> void: gesture_hint.hide())


func _configure_hdr_filter() -> void:
	hdr_material = ShaderMaterial.new()
	hdr_material.shader = HDR_SHADER
	hdr_material.set_shader_parameter("contrast", 1.0)
	hdr_material.set_shader_parameter("saturation", 1.0)
	artwork.material = null
	video_player.material = null


func _cycle_hdr() -> void:
	var multiplier: float = hdr_multipliers[hdr_cycle_index]
	if is_equal_approx(multiplier, 1.0):
		artwork.material = null
		video_player.material = null
	else:
		hdr_material.set_shader_parameter("contrast", original_hdr_contrast * multiplier)
		hdr_material.set_shader_parameter("saturation", original_hdr_saturation * multiplier)
		artwork.material = hdr_material
		video_player.material = hdr_material
	_update_gesture_hint("HDR %.1fx original contrast and saturation" % multiplier)
	hdr_cycle_index = (hdr_cycle_index + 1) % hdr_multipliers.size()


func _show_audio_track_menu() -> void:
	if video_player.stream == null:
		_update_gesture_hint("Load a video before choosing an audio track")
		return
	var playback: VideoStreamPlayback = video_player.stream.call("get_last_playback") as VideoStreamPlayback if video_player.stream.has_method("get_last_playback") else null
	if playback == null or not playback.has_method("get_decoded_audio_track_count"):
		_update_gesture_hint("Audio-track selection is unavailable for this stream")
		return
	available_audio_tracks = int(playback.call("get_decoded_audio_track_count"))
	if available_audio_tracks <= 0:
		_update_gesture_hint("This video has no audio tracks")
		return
	var popup: PopupMenu = PopupMenu.new()
	for track_index: int in range(available_audio_tracks):
		popup.add_item("Audio track %d" % (track_index + 1), track_index)
		popup.set_item_as_checkable(track_index, true)
		popup.set_item_checked(track_index, track_index == current_audio_track)
	popup.id_pressed.connect(_select_audio_track)
	player_surface.add_child(popup)
	popup.position = Vector2i(maxi(0, int(player_surface.size.x) - 200), 54)
	popup.popup()
	popup.popup_hide.connect(popup.queue_free)


func _select_audio_track(track_index: int) -> void:
	if video_player.stream == null or track_index < 0 or track_index >= available_audio_tracks:
		return
	current_audio_track = track_index
	video_player.audio_track = track_index
	var playback: VideoStreamPlayback = video_player.stream.call("get_last_playback") as VideoStreamPlayback
	var channels: int = int(playback.call("get_decoded_audio_channels")) if playback != null and playback.has_method("get_decoded_audio_channels") else 0
	_update_gesture_hint("Audio track %d selected · %d output channels" % [track_index + 1, channels])

func _show_player_menu() -> void:
	var popup: PopupMenu = PopupMenu.new()
	popup.add_item("Playback speed", 1)
	popup.add_item("Mute / unmute", 2)
	popup.add_item("Toggle fullscreen", 3)
	popup.add_item("Reset zoom", 4)
	popup.add_item("Player help", 5)
	popup.id_pressed.connect(_on_player_menu_selected)
	player_surface.add_child(popup)
	popup.position = Vector2i(maxi(0, int(player_surface.size.x) - 190), 54)
	popup.popup()
	popup.popup_hide.connect(popup.queue_free)


func _on_player_menu_selected(id: int) -> void:
	match id:
		1:
			_show_playback_speed_popup()
		2:
			_toggle_mute()
		3:
			_toggle_fullscreen()
		4:
			_set_player_zoom(1.0)
		5:
			_update_gesture_hint("Double-click the center to play or pause")

func _toggle_mute() -> void:
	if volume_level > 0.0:
		previous_volume = volume_level
		volume_level = 0.0
	else:
		volume_level = previous_volume if previous_volume > 0.0 else 0.8
	if video_player != null:
		video_player.volume = volume_level
		video_player.volume_db = linear_to_db(maxf(volume_level, 0.0001))
	_update_gesture_hint("Muted" if volume_level == 0.0 else "Unmuted")


func _show_playback_speed_popup() -> void:
	if not is_instance_valid(overlay_speed_button) or not is_instance_valid(player_surface):
		return
	var popup: PopupMenu = PopupMenu.new()
	for speed_index: int in range(playback_speeds.size()):
		var speed: float = playback_speeds[speed_index]
		var speed_text: String = "%.2f×" % speed
		popup.add_radio_check_item(speed_text, speed_index)
		popup.set_item_checked(speed_index, is_equal_approx(speed, playback_speed))
	popup.id_pressed.connect(_select_playback_speed)
	player_surface.add_child(popup)
	var surface_local_button_rect: Rect2 = overlay_speed_button.get_global_rect()
	surface_local_button_rect.position = player_surface.get_global_transform().affine_inverse() * surface_local_button_rect.position
	popup.position = Vector2i(maxi(0, int(surface_local_button_rect.position.x)), maxi(0, int(surface_local_button_rect.position.y) - 8))
	popup.popup()
	popup.popup_hide.connect(popup.queue_free)


func _select_playback_speed(speed_index: int) -> void:
	if speed_index < 0 or speed_index >= playback_speeds.size():
		return
	playback_speed = playback_speeds[speed_index]
	if video_player != null:
		video_player.speed_scale = playback_speed
	_update_overlay_state()
	_update_gesture_hint("Speed %.2f×" % playback_speed)


func _toggle_fullscreen() -> void:
	var game_window: Window = get_window()
	if not is_instance_valid(game_window) or not is_instance_valid(fullscreen_host) or not is_instance_valid(fullscreen_player_host):
		return
	if fullscreen_active:
		fullscreen_active = false
		fullscreen_controls_timer.stop()
		if is_instance_valid(fullscreen_controls_tween) and fullscreen_controls_tween.is_running():
			fullscreen_controls_tween.kill()
		fullscreen_controls_visible = true
		for overlay_control: Control in _get_fullscreen_overlay_controls():
			overlay_control.show()
			overlay_control.modulate.a = 1.0
			overlay_control.mouse_filter = Control.MOUSE_FILTER_STOP
		video_aspect_container.reparent(normal_player_parent, false)
		if normal_player_parent is Container:
			(normal_player_parent as Container).move_child(video_aspect_container, mini(normal_player_index, normal_player_parent.get_child_count() - 1))
		video_aspect_container.ratio = normal_video_aspect_ratio
		fullscreen_host.hide()
		if has_saved_window_state and not Engine.is_embedded_in_editor():
			game_window.mode = normal_window_mode
			if normal_window_mode == Window.MODE_WINDOWED:
				game_window.size = normal_window_size
				game_window.position = normal_window_position
		call_deferred("_finish_fullscreen_layout")
		_update_fullscreen_button()
		_update_gesture_hint("Exited player fullscreen")
		return
	playback_was_active_before_fullscreen = video_player.stream != null and video_player.is_playing() and not video_player.paused
	if not Engine.is_embedded_in_editor():
		normal_window_mode = game_window.mode
		normal_window_size = game_window.size
		normal_window_position = game_window.position
		has_saved_window_state = true
	normal_player_parent = video_aspect_container.get_parent()
	normal_player_index = video_aspect_container.get_index()
	normal_video_aspect_ratio = video_aspect_container.ratio
	fullscreen_active = true
	fullscreen_host.show()
	_show_fullscreen_controls()
	video_aspect_container.reparent(fullscreen_player_host, false)
	if not Engine.is_embedded_in_editor():
		game_window.mode = Window.MODE_FULLSCREEN
	call_deferred("_finish_fullscreen_layout")
	_update_fullscreen_button()
	_update_gesture_hint("Fullscreen · click the fullscreen button to exit")


func _update_fullscreen_button() -> void:
	if fullscreen_button == null:
		return
	fullscreen_button.text = "×" if fullscreen_active else "□"
	fullscreen_button.tooltip_text = "Exit fullscreen" if fullscreen_active else "Fullscreen"


func _update_overlay_state() -> void:
	if overlay_play_button != null and video_player != null:
		overlay_play_button.text = "❚❚" if video_player.is_playing() and not video_player.paused else "▶"
		overlay_play_button.disabled = video_player.stream == null
	if overlay_speed_button != null:
		overlay_speed_button.text = ("%.2f" % playback_speed) + "×"


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and fullscreen_active:
		_toggle_fullscreen()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		_handle_fullscreen_surface_interaction((event as InputEventScreenTouch).position)
		_handle_screen_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event as InputEventScreenDrag)
	elif event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if player_surface != null:
			var local_event: InputEventMouseButton = player_surface.make_input_local(mouse_event) as InputEventMouseButton
			_handle_fullscreen_surface_interaction(local_event.position)
		_handle_surface_mouse_button(mouse_event)
	elif event is InputEventMouseMotion and mouse_gesture_active:
		_handle_surface_mouse_motion(event as InputEventMouseMotion)


func _is_overlay_control_at(surface_local_position: Vector2) -> bool:
	for overlay_control: Control in overlay_interactive_controls:
		if is_instance_valid(overlay_control) and overlay_control.visible:
			var local_control_transform: Transform2D = player_surface.get_global_transform().affine_inverse() * overlay_control.get_global_transform()
			var control_rect: Rect2 = Rect2(local_control_transform.origin, overlay_control.size)
			if control_rect.has_point(surface_local_position):
				return true
	return false


func _handle_surface_mouse_button(event: InputEventMouseButton) -> void:
	if player_surface == null:
		return
	var local_event: InputEventMouseButton = player_surface.make_input_local(event) as InputEventMouseButton
	var surface_local: Vector2 = local_event.position
	if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if not event.pressed:
			return
		if surface_local.x < 0.0 or surface_local.y < 0.0 or surface_local.x > player_surface.size.x or surface_local.y > player_surface.size.y:
			return
		if _is_overlay_control_at(surface_local):
			return
		var wheel_zoom_factor: float = 1.1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1
		_set_player_zoom(player_zoom * wheel_zoom_factor)
		get_viewport().set_input_as_handled()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		if surface_local.x < 0.0 or surface_local.y < 0.0 or surface_local.x > player_surface.size.x or surface_local.y > player_surface.size.y:
			mouse_gesture_active = false
			mouse_last_click_time = 0
			return
		if _is_overlay_control_at(surface_local):
			mouse_gesture_active = false
			mouse_last_click_time = 0
			return
		mouse_gesture_active = true
		mouse_gesture_mode = ""
		mouse_press_position = surface_local
		mouse_last_position = surface_local
		mouse_press_was_dragged = false
		var now_ms: int = Time.get_ticks_msec()
		var repeated_click: bool = mouse_last_click_time > 0 and now_ms - mouse_last_click_time <= DOUBLE_TAP_INTERVAL_MS and mouse_last_click_position.distance_to(surface_local) <= DOUBLE_TAP_DISTANCE
		if local_event.double_click or repeated_click:
			_handle_double_tap(surface_local)
			mouse_last_click_time = 0
			mouse_native_double_handled = true
			get_viewport().set_input_as_handled()
		else:
			mouse_native_double_handled = false
	else:
		if not mouse_gesture_active:
			return
		if mouse_native_double_handled:
			mouse_native_double_handled = false
		elif not mouse_press_was_dragged:
			mouse_last_click_time = Time.get_ticks_msec()
			mouse_last_click_position = surface_local
		else:
			mouse_last_click_time = 0
		mouse_gesture_active = false


func _handle_surface_mouse_motion(event: InputEventMouseMotion) -> void:
	if player_surface == null or not mouse_gesture_active:
		return
	var local_event: InputEventMouseMotion = player_surface.make_input_local(event) as InputEventMouseMotion
	var local_delta: Vector2 = local_event.relative
	if local_event.position.distance_to(mouse_press_position) >= DOUBLE_TAP_DISTANCE:
		mouse_press_was_dragged = true
	if mouse_gesture_mode.is_empty():
		if absf(local_delta.y) < absf(local_delta.x) * 1.2:
			return
		var gesture_start: Vector2 = mouse_press_position
		if gesture_start.x <= player_surface.size.x * 0.4:
			mouse_gesture_mode = "brightness"
		elif gesture_start.x >= player_surface.size.x * 0.6:
			mouse_gesture_mode = "volume"
		else:
			mouse_gesture_mode = "none"
	var normalized_delta: float = -local_delta.y / maxf(player_surface.size.y, 1.0)
	match mouse_gesture_mode:
		"brightness":
			brightness_level = clampf(brightness_level + normalized_delta * 1.5, 0.0, 2.0)
			_on_brightness_changed(brightness_level)
		"volume":
			volume_level = clampf(volume_level + normalized_delta, 0.0, 1.0)
			_on_volume_changed(volume_level)
	mouse_last_position = local_event.position
	get_viewport().set_input_as_handled()


func _screen_to_surface_local(screen_position: Vector2) -> Vector2:
	if player_surface == null:
		return Vector2.ZERO
	var canvas_position: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen_position
	return player_surface.get_global_transform().affine_inverse() * canvas_position


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if player_surface == null:
		return
	if event.pressed:
		var surface_local: Vector2 = _screen_to_surface_local(event.position)
		if surface_local.x < 0.0 or surface_local.y < 0.0 or surface_local.x > player_surface.size.x or surface_local.y > player_surface.size.y:
			return
		if _is_overlay_control_at(surface_local):
			get_viewport().set_input_as_handled()
			return
		if event.double_tap and touch_points.is_empty():
			_handle_double_tap(surface_local)
			get_viewport().set_input_as_handled()
		touch_points[event.index] = event.position
		touch_start_positions[event.index] = event.position
		if touch_points.size() == 1:
			touch_gesture_mode = ""
		elif touch_points.size() == 2:
			var points: Array[Vector2] = []
			for point: Vector2 in touch_points.values():
				points.append(point)
			pinch_start_distance = points[0].distance_to(points[1])
			pinch_start_zoom = player_zoom
			touch_gesture_mode = "pinch"
		else:
			touch_gesture_mode = ""
	else:
		touch_points.erase(event.index)
		touch_start_positions.erase(event.index)
		if touch_points.is_empty():
			touch_gesture_mode = ""
		elif touch_points.size() == 1:
			touch_gesture_mode = ""


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if not touch_points.has(event.index) or player_surface == null:
		return
	var drag_surface_local: Vector2 = _screen_to_surface_local(event.position)
	if _is_overlay_control_at(drag_surface_local):
		return
	touch_points[event.index] = event.position
	if touch_points.size() >= 2:
		var points: Array[Vector2] = []
		for point: Vector2 in touch_points.values():
			points.append(point)
		if points.size() >= 2:
			var distance: float = points[0].distance_to(points[1])
			if pinch_start_distance > 1.0:
				_set_player_zoom(pinch_start_zoom * distance / pinch_start_distance)
				touch_gesture_mode = "pinch"
				get_viewport().set_input_as_handled()
		return
	if touch_gesture_mode == "pinch":
		return
	var start_position: Vector2 = touch_start_positions.get(event.index, event.position)
	var local_start: Vector2 = _screen_to_surface_local(start_position)
	if touch_gesture_mode.is_empty():
		if absf(event.relative.y) < absf(event.relative.x) * 1.2:
			return
		if local_start.x <= player_surface.size.x * 0.4:
			touch_gesture_mode = "brightness"
		elif local_start.x >= player_surface.size.x * 0.6:
			touch_gesture_mode = "volume"
		else:
			touch_gesture_mode = "none"
	var local_delta: Vector2 = player_surface.get_global_transform().basis_xform_inv(event.relative)
	var normalized_delta: float = -local_delta.y / maxf(player_surface.size.y, 1.0)
	match touch_gesture_mode:
		"brightness":
			brightness_level = clampf(brightness_level + normalized_delta * 1.5, 0.0, 2.0)
			_on_brightness_changed(brightness_level)
		"volume":
			volume_level = clampf(volume_level + normalized_delta, 0.0, 1.0)
			_on_volume_changed(volume_level)
	get_viewport().set_input_as_handled()


func _on_overlay_timeline_drag_ended(changed: bool) -> void:
	overlay_timeline_dragging = false
	if changed and video_player != null and video_player.stream != null:
		video_player.stream_position = overlay_timeline.value


func _handle_double_tap(local_position: Vector2) -> void:
	if player_surface == null:
		return
	var horizontal_ratio: float = local_position.x / maxf(player_surface.size.x, 1.0)
	var vertical_ratio: float = local_position.y / maxf(player_surface.size.y, 1.0)
	var is_center_double_tap: bool = horizontal_ratio >= 0.30 and horizontal_ratio <= 0.70 and vertical_ratio >= 0.30 and vertical_ratio <= 0.70
	if is_center_double_tap:
		_toggle_playback()


func _toggle_playback() -> void:
	if video_player == null or video_player.stream == null:
		_update_gesture_hint("Load a video before starting playback")
		return
	video_player.paused = not video_player.paused
	_update_overlay_state()
	_update_gesture_hint("Paused" if video_player.paused else "Playing")


func _on_volume_changed(value: float) -> void:
	volume_level = clampf(value, 0.0, 1.0)
	if video_player != null:
		video_player.volume = volume_level
		video_player.volume_db = linear_to_db(maxf(volume_level, 0.0001))
	_update_gesture_hint("Volume %d%%" % int(round(volume_level * 100.0)))


func _on_brightness_changed(value: float) -> void:
	brightness_level = clampf(value, 0.2, 1.8)
	var brightness_tint: Color = Color(brightness_level, brightness_level, brightness_level, 1.0)
	if video_player != null:
		video_player.modulate = brightness_tint
	if artwork != null:
		artwork.modulate = brightness_tint
	_update_gesture_hint("Brightness %d%%" % int(round(brightness_level * 100.0)))


func _update_responsive_layout() -> void:
	if content_row == null or content_scroll == null:
		return
	var available_size: Vector2 = get_viewport().get_visible_rect().size
	if available_size.x <= 0.0 or available_size.y <= 0.0:
		return
	var phone: bool = available_size.x < PHONE_BREAKPOINT
	var portrait: bool = available_size.x < available_size.y or available_size.x < PORTRAIT_BREAKPOINT
	is_phone_layout = phone
	is_portrait_layout = portrait
	content_row.vertical = portrait
	content_row.add_theme_constant_override("separation", 12 if phone else 20)
	var sidebar: Control = content_row.get_child(1) as Control
	sidebar.custom_minimum_size = Vector2(0.0, 330.0 if phone else 420.0) if portrait else Vector2(SIDEBAR_WIDTH, 0.0)
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL if portrait else Control.SIZE_SHRINK_END
	sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	featured_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	featured_column.size_flags_vertical = Control.SIZE_FILL if portrait else Control.SIZE_EXPAND_FILL
	var player_frame: Control = featured_column.get_child(0) as Control
	player_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var horizontal_insets: float = 20.0 if phone else 44.0
	var sidebar_inset: float = 0.0 if portrait else SIDEBAR_WIDTH + 20.0
	var available_player_width: float = maxf(1.0, available_size.x - horizontal_insets - sidebar_inset - 2.0)
	var aspect_ratio: float = clampf(video_aspect_ratio, 0.5, 3.0)
	var target_player_height: float = clampf(available_player_width / aspect_ratio, 160.0, 560.0)
	if phone:
		target_player_height = minf(target_player_height, MOBILE_PLAYER_HEIGHT)
	if phone:
		player_stack.custom_minimum_size = Vector2(0.0, target_player_height)
		player_stack.custom_maximum_size = Vector2(4096.0, target_player_height)
		player_stack.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	else:
		player_stack.custom_minimum_size = Vector2(0.0, 0.0)
		player_stack.custom_maximum_size = Vector2(4096.0, 4096.0)
		player_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	player_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var details: Control = featured_column.get_child(1) as Control
	details.custom_minimum_size.y = 64.0
	details.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	video_aspect_container.custom_minimum_size = Vector2.ZERO
	video_aspect_container.size_flags_horizontal = Control.SIZE_FILL
	video_aspect_container.size_flags_vertical = Control.SIZE_FILL
	var margin_container: MarginContainer = get_node("Margin") as MarginContainer
	_fill_rect(margin_container)
	margin_container.add_theme_constant_override("margin_left", 10 if phone else 22)
	margin_container.add_theme_constant_override("margin_right", 10 if phone else 22)
	margin_container.add_theme_constant_override("margin_top", 8 if phone else 16)
	margin_container.add_theme_constant_override("margin_bottom", 8 if phone else 16)
	header_spacer.visible = not phone
	guest_label.visible = not phone
	library_heading.text = "VIDEO LIBRARY" if phone else "ON THIS DEVICE"
	library_search.custom_minimum_size.y = MOBILE_TOUCH_TARGET if phone else 38.0
	library_scroll.custom_minimum_size.y = 0.0
	library_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.queue_sort()
	content_scroll.queue_sort()
	if phone:
		_set_mobile_control_sizes()
	else:
		_set_desktop_control_sizes()


func _set_mobile_control_sizes() -> void:
	var paths: Array[NodePath] = [
		"Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/TopBar/BackButton",
		"Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/TopBar/HDRButton",
		"Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/TopBar/CaptionsButton",
		"Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/TopBar/AudioButton",
		"Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/TopBar/MenuButton",
		"Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/BottomBar/OverlayPlayButton",
		"Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/BottomBar/RewindButton",
		"Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/BottomBar/ForwardButton",
		"Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/BottomBar/OverlaySpeedButton",
		"Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/BottomBar/FullscreenButton",
	]
	for path: NodePath in paths:
		var button: Button = get_node(path) as Button
		button.custom_minimum_size = Vector2(maxf(button.custom_minimum_size.x, MOBILE_TOUCH_TARGET), MOBILE_TOUCH_TARGET)
	top_bar.add_theme_constant_override("separation", 2)
	bottom_bar.add_theme_constant_override("separation", 2)
	library_toolbar.add_theme_constant_override("separation", 4)
	library_heading.add_theme_font_size_override("font_size", 20)
	scan_button.text = "Scan"
	scan_button.custom_minimum_size = Vector2(74, MOBILE_TOUCH_TARGET)
	bottom_spacer.hide()
	speed_label.hide()
	overlay_timeline.custom_minimum_size.y = 40


func _set_desktop_control_sizes() -> void:
	var paths: Array[NodePath] = [
		"Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/TopBar/BackButton",
		"Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/TopBar/HDRButton",
		"Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/TopBar/CaptionsButton",
		"Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/TopBar/AudioButton",
		"Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/TopBar/MenuButton",
		"Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/BottomBar/OverlayPlayButton",
		"Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/BottomBar/RewindButton",
		"Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/BottomBar/ForwardButton",
		"Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/BottomBar/OverlaySpeedButton",
		"Margin/Page/ContentScroll/ContentRow/FeaturedColumn/PlayerFrame/PlayerStack/VideoAspectContainer/PlayerSurface/BottomBar/FullscreenButton",
	]
	for path: NodePath in paths:
		var button: Button = get_node_or_null(path) as Button
		if button != null:
			button.custom_minimum_size = Vector2.ZERO
	top_bar.add_theme_constant_override("separation", 6)
	bottom_bar.add_theme_constant_override("separation", 6)
	library_toolbar.add_theme_constant_override("separation", 3)
	library_heading.text = "LIBRARY"
	library_heading.add_theme_font_size_override("font_size", 20)
	scan_button.text = "Scan"
	scan_button.custom_minimum_size = Vector2(52, 36)
	bottom_spacer.show()
	speed_label.show()
	overlay_timeline.custom_minimum_size.y = 30
