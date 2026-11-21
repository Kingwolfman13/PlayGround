extends RefCounted
class_name SaveSystem

const SAVE_PATH := "user://petersburg_save.json"
const SAVE_VERSION := 1

static func save_data(data: Dictionary) -> bool:
	var payload := data.duplicate(true)
	payload["version"] = SAVE_VERSION
	payload["saved_at"] = Time.get_datetime_string_from_system()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not open save file: %s" % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true

static func load_data() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed as Dictionary

static func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
