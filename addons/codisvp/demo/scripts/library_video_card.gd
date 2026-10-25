class_name LibraryVideoCard
extends Button

signal selected(path: String)
signal double_clicked(path: String)

@onready var title_label: Label = $CardRow/Description/EpisodeTitle
@onready var type_label: Label = $CardRow/Description/Genre
@onready var path_label: Label = $CardRow/Description/Metadata
@onready var thumbnail_button: TextureButton = $CardRow/Thumbnail

var file_path: String = ""
var file_extension: String = ""
var is_registered: bool = false
var search_text: String = ""
var thumbnail_requested: bool = false
var thumbnail_loading: bool = false
var thumbnail_generation: int = 0
static var thumbnail_cache: Dictionary[String, Texture2D] = {}


func _ready() -> void:
	thumbnail_button.pressed.connect(_on_thumbnail_pressed)
	if not file_path.is_empty():
		configure_video(file_path, file_extension, is_registered)


func configure_video(path: String, extension: String, is_supported: bool) -> void:
	file_path = path
	file_extension = extension
	is_registered = is_supported
	search_text = (path.get_file().get_basename() + " " + extension + " " + path.get_base_dir()).to_lower()
	if not is_node_ready():
		return
	title_label.text = path.get_file().get_basename()
	type_label.text = ("VIDEO FILE · " if is_supported else "UNREGISTERED · ") + extension.to_upper()
	type_label.add_theme_color_override("font_color", Color("#28c8b5") if is_supported else Color("#edb85c"))
	path_label.text = path.get_base_dir()
	tooltip_text = path + ("\nThe extension is registered with a VideoStream loader. The actual codecs may still be incompatible." if is_supported else "\nThe extension is not registered with a VideoStream loader.")
	thumbnail_button.texture_normal = thumbnail_cache.get(path, load("res://assets/generated/streamflow_astria.png") as Texture2D)
	thumbnail_button.tooltip_text = "Preview loads when this card scrolls into view."


func request_thumbnail() -> void:
	if thumbnail_requested or thumbnail_loading or not is_registered or file_path.is_empty():
		return
	if thumbnail_cache.has(file_path):
		thumbnail_button.texture_normal = thumbnail_cache[file_path]
		return
	if not ClassDB.class_exists("VideoStreamCodisVP"):
		return
	thumbnail_requested = true
	thumbnail_loading = true
	thumbnail_generation += 1
	_generate_preview(file_path, thumbnail_generation)


func _generate_preview(path: String, generation: int) -> void:
	thumbnail_button.tooltip_text = "Generating video preview..."
	var preview: Texture2D = await VideoThumbnail.extract(path)
	if not is_instance_valid(self) or file_path != path or thumbnail_generation != generation:
		return
	thumbnail_loading = false
	if preview != null:
		thumbnail_cache[path] = preview
		thumbnail_button.texture_normal = preview
		thumbnail_button.tooltip_text = "Video preview: " + path.get_file()
	else:
		thumbnail_button.tooltip_text = "Preview unavailable; double-click to attempt playback."

func _on_thumbnail_pressed() -> void:
	double_clicked.emit(file_path)
