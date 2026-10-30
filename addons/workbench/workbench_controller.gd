@tool
extends RefCounted
## Puts Workbench on the editor's 3D viewports and takes it off again.
##
## While active, each editor camera draws with a neutral environment (a flat
## background, no fog, glow, ambient or tonemapping), neutral camera
## attributes (no exposure or auto-exposure) and a compositor carrying the
## effect, and each viewport draws unshaded when the texture colour is
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
##
## X-ray needs what the opaque pass throws away, the geometry behind the
## front surface. For it, each editor viewport gets a hidden child
## SubViewport rendering the same world from a copy of its camera in the
## editor's Overdraw debug draw, which draws every surface, regardless of
## depth, as a fixed amount of green on black. A child viewport renders before
## its parent in the same frame, so the count of surfaces under each pixel is
## current when the effect blends it in.
##
## Random colour has nothing per object to read from a camera or viewport, so
## each object's render instance gets a material in its own colour through the
## RenderingServer, for as long as the mode is on: the server has no getter for
## it and the editor reads nodes, so the node, its resources and the saved
## scene never see it. The viewport draws unshaded as for texture colour, and
## the effect shades that colour the same way.

const WorkbenchEffect := preload("workbench_effect.gd")

## Where a pixel's colour comes from: a flat grey, the albedo in the colour
## buffer, or a colour of the object's own.
enum ColorMode { FLAT, TEXTURE, RANDOM }

const VIEWPORT_COUNT := 4
## Blender's default viewport grey, as a display colour.
const BACKGROUND := Color(0.24, 0.24, 0.24)
## The editor cameras see the game's 20 render layers plus their own gizmo,
## grid and tool layers above; the x-ray camera only wants the game's.
const GAME_LAYERS := (1 << 20) - 1
const XRAY_VIEWPORT_NAME := "WorkbenchXray"
## Random colour varies only the hue, at Blender's saturation and value, so
## more steps than this could not be told apart. Linear, like the base colour.
const RANDOM_HUES := 64
const RANDOM_SATURATION := 0.5
const RANDOM_VALUE := 0.8

## The options, read by every viewport's own effect before each draw.
var effect: WorkbenchEffect
var environment: Environment
var attributes: CameraAttributesPractical
var active: bool = false:
	set(value):
		if value != active:
			active = value
			if active:
				_take()
			else:
				_restore()
## How surfaces are coloured. Leaving random colour takes it off every object.
var color_mode: ColorMode = ColorMode.FLAT:
	set(value):
		color_mode = value
		effect.texture_color = color_mode != ColorMode.FLAT
		if color_mode != ColorMode.RANDOM:
			_unpaint_all()
## See through the front surfaces to the geometry behind them.
var xray: bool = false
## How opaque the front surface is in x-ray.
var xray_alpha: float = 0.5

## Per viewport taken over: its camera, its own effect and compositor, the
## MSAA it had, during a draw the environment, attributes, compositor and
## debug draw it had before the draw, and in x-ray its hidden viewport and
## camera.
var _entries: Array[Dictionary] = []
## True between [method before_draw] and [method after_draw].
var _drawing: bool = false
## One unshaded material per hue, made the first time random colour draws.
var _hue_materials: Array[StandardMaterial3D] = []
## The objects whose render instance carries a random colour, by instance id.
var _painted: Dictionary[int, Painted] = {}


## What a painted object's render instance was given, and the override its
## node had at the time: a change to either means a repaint.
class Painted:
	var object: GeometryInstance3D
	var material: StandardMaterial3D
	var own: Material


func _init() -> void:
	effect = WorkbenchEffect.new()
	effect.background_color = BACKGROUND
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BACKGROUND
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	attributes = CameraAttributesPractical.new()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and active:
		_restore()


