@tool
extends RefCounted
## Puts Solid View on the editor's 3D viewports and takes it off again.
##
## While active, each editor camera draws with a neutral environment (a flat
## background, no fog, glow, ambient or tonemapping) and a compositor carrying
## the effect, and each viewport draws unshaded when the texture colour is
## wanted. Those are only on the camera and viewport for the duration of a
## draw: [method before_draw] puts them on from
## [signal RenderingServer.frame_pre_draw] and [method after_draw] puts the
## editor's own values back from [signal RenderingServer.frame_post_draw].
## Between frames the editor sees its own state, which matters because it
## stores its View Environment toggle as "does the camera have an
## environment" in the per-scene edit state, and would otherwise save and
## replay this addon's environment as the user's choice.
##
## MSAA is the exception: changing it rebuilds the render buffers, so it stays
## off for as long as the mode is on, and is re-asserted before every draw
## because the editor puts the project's value back on a settings change.

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

## Per viewport taken over: its camera, the MSAA it had, and during a draw
## the environment, compositor and debug draw it had before the draw.
var _entries: Array[Dictionary] = []
## True between [method before_draw] and [method after_draw].
var _drawing: bool = false


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


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and active:
		_restore()


## Puts the solid view state on every editor viewport for the draw that
## follows. Connected to [signal RenderingServer.frame_pre_draw] while active.
func before_draw() -> void:
	if not active or _drawing:
		return
	_drawing = true
	for entry: Dictionary in _entries:
		var camera := entry["camera"] as Camera3D
		var viewport := entry["viewport"] as SubViewport
		if not is_instance_valid(camera) or not is_instance_valid(viewport):
			continue
		entry["environment"] = camera.environment
		entry["compositor"] = camera.compositor
		entry["debug_draw"] = viewport.debug_draw
		camera.environment = environment
		camera.compositor = compositor
		if viewport.msaa_3d != Viewport.MSAA_DISABLED:
			viewport.msaa_3d = Viewport.MSAA_DISABLED
		viewport.debug_draw = Viewport.DEBUG_DRAW_UNSHADED if texture_color else Viewport.DEBUG_DRAW_DISABLED


## Puts the editor's own camera and viewport state back after a draw.
## Connected to [signal RenderingServer.frame_post_draw] while active.
func after_draw() -> void:
	if not _drawing:
		return
	_drawing = false
	for entry: Dictionary in _entries:
		var camera := entry["camera"] as Camera3D
		var viewport := entry["viewport"] as SubViewport
		if is_instance_valid(camera):
			if camera.environment == environment:
				camera.environment = entry.get("environment") as Environment
			if camera.compositor == compositor:
				camera.compositor = entry.get("compositor") as Compositor
		if is_instance_valid(viewport) and entry.has("debug_draw"):
			viewport.debug_draw = entry["debug_draw"] as Viewport.DebugDraw


func _take() -> void:
	_entries.clear()
	for index: int in VIEWPORT_COUNT:
		var viewport := EditorInterface.get_editor_viewport_3d(index)
		if viewport == null:
			continue
		var camera := viewport.get_camera_3d()
		if camera == null:
			continue
		_entries.append({
			"viewport": viewport,
			"camera": camera,
			"msaa_3d": viewport.msaa_3d,
		})
		viewport.msaa_3d = Viewport.MSAA_DISABLED
	if not RenderingServer.frame_pre_draw.is_connected(before_draw):
		RenderingServer.frame_pre_draw.connect(before_draw)
	if not RenderingServer.frame_post_draw.is_connected(after_draw):
		RenderingServer.frame_post_draw.connect(after_draw)


func _restore() -> void:
	if RenderingServer.frame_pre_draw.is_connected(before_draw):
		RenderingServer.frame_pre_draw.disconnect(before_draw)
	if RenderingServer.frame_post_draw.is_connected(after_draw):
		RenderingServer.frame_post_draw.disconnect(after_draw)
	after_draw()
	for entry: Dictionary in _entries:
		var viewport := entry["viewport"] as SubViewport
		if is_instance_valid(viewport) and viewport.msaa_3d == Viewport.MSAA_DISABLED:
			viewport.msaa_3d = entry["msaa_3d"] as Viewport.MSAA
	_entries.clear()
