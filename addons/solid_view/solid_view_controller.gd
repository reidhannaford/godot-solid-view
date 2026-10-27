@tool
extends RefCounted
## Puts Solid View on the editor's 3D viewports and takes it off again. While
## active, each editor camera gets a neutral environment (a flat background,
## no fog, glow, ambient or tonemapping) and a compositor carrying the effect;
## each viewport gets MSAA off, and draws unshaded when the texture colour is
## wanted. The editor resets some of these on its own (the View Environment
## toggle, a project settings change), so [method apply] is meant to be
## called every frame while active, and is cheap when nothing changed.

const SolidViewEffect := preload("solid_view_effect.gd")
const VIEWPORT_COUNT := 4
## Blender's default viewport grey, as a display colour.
const BACKGROUND := Color(0.24, 0.24, 0.24)

var effect: SolidViewEffect
var environment: Environment
var compositor: Compositor
var active: bool = false:
	set(value):
		if value != active:
			active = value
			if active:
				_take()
			else:
				_restore()
## Shade with the albedo from the colour buffer instead of a flat colour.
var texture_color: bool = false:
	set(value):
		texture_color = value
		effect.texture_color = value

## Per viewport, what the editor had before: camera, environment, compositor,
## msaa_3d and debug_draw.
var _saved: Array[Dictionary] = []


func _init() -> void:
	effect = SolidViewEffect.new()
	compositor = Compositor.new()
	compositor.compositor_effects = [effect]
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BACKGROUND
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR


## Re-asserts the solid view state on every editor viewport, undoing anything
## the editor reset since the last call. Does nothing while inactive.
func apply() -> void:
	if not active:
		return
	for entry: Dictionary in _saved:
		var camera := entry["camera"] as Camera3D
		var viewport := entry["viewport"] as SubViewport
		if not is_instance_valid(camera) or not is_instance_valid(viewport):
			continue
		if camera.environment != environment:
			camera.environment = environment
		if camera.compositor != compositor:
			camera.compositor = compositor
		if viewport.msaa_3d != Viewport.MSAA_DISABLED:
			viewport.msaa_3d = Viewport.MSAA_DISABLED
		var wanted := Viewport.DEBUG_DRAW_UNSHADED if texture_color else Viewport.DEBUG_DRAW_DISABLED
		if viewport.debug_draw != wanted:
			viewport.debug_draw = wanted


func _take() -> void:
	_saved.clear()
	for index: int in VIEWPORT_COUNT:
		var viewport := EditorInterface.get_editor_viewport_3d(index)
		if viewport == null:
			continue
		var camera := viewport.get_camera_3d()
		if camera == null:
			continue
		_saved.append({
			"viewport": viewport,
			"camera": camera,
			"environment": camera.environment,
			"compositor": camera.compositor,
			"msaa_3d": viewport.msaa_3d,
			"debug_draw": viewport.debug_draw,
		})
	apply()


func _restore() -> void:
	for entry: Dictionary in _saved:
		var camera := entry["camera"] as Camera3D
		var viewport := entry["viewport"] as SubViewport
		if is_instance_valid(camera):
			if camera.environment == environment:
				camera.environment = entry["environment"] as Environment
			if camera.compositor == compositor:
				camera.compositor = entry["compositor"] as Compositor
		if is_instance_valid(viewport):
			viewport.msaa_3d = entry["msaa_3d"] as Viewport.MSAA
			viewport.debug_draw = entry["debug_draw"] as Viewport.DebugDraw
	_saved.clear()
