extends SceneTree
## Headless check that the plugin loads, puts its toggle in the 3D toolbar,
## and that the controller takes over and restores the editor viewports.
## Run: godot --headless --editor --path . -s res://test/plugin_test.gd

const SolidViewController := preload("res://addons/solid_view/solid_view_controller.gd")

var _failures: int = 0


func _initialize() -> void:
	var watchdog := create_timer(30.0)
	watchdog.timeout.connect(func() -> void:
		print("WATCHDOG: test did not finish")
		quit(2))
	_run()


func _run() -> void:
	await process_frame
	await process_frame

	var viewport := EditorInterface.get_editor_viewport_3d(0)
	var camera := viewport.get_camera_3d()
	_check(camera != null, "the editor viewport has a camera")
	var msaa_before := viewport.msaa_3d
	var env_before := camera.environment

	var controller := SolidViewController.new()
	controller.active = true
	_check(camera.environment == controller.environment, "camera takes the solid environment")
	_check(camera.compositor == controller.compositor, "camera takes the compositor")
	_check(viewport.msaa_3d == Viewport.MSAA_DISABLED, "MSAA is off while active")
	_check(viewport.debug_draw == Viewport.DEBUG_DRAW_DISABLED, "flat colour draws normally")

	camera.environment = null
	viewport.msaa_3d = Viewport.MSAA_4X
	controller.apply()
	_check(camera.environment == controller.environment, "apply() puts the environment back after the editor resets it")
	_check(viewport.msaa_3d == Viewport.MSAA_DISABLED, "apply() puts MSAA off again")

	controller.texture_color = true
	controller.apply()
	_check(viewport.debug_draw == Viewport.DEBUG_DRAW_UNSHADED, "texture colour draws unshaded")

	controller.active = false
	_check(camera.environment == env_before, "environment restored")
	_check(camera.compositor == null, "compositor removed")
	_check(viewport.msaa_3d == msaa_before, "MSAA restored")
	_check(viewport.debug_draw == Viewport.DEBUG_DRAW_DISABLED, "debug draw restored")

	var toggle := EditorInterface.get_base_control().find_child("SolidViewToggle", true, false) as Button
	_check(toggle != null, "the Solid toggle is in the 3D toolbar")
	if toggle != null:
		toggle.button_pressed = true
		await process_frame
		_check(camera.environment != null and camera.environment != env_before, "the toggle turns solid view on")
		_check(camera.compositor != null, "the toggle attaches a compositor")
		toggle.button_pressed = false
		await process_frame
		_check(camera.environment == env_before, "the toggle turns it off again")

	var settings := EditorInterface.get_editor_settings()
	_check(settings.has_shortcut("solid_view/toggle"), "the shortcut is registered")

	print("FAILURES %d" % _failures)
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, what: String) -> void:
	if condition:
		print("PASS %s" % what)
	else:
		_failures += 1
		print("FAIL %s" % what)
