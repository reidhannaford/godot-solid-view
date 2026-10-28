@tool
extends EditorPlugin
## Adds a Workbench toggle and its options menu to the 3D editor toolbar, and a
## shortcut (workbench/toggle, Alt+Z by default) to flip it, and another
## (workbench/toggle_xray, Alt+Shift+Z) for x-ray.

const WorkbenchController := preload("workbench_controller.gd")
const WorkbenchSettings := preload("workbench_settings.gd")
const WorkbenchEffect := preload("workbench_effect.gd")

const SHORTCUT_PATH := "workbench/toggle"
const XRAY_SHORTCUT_PATH := "workbench/toggle_xray"

enum Item { STUDIO, MATCAP, FLAT, TEXTURE, CAVITY, OUTLINE, CHOOSE_MATCAP, XRAY, CREASE }
## Ids of the bundled matcaps in their submenu: this plus their index.
const MATCAP_ID_BASE := 100

var _controller: WorkbenchController
var _settings: WorkbenchSettings
var _bar: HBoxContainer
var _toggle: Button
var _menu: MenuButton
var _matcap_menu: PopupMenu
var _file_dialog: EditorFileDialog


func _enter_tree() -> void:
	_register_shortcuts()
	_settings = WorkbenchSettings.new()
	_settings.load()
	_controller = WorkbenchController.new()
	_apply_settings()

	_bar = HBoxContainer.new()
	_toggle = Button.new()
	_toggle.name = "WorkbenchToggle"
	_toggle.text = "Workbench"
	_toggle.toggle_mode = true
	_toggle.flat = true
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.icon = EditorInterface.get_editor_theme().get_icon(&"SphereMesh", &"EditorIcons")
	_toggle.toggled.connect(_on_toggled)
	_bar.add_child(_toggle)
	_menu = MenuButton.new()
	_menu.name = "WorkbenchMenu"
	_menu.flat = true
	_menu.focus_mode = Control.FOCUS_NONE
	_menu.icon = EditorInterface.get_editor_theme().get_icon(&"GuiTabMenuHl", &"EditorIcons")
	_menu.tooltip_text = "Workbench options"
	_menu.get_popup().id_pressed.connect(_on_menu_pressed)
	# Ticking an option keeps the menu open, so several can be changed in one
	# go; only "Choose MatCap…" and the like close it.
	_menu.get_popup().hide_on_checkable_item_selection = false
	_bar.add_child(_menu)
	_build_menu()
	_sync_menu()
	_update_tooltip()
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, _bar)
	set_input_event_forwarding_always_enabled()
	# Editor Settings > Workbench edits (the outline width, the x-ray
	# opacity) take effect at once.
	EditorInterface.get_editor_settings().settings_changed.connect(_on_settings_changed)


func _exit_tree() -> void:
	var editor_settings := EditorInterface.get_editor_settings()
	if editor_settings.settings_changed.is_connected(_on_settings_changed):
		editor_settings.settings_changed.disconnect(_on_settings_changed)
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


func _forward_3d_gui_input(_viewport_camera: Camera3D, event: InputEvent) -> int:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return AFTER_GUI_INPUT_PASS
	var settings := EditorInterface.get_editor_settings()
	if settings.has_shortcut(SHORTCUT_PATH) and settings.get_shortcut(SHORTCUT_PATH).matches_event(event):
		_toggle.button_pressed = not _toggle.button_pressed
		return AFTER_GUI_INPUT_STOP
	if settings.has_shortcut(XRAY_SHORTCUT_PATH) and settings.get_shortcut(XRAY_SHORTCUT_PATH).matches_event(event):
		_on_menu_pressed(Item.XRAY)
		if _settings.xray and not _toggle.button_pressed:
			_toggle.button_pressed = true
		return AFTER_GUI_INPUT_STOP
	return AFTER_GUI_INPUT_PASS


func _register_shortcuts() -> void:
	_register_shortcut(SHORTCUT_PATH, "Toggle Workbench", false)
	_register_shortcut(XRAY_SHORTCUT_PATH, "Toggle Workbench X-Ray", true)


func _register_shortcut(path: String, label: String, shift: bool) -> void:
	var settings := EditorInterface.get_editor_settings()
	if settings.has_shortcut(path):
		return
	var key := InputEventKey.new()
	key.keycode = KEY_Z
	key.alt_pressed = true
	key.shift_pressed = shift
	var shortcut := Shortcut.new()
	shortcut.resource_name = label
	shortcut.events = [key]
	settings.add_shortcut(path, shortcut)


func _apply_settings() -> void:
	var effect := _controller.effect
	effect.shading = _settings.shading as WorkbenchEffect.Shading
	effect.cavity = 1.0 if _settings.cavity else 0.0
	effect.outline = 1.0 if _settings.outline else 0.0
	# The width is in points; the viewport has editor-scale pixels per point.
	effect.outline_width = _settings.outline_width * EditorInterface.get_editor_scale()
	effect.crease = _settings.crease
	effect.matcap = _settings.load_matcap()
	_controller.texture_color = _settings.texture_color
	_controller.xray = _settings.xray
	_controller.xray_alpha = _settings.xray_alpha


func _on_settings_changed() -> void:
	if _settings == null or _controller == null or _menu == null:
		return
	_settings.load()
	_apply_settings()
	_sync_menu()
	_update_tooltip()


