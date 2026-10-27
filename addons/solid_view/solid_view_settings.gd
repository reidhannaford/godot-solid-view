@tool
extends RefCounted
## The solid view options, kept in Editor Settings under solid_view/ so they
## follow the user between projects. Whether the view is on is not saved: it
## starts off, like a debug draw mode.

const PREFIX := "solid_view/"
const DEFAULT_MATCAP := "res://addons/solid_view/matcaps/clay.png"

var shading: int = 0 # SolidViewEffect.Shading
var texture_color: bool = false
var cavity: bool = true
var outline: bool = true
var matcap_path: String = DEFAULT_MATCAP


func load() -> void:
	var settings := EditorInterface.get_editor_settings()
	shading = _read(settings, "shading", shading, TYPE_INT, PROPERTY_HINT_ENUM, "Studio Lighting,MatCap")
	texture_color = _read(settings, "texture_color", texture_color, TYPE_BOOL)
	cavity = _read(settings, "cavity", cavity, TYPE_BOOL)
	outline = _read(settings, "outline", outline, TYPE_BOOL)
	matcap_path = _read(settings, "matcap", matcap_path, TYPE_STRING, PROPERTY_HINT_FILE, "*.png,*.jpg,*.jpeg,*.exr,*.webp")


func save() -> void:
	var settings := EditorInterface.get_editor_settings()
	settings.set_setting(PREFIX + "shading", shading)
	settings.set_setting(PREFIX + "texture_color", texture_color)
	settings.set_setting(PREFIX + "cavity", cavity)
	settings.set_setting(PREFIX + "outline", outline)
	settings.set_setting(PREFIX + "matcap", matcap_path)


## The matcap texture the settings name, or the bundled one if it won't load.
func load_matcap() -> Texture2D:
	var texture: Texture2D = null
	if ResourceLoader.exists(matcap_path):
		texture = ResourceLoader.load(matcap_path, "Texture2D") as Texture2D
	if texture == null and matcap_path != DEFAULT_MATCAP:
		push_warning("Solid View: can't load the matcap at %s; using the bundled one." % matcap_path)
		texture = ResourceLoader.load(DEFAULT_MATCAP, "Texture2D") as Texture2D
	return texture


static func _read(settings: EditorSettings, name: String, default: Variant, type: int, hint: int = PROPERTY_HINT_NONE, hint_string: String = "") -> Variant:
	var path := PREFIX + name
	if not settings.has_setting(path):
		settings.set_setting(path, default)
	settings.set_initial_value(path, default, false)
	settings.add_property_info({
		"name": path,
		"type": type,
		"hint": hint,
		"hint_string": hint_string,
	})
	return settings.get_setting(path)
