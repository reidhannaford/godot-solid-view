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
	# Item ids match plugin.gd's Item enum.
	var sequence: Array[Array] = [
		["studio", [0, 2]],
		["studio_texture", [3]],
		["matcap", [1, 2]],
		["matcap_texture", [3]],
		["studio_plain", [0, 2, 4, 5]],
	]
	toggle.button_pressed = true
	for step: Array in sequence:
		for id: int in step[1] as Array:
			popup.id_pressed.emit(id)
		await _settle()
		_shot(step[0] as String)
	toggle.button_pressed = false
	await _settle()
	_shot("after")
	print("DONE")
	quit(0)


func _settle() -> void:
	for i: int in SETTLE_FRAMES:
		await process_frame


func _shot(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, name]
	var error := image.save_png(path)
	print("shot %s (%s)" % [path, error_string(error)])
