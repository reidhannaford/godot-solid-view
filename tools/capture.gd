extends SceneTree
## Opens the test scene in a windowed editor and saves screenshots of the
## viewport with solid view off and in each mode, into docs/captures/.
## Run: godot --editor --resolution 1600x900 --path . -s res://tools/capture.gd

const SCENE := "res://test/test_scene.tscn"
const OUT_DIR := "res://docs/captures"
const SETTLE_FRAMES := 40


func _initialize() -> void:
	var watchdog := create_timer(120.0)
	watchdog.timeout.connect(func() -> void:
		print("WATCHDOG: capture did not finish")
		quit(2))
	_run()


func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	EditorInterface.open_scene_from_path(SCENE)
	var waited := 0
	while waited < 600:
		var root_node := EditorInterface.get_edited_scene_root()
		if root_node != null and root_node.scene_file_path == SCENE:
			break
		await process_frame
		waited += 1
	EditorInterface.set_main_screen_editor("3D")
	await _settle()
	_shot("before")

	var base := EditorInterface.get_base_control()
	var toggle := base.find_child("SolidViewToggle", true, false) as Button
	var menu := base.find_child("SolidViewMenu", true, false) as MenuButton
	if toggle == null or menu == null:
		print("FAIL: toolbar controls not found")
		quit(1)
		return
	var popup := menu.get_popup()
	# Item ids match plugin.gd's Item enum: 0 studio, 1 matcap, 2 flat,
	# 3 texture, 4 cavity, 5 outline, 7 x-ray, 8 crease lines; a bundled matcap
	# is picked by its label in the submenu. Cavity, outline, crease and x-ray are toggles and are
	# remembered in editor settings, so they are set to a wanted state.
	var sequence: Array[Array] = [
		["studio", [0, 2], true],
		["studio_texture", [3], true],
		["matcap", [1, 2], true, "Normal"],
		["matcap_texture", [3], true, "Clay"],
		["studio_plain", [0, 2], false],
	]
	toggle.button_pressed = true
	for step: Array in sequence:
		for id: int in step[1] as Array:
			popup.id_pressed.emit(id)
		if step.size() > 3:
			_pick_matcap(popup, step[3] as String)
		_set_checked(popup, 4, step[2] as bool)
		_set_checked(popup, 5, step[2] as bool)
		_set_checked(popup, 8, step[2] as bool)
		await _settle()
		_shot(step[0] as String)
	_set_checked(popup, 4, true)
	_set_checked(popup, 5, true)
	_set_checked(popup, 8, true)
	_set_checked(popup, 7, true)
	await _settle()
	_shot("studio_xray")
	_set_checked(popup, 7, false)
	_set_view_item("Orthogonal")
	await _settle()
	_shot("studio_ortho")
	_set_view_item("Perspective")
	await _settle()
	toggle.button_pressed = false
	await _settle()
	_shot("after")
	print("DONE")
	quit(0)


## Picks an item of the first editor viewport's view menu by its text, the
## way a click would.
func _set_view_item(text: String) -> void:
	var viewport := EditorInterface.get_editor_viewport_3d(0)
	var editor_viewport := viewport.get_parent().get_parent()
	for child: Node in editor_viewport.find_children("*", "MenuButton", true, false):
		var menu := child as MenuButton
		var view_popup := menu.get_popup()
		for index: int in view_popup.item_count:
			if view_popup.get_item_text(index) == text:
				view_popup.id_pressed.emit(view_popup.get_item_id(index))
				return
	print("FAIL: view menu item %s not found" % text)


## Picks a bundled matcap by its label in the Bundled MatCaps submenu.
func _pick_matcap(popup: PopupMenu, label: String) -> void:
	var submenu := popup.get_node_or_null("SolidViewMatcaps") as PopupMenu
	if submenu == null:
		print("FAIL: matcap submenu not found")
		return
	for index: int in submenu.item_count:
		if submenu.get_item_text(index) == label:
			submenu.id_pressed.emit(submenu.get_item_id(index))
			return
	print("FAIL: bundled matcap %s not found" % label)


## Presses a check item only if it isn't already in the wanted state.
func _set_checked(popup: PopupMenu, id: int, wanted: bool) -> void:
	if popup.is_item_checked(popup.get_item_index(id)) != wanted:
		popup.id_pressed.emit(id)


func _settle() -> void:
	for i: int in SETTLE_FRAMES:
		await process_frame


func _shot(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, name]
	var error := image.save_png(path)
	print("shot %s (%s)" % [path, error_string(error)])
