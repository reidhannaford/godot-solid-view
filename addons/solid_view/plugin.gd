@tool
extends EditorPlugin
## Adds a Solid toggle and its options menu to the 3D editor toolbar, and a
## shortcut (solid_view/toggle, Alt+Z by default) to flip it.

const SolidViewController := preload("solid_view_controller.gd")
const SolidViewSettings := preload("solid_view_settings.gd")
const SolidViewEffect := preload("solid_view_effect.gd")

const SHORTCUT_PATH := "solid_view/toggle"

enum Item { STUDIO, MATCAP, FLAT, TEXTURE, CAVITY, OUTLINE, CHOOSE_MATCAP, DEFAULT_MATCAP }

var _controller: SolidViewController
var _settings: SolidViewSettings
var _bar: HBoxContainer
var _toggle: Button
var _menu: MenuButton
var _file_dialog: EditorFileDialog


func _enter_tree() -> void:
	_register_shortcut()
	_settings = SolidViewSettings.new()
	_settings.load()
	_controller = SolidViewController.new()
	_apply_settings()

	_bar = HBoxContainer.new()
	_toggle = Button.new()
	_toggle.name = "SolidViewToggle"
	_toggle.text = "Solid"
	_toggle.toggle_mode = true
	_toggle.flat = true
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.icon = EditorInterface.get_editor_theme().get_icon(&"SphereMesh", &"EditorIcons")
	_toggle.toggled.connect(_on_toggled)
	_bar.add_child(_toggle)
	_menu = MenuButton.new()
	_menu.name = "SolidViewMenu"
	_menu.flat = true
	_menu.focus_mode = Control.FOCUS_NONE
	_menu.icon = EditorInterface.get_editor_theme().get_icon(&"GuiTabMenuHl", &"EditorIcons")
	_menu.tooltip_text = "Solid View options"
	_menu.get_popup().id_pressed.connect(_on_menu_pressed)
	_menu.about_to_popup.connect(_refresh_menu)
	_bar.add_child(_menu)
	_refresh_menu()
	_update_tooltip()
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, _bar)
	set_input_event_forwarding_always_enabled()


func _exit_tree() -> void:
	if _controller != null:
		_controller.active = false
	if _bar != null:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, _bar)
		_bar.free()
	_bar = null
	_toggle = null
	_menu = null
	if _file_dialog != null:
		_file_dialog.queue_free()
	_file_dialog = null
	_controller = null


func _process(_delta: float) -> void:
	if _controller != null:
		_controller.apply()


func _forward_3d_gui_input(_viewport_camera: Camera3D, event: InputEvent) -> int:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return AFTER_GUI_INPUT_PASS
	var settings := EditorInterface.get_editor_settings()
	if settings.has_shortcut(SHORTCUT_PATH) and settings.get_shortcut(SHORTCUT_PATH).matches_event(event):
		_toggle.button_pressed = not _toggle.button_pressed
		return AFTER_GUI_INPUT_STOP
	return AFTER_GUI_INPUT_PASS


func _register_shortcut() -> void:
	var settings := EditorInterface.get_editor_settings()
	if settings.has_shortcut(SHORTCUT_PATH):
		return
	var key := InputEventKey.new()
	key.keycode = KEY_Z
	key.alt_pressed = true
	var shortcut := Shortcut.new()
	shortcut.resource_name = "Toggle Solid View"
	shortcut.events = [key]
	settings.add_shortcut(SHORTCUT_PATH, shortcut)


func _apply_settings() -> void:
	var effect := _controller.effect
	effect.shading = _settings.shading as SolidViewEffect.Shading
	effect.cavity = 1.0 if _settings.cavity else 0.0
	effect.outline = 1.0 if _settings.outline else 0.0
	effect.matcap = _settings.load_matcap()
	_controller.texture_color = _settings.texture_color


func _on_toggled(on: bool) -> void:
	_controller.active = on