## Puts the workbench state on every editor viewport for the draw that
## follows. Connected to [signal RenderingServer.frame_pre_draw] while active.
func before_draw() -> void:
	if not active or _drawing or not _shown():
		return
	_drawing = true
	if color_mode == ColorMode.RANDOM:
		_paint_objects()
	for entry: Dictionary in _entries:
		var camera := entry["camera"] as Camera3D
		var viewport := entry["viewport"] as SubViewport
		if not is_instance_valid(camera) or not is_instance_valid(viewport):
			continue
		var own_effect := entry["effect"] as WorkbenchEffect
		_copy_options(own_effect)
		if xray:
			_ensure_xray(entry)
			_sync_xray(entry)
			own_effect.xray = xray_alpha
			own_effect.xray_texture = RenderingServer.viewport_get_texture((entry["xray_viewport"] as SubViewport).get_viewport_rid())
		else:
			_free_xray(entry)
			own_effect.xray = 0.0
			own_effect.xray_texture = RID()
		entry["environment"] = camera.environment
		entry["attributes"] = camera.attributes
		entry["compositor"] = camera.compositor
		entry["debug_draw"] = viewport.debug_draw
		camera.environment = environment
		camera.attributes = attributes
		camera.compositor = entry["own_compositor"] as Compositor
		if viewport.msaa_3d != Viewport.MSAA_DISABLED:
			viewport.msaa_3d = Viewport.MSAA_DISABLED
		viewport.debug_draw = Viewport.DEBUG_DRAW_UNSHADED if color_mode != ColorMode.FLAT else Viewport.DEBUG_DRAW_DISABLED


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
			if camera.attributes == attributes:
				camera.attributes = entry.get("attributes") as CameraAttributes
			if camera.compositor == entry["own_compositor"]:
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
		var own_effect := WorkbenchEffect.new()
		var own_compositor := Compositor.new()
		own_compositor.compositor_effects = [own_effect]
		_entries.append({
			"viewport": viewport,
			"camera": camera,
			"msaa_3d": viewport.msaa_3d,
			"effect": own_effect,
			"own_compositor": own_compositor,
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
	_unpaint_all()
	for entry: Dictionary in _entries:
		_free_xray(entry)
		var viewport := entry["viewport"] as SubViewport
		if is_instance_valid(viewport) and viewport.msaa_3d == Viewport.MSAA_DISABLED:
			viewport.msaa_3d = entry["msaa_3d"] as Viewport.MSAA
	_entries.clear()


## Whether any editor viewport taken is on screen. On the 2D or Script screen
## nothing draws, so there is nothing to set up, and leaving the server alone
## lets the editor idle: it redraws while its change counter is up, which
## every server write raises, including the restores after a draw.
func _shown() -> bool:
	for entry: Dictionary in _entries:
		var viewport := entry["viewport"] as SubViewport
		if not is_instance_valid(viewport):
			continue
		var container := viewport.get_parent() as Control
		if container != null and container.is_visible_in_tree():
			return true
	return false


func _copy_options(own_effect: WorkbenchEffect) -> void:
	own_effect.shading = effect.shading
	own_effect.texture_color = effect.texture_color
	own_effect.base_color = effect.base_color
	own_effect.background_color = effect.background_color
	own_effect.cavity = effect.cavity
	own_effect.outline = effect.outline
	own_effect.outline_width = effect.outline_width
	own_effect.crease = effect.crease
	own_effect.matcap = effect.matcap


## Which of the [constant RANDOM_HUES] hues the object at this path gets, the
## same every time. Mixed through the generator because a string hash of
## "Wall2" and "Wall3" differs only in its low bits, which would pick
## neighbouring hues.
static func random_hue_index(path: String) -> int:
	return rand_from_seed(path.hash())[0] % RANDOM_HUES


## Whether random colour applies to this node: meshes, not the camera-facing
## quads of sprites and particles, which would draw as solid rectangles. Only
## the root of a CSG tree renders.
static func paints_random_color(node: Node) -> bool:
	if node is CSGShape3D:
		return (node as CSGShape3D).is_root_shape()
	return node is MeshInstance3D or node is MultiMeshInstance3D


## Gives every object in the edited scene a colour on its render instance, and
## takes it off the objects that have left the scene. Each node's path picks
## the colour, so an object keeps it between sessions. An object already
## carrying its colour is left alone: a server write rebuilds the instance's
## surfaces, so only a change is written. A new override on the node is such a
## change, as the node's setter puts it on the render instance over ours.
func _paint_objects() -> void:
	var root := EditorInterface.get_edited_scene_root()
	var nodes: Array[Node] = []
	if root != null:
		nodes = root.find_children("*", "GeometryInstance3D", true, false)
		nodes.append(root)
	if _hue_materials.is_empty():
		_make_hue_materials()
	var seen: Dictionary[int, bool] = {}
	for node: Node in nodes:
		if not paints_random_color(node):
			continue
		var object := node as GeometryInstance3D
		var id := object.get_instance_id()
		seen[id] = true
		var material := _hue_materials[random_hue_index(String(root.get_path_to(object)))]
		var own := object.material_override
		var painted: Painted = _painted.get(id)
		if painted != null and painted.material == material and painted.own == own:
			continue
		if painted == null:
			painted = Painted.new()
			painted.object = object
			_painted[id] = painted
		painted.material = material
		painted.own = own
		RenderingServer.instance_geometry_set_material_override(object.get_instance(), material.get_rid())
	for id: int in _painted.keys():
		if not seen.has(id):
			_unpaint(_painted[id])
			_painted.erase(id)


## Puts the node's own override back on a painted object's render instance.
func _unpaint(painted: Painted) -> void:
	if not is_instance_valid(painted.object):
		return
	var own := painted.object.material_override
	RenderingServer.instance_geometry_set_material_override(painted.object.get_instance(), own.get_rid() if own != null else RID())


func _unpaint_all() -> void:
	for painted: Painted in _painted.values():
		_unpaint(painted)
	_painted.clear()


func _make_hue_materials() -> void:
	for index: int in RANDOM_HUES:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		# Double-sided, as Blender's Solid mode draws by default, so a plane in
		# a double-sided material doesn't vanish from behind.
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		# A material's albedo is sRGB and these values are meant as linear.
		material.albedo_color = Color.from_hsv(float(index) / RANDOM_HUES, RANDOM_SATURATION, RANDOM_VALUE).linear_to_srgb()
		_hue_materials.append(material)


## Adds the hidden overdraw viewport under this editor viewport, if it isn't
## there yet. As a child, it shares the editor viewport's world and renders
## before it.
func _ensure_xray(entry: Dictionary) -> void:
	if entry.has("xray_viewport") and is_instance_valid(entry["xray_viewport"]):
		return
	var viewport := entry["viewport"] as SubViewport
	var ghost := SubViewport.new()
	ghost.name = XRAY_VIEWPORT_NAME
	ghost.debug_draw = Viewport.DEBUG_DRAW_OVERDRAW
	ghost.msaa_3d = Viewport.MSAA_DISABLED
	ghost.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	ghost.use_taa = false
	ghost.use_debanding = false
	# Keeps the render linear, so the shader reads the overdraw's green as is.
	ghost.use_hdr_2d = true
	ghost.positional_shadow_atlas_size = 0
	ghost.gui_disable_input = true
	ghost.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	ghost.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var ghost_camera := Camera3D.new()
	ghost_camera.environment = environment
	ghost_camera.attributes = attributes
	ghost_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	ghost.add_child(ghost_camera)
	viewport.add_child(ghost)
	entry["xray_viewport"] = ghost
	entry["xray_camera"] = ghost_camera


## Matches the hidden viewport and its camera to the editor's for this draw.
func _sync_xray(entry: Dictionary) -> void:
	var viewport := entry["viewport"] as SubViewport
	var camera := entry["camera"] as Camera3D
	var ghost := entry["xray_viewport"] as SubViewport
	var ghost_camera := entry["xray_camera"] as Camera3D
	if ghost.size != viewport.size:
		ghost.size = viewport.size
	ghost_camera.global_transform = camera.global_transform
	ghost_camera.projection = camera.projection
	ghost_camera.keep_aspect = camera.keep_aspect
	ghost_camera.fov = camera.fov
	ghost_camera.size = camera.size
	ghost_camera.near = camera.near
	ghost_camera.far = camera.far
	ghost_camera.h_offset = camera.h_offset
	ghost_camera.v_offset = camera.v_offset
	ghost_camera.frustum_offset = camera.frustum_offset
	ghost_camera.cull_mask = camera.cull_mask & GAME_LAYERS


func _free_xray(entry: Dictionary) -> void:
	if not entry.has("xray_viewport"):
		return
	var ghost := entry["xray_viewport"] as SubViewport
	if is_instance_valid(ghost):
		ghost.queue_free()
	entry.erase("xray_viewport")
	entry.erase("xray_camera")
