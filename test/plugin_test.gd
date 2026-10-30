extends SceneTree
## Headless check that the plugin loads, puts its toggle in the 3D toolbar,
## and that the controller takes over the editor viewports only for a draw
## and restores them.
## Run: godot --headless --editor --path . -s res://test/plugin_test.gd

const WorkbenchController := preload("res://addons/workbench/workbench_controller.gd")
const WorkbenchSettings := preload("res://addons/workbench/workbench_settings.gd")

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
	var attributes_before := camera.attributes
	var debug_draw_before := viewport.debug_draw
	var children_before := viewport.get_child_count()

	var controller := WorkbenchController.new()
	controller.active = true
	_check(viewport.msaa_3d == Viewport.MSAA_DISABLED, "MSAA is off while active")
	_check(camera.environment == env_before, "between frames the camera keeps the editor's environment")
	_check(camera.compositor == null, "between frames the camera has no compositor")
	_check(RenderingServer.frame_pre_draw.is_connected(controller.before_draw), "before_draw is hooked to frame_pre_draw")
	_check(RenderingServer.frame_post_draw.is_connected(controller.after_draw), "after_draw is hooked to frame_post_draw")

	controller.before_draw()
	_check(camera.environment == controller.environment, "the draw gets the solid environment")
	_check(camera.attributes == controller.attributes, "the draw gets neutral camera attributes")
	_check(camera.compositor != null and camera.compositor.compositor_effects.size() == 1, "the draw gets a compositor with the effect")
	_check(viewport.debug_draw == Viewport.DEBUG_DRAW_DISABLED, "flat colour draws normally")
	_check(viewport.get_child_count() == children_before, "no x-ray viewport while x-ray is off")
	controller.after_draw()
	_check(camera.environment == env_before, "after the draw the environment is the editor's again")
	_check(camera.attributes == attributes_before, "after the draw the attributes are the editor's again")
	_check(camera.compositor == null, "after the draw the compositor is gone")
	_check(viewport.debug_draw == debug_draw_before, "after the draw the debug draw is the editor's again")

	viewport.msaa_3d = Viewport.MSAA_4X
	controller.color_mode = WorkbenchController.ColorMode.TEXTURE
	controller.before_draw()
	_check(viewport.msaa_3d == Viewport.MSAA_DISABLED, "before_draw puts MSAA off again after the editor resets it")
	_check(viewport.debug_draw == Viewport.DEBUG_DRAW_UNSHADED, "texture colour draws unshaded")
	controller.after_draw()
	_check(viewport.debug_draw == debug_draw_before, "debug draw restored after an unshaded draw")
	controller.color_mode = WorkbenchController.ColorMode.FLAT

	EditorInterface.open_scene_from_path("res://test/test_scene.tscn")
	await process_frame
	var scene_root := EditorInterface.get_edited_scene_root()
	_check(scene_root != null, "the test scene opens")
	if scene_root != null:
		var ball := scene_root.get_node("Ball") as MeshInstance3D
		var ball_id := ball.get_instance_id()
		var ball_material := ball.get_surface_override_material(0)
		controller.color_mode = WorkbenchController.ColorMode.RANDOM
		controller.before_draw()
		_check(viewport.debug_draw == Viewport.DEBUG_DRAW_UNSHADED, "random colour draws unshaded")
		_check(camera.compositor.compositor_effects[0].texture_color, "the effect shades the random colour")
		_check(controller._painted.size() == 9, "random colour paints the scene's nine meshes, not its lights or camera")
		_check(ball.material_override == null, "the node's material override is untouched")
		_check(ball.get_surface_override_material(0) == ball_material, "the node's surface material is untouched")
		controller.after_draw()
		_check(controller._painted.size() == 9, "the colours stay on between draws")
		_check(viewport.debug_draw == debug_draw_before, "debug draw restored after a random colour draw")
		var ball_hue: StandardMaterial3D = controller._painted[ball_id].material
		var own_override := StandardMaterial3D.new()
		ball.material_override = own_override
		controller.before_draw()
		_check(controller._painted[ball_id].own == own_override, "a new override on the node is seen, and painted over")
		_check(controller._painted[ball_id].material == ball_hue, "the object keeps its hue")
		controller.after_draw()
		ball.material_override = null
		var ball_parent := ball.get_parent()
		ball_parent.remove_child(ball)
		controller.before_draw()
		_check(controller._painted.size() == 8 and not controller._painted.has(ball_id), "an object that left the scene is unpainted")
		controller.after_draw()
		ball_parent.add_child(ball)
		controller.before_draw()
		_check(controller._painted.has(ball_id), "an object back in the scene is painted again")
		controller.active = false
		_check(controller._painted.is_empty(), "deactivating mid-draw unpaints the objects")
		controller.active = true
		controller.before_draw()
		controller.after_draw()
		controller.color_mode = WorkbenchController.ColorMode.FLAT
		_check(controller._painted.is_empty(), "flat colour takes the colours off")
		controller.before_draw()
		_check(controller._painted.is_empty(), "flat colour paints nothing")
		_check(viewport.debug_draw == Viewport.DEBUG_DRAW_DISABLED, "back to a normal draw without random colour")
		controller.after_draw()
		var csg_root := CSGBox3D.new()
		var csg_child := CSGBox3D.new()
		csg_root.add_child(csg_child)
		_check(WorkbenchController.paints_random_color(csg_root), "a CSG root is painted")
		_check(not WorkbenchController.paints_random_color(csg_child), "a CSG child is not: only its root renders")
		csg_root.free()
		var multimesh := MultiMeshInstance3D.new()
		_check(WorkbenchController.paints_random_color(multimesh), "a multimesh is painted")
		multimesh.free()
		for other: Node in [Sprite3D.new(), Label3D.new(), GPUParticles3D.new(), DirectionalLight3D.new()]:
			_check(not WorkbenchController.paints_random_color(other), "a %s is not painted" % other.get_class())
			other.free()
		var hues: Dictionary[int, bool] = {}
		for node_name: String in ["Floor", "Wall", "Wall2", "Wall3", "Crate", "CrateOnTop", "Ball", "Pillar", "Ring"]:
			hues[WorkbenchController.random_hue_index(node_name)] = true
		_check(hues.size() >= 7, "similar names get different hues")
		_check(WorkbenchController.random_hue_index("Wall2") == WorkbenchController.random_hue_index("Wall2"), "a path always gets the same hue")

	controller.xray = true
	controller.before_draw()
	var ghost := viewport.find_child(WorkbenchController.XRAY_VIEWPORT_NAME, false, false) as SubViewport
	_check(ghost != null, "x-ray adds a hidden viewport under the editor viewport")
	if ghost != null:
		_check(ghost.debug_draw == Viewport.DEBUG_DRAW_OVERDRAW, "the hidden viewport draws overdraw")
		_check(ghost.size == viewport.size, "the hidden viewport matches the editor viewport's size")
		var ghost_camera := ghost.get_camera_3d()
		_check(ghost_camera != null, "the hidden viewport has a camera")
		if ghost_camera != null:
			_check(ghost_camera.global_transform.is_equal_approx(camera.global_transform), "the hidden camera copies the editor camera")
			_check(ghost_camera.cull_mask & ~WorkbenchController.GAME_LAYERS == 0, "the hidden camera leaves out the gizmo layers")
			_check(ghost_camera.environment == controller.environment, "the hidden camera has the neutral environment")
		var own_effect := camera.compositor.compositor_effects[0]
		_check(own_effect.xray > 0.0, "the effect gets the x-ray opacity")
		_check(own_effect.outline_width >= 1.0, "the effect gets an outline width of at least a pixel")
		_check(own_effect.xray_texture == RenderingServer.viewport_get_texture(ghost.get_viewport_rid()), "the effect gets the hidden viewport's texture")
	controller.after_draw()
	controller.xray = false
	controller.before_draw()
	_check(ghost == null or ghost.is_queued_for_deletion(), "turning x-ray off removes the hidden viewport")
	controller.after_draw()

	controller.before_draw()
	controller.active = false
	_check(camera.environment == env_before, "deactivating mid-draw restores the environment")
	_check(camera.compositor == null, "deactivating removes the compositor")
	_check(viewport.msaa_3d == msaa_before, "MSAA restored")
	_check(not RenderingServer.frame_pre_draw.is_connected(controller.before_draw), "before_draw is unhooked")
	_check(not RenderingServer.frame_post_draw.is_connected(controller.after_draw), "after_draw is unhooked")
	await process_frame
	_check(viewport.get_child_count() == children_before, "the editor viewport has no leftover children")

	var toggle := EditorInterface.get_base_control().find_child("WorkbenchToggle", true, false) as Button
	_check(toggle != null, "the Workbench toggle is in the 3D toolbar")
	if toggle != null:
		toggle.button_pressed = true
		await process_frame
		_check(viewport.msaa_3d == Viewport.MSAA_DISABLED, "the toggle turns workbench on")
		_check(camera.environment == env_before, "the toggle leaves the editor's environment alone between frames")
		toggle.button_pressed = false
		await process_frame
		_check(viewport.msaa_3d == msaa_before, "the toggle turns it off again")

	for label: String in WorkbenchSettings.BUNDLED_MATCAPS:
		var path: String = WorkbenchSettings.BUNDLED_MATCAPS[label]
		_check(ResourceLoader.exists(path), "bundled matcap %s exists at %s" % [label, path])
	var matcap_menu := EditorInterface.get_base_control().find_child("WorkbenchMatcaps", true, false) as PopupMenu
	_check(matcap_menu != null and matcap_menu.item_count == WorkbenchSettings.BUNDLED_MATCAPS.size(), "the Bundled MatCaps submenu lists every bundled matcap")

	var settings := EditorInterface.get_editor_settings()
	settings.set_setting("workbench/texture_color", true)
	var migrated := WorkbenchSettings.new()
	migrated.load()
	_check(migrated.color_mode == WorkbenchController.ColorMode.TEXTURE, "the old texture colour setting carries over")
	settings.set_setting("workbench/color_mode", 7)
	var clamped := WorkbenchSettings.new()
	clamped.load()
	_check(clamped.color_mode == WorkbenchController.ColorMode.RANDOM, "a colour mode past the enum is clamped")
	settings.set_setting("workbench/color_mode", WorkbenchController.ColorMode.FLAT)
	_check(not settings.has_setting("workbench/texture_color"), "the old texture colour setting is removed")
	_check(settings.has_shortcut("workbench/toggle"), "the shortcut is registered")
	_check(settings.has_shortcut("workbench/toggle_xray"), "the x-ray shortcut is registered")

	print("FAILURES %d" % _failures)
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, what: String) -> void:
	if condition:
		print("PASS %s" % what)
	else:
		_failures += 1
		print("FAIL %s" % what)
