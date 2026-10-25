@tool
extends EditorPlugin


func _enable_plugin() -> void:
	# Add autoloads here.
	pass


func _disable_plugin() -> void:
	# Remove autoloads here.
	pass


func _enter_tree() -> void:
	if not ClassDB.class_exists("VideoStreamCodisVP"):
		push_warning("CodisVP: build the native extension first. See README.md.")


func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	pass
