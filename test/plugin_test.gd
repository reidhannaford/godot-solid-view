extends SceneTree
## Headless check that the plugin loads, puts its toggle in the 3D toolbar,
## and that the controller takes over the editor viewports only for a draw
## and restores them.
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
	var debug_draw_before := viewport.debug_draw

	var controller := SolidViewController.new()
	controller.active = true
	_check(viewport.msaa_3d == Viewport.MSAA_DISABLED, "MSAA is off while active")
	_check(camera.environment == env_before, "between frames the camera keeps the editor's environment")
	_check(camera.compositor == null, "between frames the camera has no compositor")
	_check(RenderingServer.frame_pre_draw.is_connected(controller.before_draw), "before_draw is hooked to frame_pre_draw")
	_check(RenderingServer.frame_post_draw.is_connected(controller.after_draw), "after_draw is hooked to frame_post_draw")

	controller.before_draw()
	_check(camera.environment == controller.environment, "the draw gets the solid environment")
	_check(camera.compositor == controller.compositor, "the draw gets the compositor")
	_check(viewport.debug_draw == Viewport.DEBUG_DRAW_DISABLED, "flat colour draws normally")
	controller.after_draw()
	_check(camera.environment == env_before, "after the draw the environment is the editor's again")
	_check(camera.compositor == null, "after the draw the compositor is gone")
	_check(viewport.debug_draw == debug_draw_before, "after the draw the debug draw is the editor's again")

	viewport.msaa_3d = Viewport.MSAA_4X
	controller.texture_color = true
	controller.before_draw()
	_check(viewport.msaa_3d == Viewport.MSAA_DISABLED, "before_draw puts MSAA off again after the editor resets it")
	_check(viewport.debug_draw == Viewport.DEBUG_DRAW_UNSHADED, "texture colour draws unshaded")
	controller.after_draw()
	_check(viewport.debug_draw == debug_draw_before, "debug draw restored after an unshaded draw")

	controller.before_draw()
	controller.active = false
	_check(camera.environment == env_before, "deactivating mid-draw restores the environment")
	_check(camera.compositor == null, "deactivating removes the compositor")
	_check(viewport.msaa_3d == msaa_before, "MSAA restored")
	_check(not RenderingServer.frame_pre_draw.is_connected(controller.before_draw), "before_draw is unhooked")
	_check(not RenderingServer.frame_post_draw.is_connected(controller.after_draw), "after_draw is unhooked")

	var toggle := EditorInterface.get_base_control().find_child("SolidViewToggle", true, false) as Button
	_check(toggle != null, "the Solid toggle is in the 3D toolbar")
	if toggle != null:
		toggle.button_pressed = true
		await process_frame
		_check(viewport.msaa_3d == Viewport.MSAA_DISABLED, "the toggle turns solid view on")
		_check(camera.environment == env_before, "the toggle leaves the editor's environment alone between frames")
		toggle.button_pressed = false
		await process_frame
		_check(viewport.msaa_3d == msaa_before, "the toggle turns it off again")

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