func _refresh_menu() -> void:
	var popup := _menu.get_popup()
	popup.clear()
	popup.add_radio_check_item("Studio Lighting", Item.STUDIO)
	popup.add_radio_check_item("MatCap", Item.MATCAP)
	popup.add_separator()
	popup.add_radio_check_item("Flat Colour", Item.FLAT)
	popup.add_radio_check_item("Texture Colour", Item.TEXTURE)
	popup.add_separator()
	popup.add_check_item("Cavity", Item.CAVITY)
	popup.add_check_item("Outline", Item.OUTLINE)
	popup.add_separator()
	popup.add_item("Choose MatCap…", Item.CHOOSE_MATCAP)
	popup.add_item("Use Bundled MatCap", Item.DEFAULT_MATCAP)
	popup.set_item_checked(popup.get_item_index(Item.STUDIO), _settings.shading == SolidViewEffect.Shading.STUDIO)
	popup.set_item_checked(popup.get_item_index(Item.MATCAP), _settings.shading == SolidViewEffect.Shading.MATCAP)
	popup.set_item_checked(popup.get_item_index(Item.FLAT), not _settings.texture_color)
	popup.set_item_checked(popup.get_item_index(Item.TEXTURE), _settings.texture_color)
	popup.set_item_checked(popup.get_item_index(Item.CAVITY), _settings.cavity)
	popup.set_item_checked(popup.get_item_index(Item.OUTLINE), _settings.outline)
	popup.set_item_disabled(popup.get_item_index(Item.DEFAULT_MATCAP), _settings.matcap_path == SolidViewSettings.DEFAULT_MATCAP)


func _on_menu_pressed(id: int) -> void:
	match id:
		Item.STUDIO:
			_settings.shading = SolidViewEffect.Shading.STUDIO
		Item.MATCAP:
			_settings.shading = SolidViewEffect.Shading.MATCAP
		Item.FLAT:
			_settings.texture_color = false
		Item.TEXTURE:
			_settings.texture_color = true
		Item.CAVITY:
			_settings.cavity = not _settings.cavity
		Item.OUTLINE:
			_settings.outline = not _settings.outline
		Item.CHOOSE_MATCAP:
			_choose_matcap()
			return
		Item.DEFAULT_MATCAP:
			_settings.matcap_path = SolidViewSettings.DEFAULT_MATCAP
			_settings.shading = SolidViewEffect.Shading.MATCAP
	_settings.save()
	_apply_settings()
	_update_tooltip()


func _choose_matcap() -> void:
	if _file_dialog == null:
		_file_dialog = EditorFileDialog.new()
		_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
		_file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
		_file_dialog.title = "Choose a MatCap image"
		_file_dialog.add_filter("*.png, *.jpg, *.jpeg, *.exr, *.webp", "Images")
		_file_dialog.file_selected.connect(_on_matcap_chosen)
		EditorInterface.get_base_control().add_child(_file_dialog)
	_file_dialog.current_path = _settings.matcap_path
	_file_dialog.popup_file_dialog()


func _on_matcap_chosen(path: String) -> void:
	_settings.matcap_path = path
	_settings.shading = SolidViewEffect.Shading.MATCAP
	_settings.save()
	_apply_settings()
	_update_tooltip()


func _update_tooltip() -> void:
	var shortcut_text := ""
	var settings := EditorInterface.get_editor_settings()
	if settings.has_shortcut(SHORTCUT_PATH):
		shortcut_text = " (%s)" % settings.get_shortcut(SHORTCUT_PATH).get_as_text()
	var mode := "MatCap: %s" % _settings.matcap_path.get_file() if _settings.shading == SolidViewEffect.Shading.MATCAP else "Studio lighting"
	_toggle.tooltip_text = "Solid View%s\n%s, %s colour." % [shortcut_text, mode, "texture" if _settings.texture_color else "flat"]