func _on_toggled(on: bool) -> void:
	_controller.active = on


func _build_menu() -> void:
	var popup := _menu.get_popup()
	popup.add_radio_check_item("Studio Lighting", Item.STUDIO)
	popup.add_radio_check_item("MatCap", Item.MATCAP)
	popup.add_separator()
	popup.add_radio_check_item("Flat Colour", Item.FLAT)
	popup.add_radio_check_item("Texture Colour", Item.TEXTURE)
	popup.add_separator()
	popup.add_check_item("Cavity", Item.CAVITY)
	popup.add_check_item("Outline", Item.OUTLINE)
	popup.add_check_item("Crease Lines", Item.CREASE)
	popup.add_separator()
	popup.add_check_item("X-Ray", Item.XRAY)
	popup.add_separator()
	_matcap_menu = PopupMenu.new()
	_matcap_menu.name = "WorkbenchMatcaps"
	_matcap_menu.hide_on_checkable_item_selection = false
	var index := 0
	for label: String in WorkbenchSettings.BUNDLED_MATCAPS:
		_matcap_menu.add_radio_check_item(label, MATCAP_ID_BASE + index)
		index += 1
	_matcap_menu.id_pressed.connect(_on_matcap_menu_pressed)
	popup.add_submenu_node_item("Bundled MatCaps", _matcap_menu)
	popup.add_item("Choose MatCap…", Item.CHOOSE_MATCAP)


## Shows the current settings on the menu items; the menu may be open.
func _sync_menu() -> void:
	var popup := _menu.get_popup()
	popup.set_item_checked(popup.get_item_index(Item.STUDIO), _settings.shading == WorkbenchEffect.Shading.STUDIO)
	popup.set_item_checked(popup.get_item_index(Item.MATCAP), _settings.shading == WorkbenchEffect.Shading.MATCAP)
	popup.set_item_checked(popup.get_item_index(Item.FLAT), not _settings.texture_color)
	popup.set_item_checked(popup.get_item_index(Item.TEXTURE), _settings.texture_color)
	popup.set_item_checked(popup.get_item_index(Item.CAVITY), _settings.cavity)
	popup.set_item_checked(popup.get_item_index(Item.OUTLINE), _settings.outline)
	popup.set_item_checked(popup.get_item_index(Item.CREASE), _settings.crease)
	popup.set_item_disabled(popup.get_item_index(Item.CREASE), not _settings.outline)
	popup.set_item_checked(popup.get_item_index(Item.XRAY), _settings.xray)
	var index := 0
	for label: String in WorkbenchSettings.BUNDLED_MATCAPS:
		_matcap_menu.set_item_checked(_matcap_menu.get_item_index(MATCAP_ID_BASE + index), _settings.matcap_path == WorkbenchSettings.BUNDLED_MATCAPS[label])
		index += 1


func _on_menu_pressed(id: int) -> void:
	match id:
		Item.STUDIO:
			_settings.shading = WorkbenchEffect.Shading.STUDIO
		Item.MATCAP:
			_settings.shading = WorkbenchEffect.Shading.MATCAP
		Item.FLAT:
			_settings.texture_color = false
		Item.TEXTURE:
			_settings.texture_color = true
		Item.CAVITY:
			_settings.cavity = not _settings.cavity
		Item.OUTLINE:
			_settings.outline = not _settings.outline
		Item.CREASE:
			_settings.crease = not _settings.crease
		Item.XRAY:
			_settings.xray = not _settings.xray
		Item.CHOOSE_MATCAP:
			_choose_matcap()
			return
	_settings.save()
	_apply_settings()
	_sync_menu()
	_update_tooltip()


func _on_matcap_menu_pressed(id: int) -> void:
	var labels := WorkbenchSettings.BUNDLED_MATCAPS.keys()
	var index := id - MATCAP_ID_BASE
	if index < 0 or index >= labels.size():
		return
	_settings.matcap_path = WorkbenchSettings.BUNDLED_MATCAPS[labels[index] as String]
	_settings.shading = WorkbenchEffect.Shading.MATCAP
	_settings.save()
	_apply_settings()
	_sync_menu()
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
	_settings.shading = WorkbenchEffect.Shading.MATCAP
	_settings.save()
	_apply_settings()
	_sync_menu()
	_update_tooltip()


func _update_tooltip() -> void:
	var shortcut_text := ""
	var settings := EditorInterface.get_editor_settings()
	if settings.has_shortcut(SHORTCUT_PATH):
		shortcut_text = " (%s)" % settings.get_shortcut(SHORTCUT_PATH).get_as_text()
	var mode := "MatCap: %s" % _settings.matcap_path.get_file() if _settings.shading == WorkbenchEffect.Shading.MATCAP else "Studio lighting"
	var xray_text := ""
	if settings.has_shortcut(XRAY_SHORTCUT_PATH):
		xray_text = "\nX-ray: %s (%s)." % ["on" if _settings.xray else "off", settings.get_shortcut(XRAY_SHORTCUT_PATH).get_as_text()]
	_toggle.tooltip_text = "Workbench%s\n%s, %s colour.%s" % [shortcut_text, mode, "texture" if _settings.texture_color else "flat", xray_text]
