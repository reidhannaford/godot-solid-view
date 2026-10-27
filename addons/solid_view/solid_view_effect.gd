@tool
extends CompositorEffect
## Re-shades every opaque pixel from the depth and normal buffers, ignoring
## the scene's lights and materials. Forward+ only: it needs the normal and
## roughness buffer the depth prepass writes there. Attached to the editor
## cameras by the controller; the viewport must draw with MSAA off, because
## the opaque colour is only resolved after the transparent pass and a
## post-opaque write to the resolved buffer would be lost.

enum Shading { STUDIO, MATCAP }

const SHADER_FILE_NAME := "solid_view.glsl"
const WORKGROUP := 8
const PUSH_CONSTANT_FLOATS := 16

var shading: Shading = Shading.STUDIO
## Multiply the shading by the albedo in the colour buffer. Only meaningful
## while the viewport draws unshaded, which the controller arranges.
var texture_color: bool = false
var base_color: Color = Color(0.8, 0.8, 0.8)
var cavity: float = 1.0
var outline: float = 1.0
var matcap: Texture2D

var _rd: RenderingDevice
var _shader_file: RDShaderFile
var _shader: RID
var _pipeline: RID
var _nearest_sampler: RID
var _linear_sampler: RID
var _failed: bool = false


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_OPAQUE
	needs_normal_roughness = true
	access_resolved_depth = true
	access_resolved_color = true
	# Null when the renderer is a dummy (headless) or not RenderingDevice-based.
	_rd = RenderingServer.get_rendering_device()
	if _rd == null:
		return
	# Loaded here rather than preloaded: on a project's first scan the .glsl
	# isn't imported yet when the scripts compile.
	var path := (get_script() as Script).resource_path.get_base_dir().path_join(SHADER_FILE_NAME)
	_shader_file = ResourceLoader.load(path, "RDShaderFile") as RDShaderFile
	if _shader_file == null:
		push_error("Solid View: can't load the compute shader at %s." % path)
		_failed = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _rd != null:
		# Freeing the shader frees the pipeline with it.
		if _shader.is_valid():
			_rd.free_rid(_shader)
		if _nearest_sampler.is_valid():
			_rd.free_rid(_nearest_sampler)
		if _linear_sampler.is_valid():
			_rd.free_rid(_linear_sampler)


func _render_callback(p_effect_callback_type: int, p_render_data: RenderData) -> void:
	if _rd == null or p_effect_callback_type != EFFECT_CALLBACK_TYPE_POST_OPAQUE:
		return
	if not _ensure_pipeline():
		return
	var buffers := p_render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	if buffers == null:
		return
	var size := buffers.get_internal_size()
	if size.x == 0 or size.y == 0:
		return
	if not buffers.has_texture(&"forward_clustered", &"normal_roughness"):
		return

	var projection := p_render_data.get_render_scene_data().get_cam_projection()
	var push_constant := PackedFloat32Array()
	push_constant.resize(PUSH_CONSTANT_FLOATS)
	push_constant[0] = size.x
	push_constant[1] = size.y
	push_constant[2] = projection.get_z_near()
	push_constant[3] = projection.get_z_far()
	push_constant[4] = base_color.r
	push_constant[5] = base_color.g
	push_constant[6] = base_color.b
	push_constant[7] = 1.0
	push_constant[8] = 1.0 if shading == Shading.MATCAP else 0.0
	push_constant[9] = 1.0 if texture_color else 0.0
	push_constant[10] = cavity
	push_constant[11] = outline
	push_constant[12] = 1.0 if projection.is_orthogonal() else 0.0

	var matcap_rid := _matcap_rd_texture()
	var groups_x := (size.x - 1) / WORKGROUP + 1
	var groups_y := (size.y - 1) / WORKGROUP + 1

	for view: int in buffers.get_view_count():
		var color_set := UniformSetCacheRD.get_cache(_shader, 0, [_image_uniform(buffers.get_color_layer(view))])
		var depth_set := UniformSetCacheRD.get_cache(_shader, 1, [_sampler_uniform(_nearest_sampler, buffers.get_depth_layer(view))])
		var normal_set := UniformSetCacheRD.get_cache(_shader, 2, [_sampler_uniform(_nearest_sampler, buffers.get_texture(&"forward_clustered", &"normal_roughness"))])
		var matcap_set := UniformSetCacheRD.get_cache(_shader, 3, [_sampler_uniform(_linear_sampler, matcap_rid)])

		var compute_list := _rd.compute_list_begin()
		_rd.compute_list_bind_compute_pipeline(compute_list, _pipeline)
		_rd.compute_list_bind_uniform_set(compute_list, color_set, 0)
		_rd.compute_list_bind_uniform_set(compute_list, depth_set, 1)
		_rd.compute_list_bind_uniform_set(compute_list, normal_set, 2)
		_rd.compute_list_bind_uniform_set(compute_list, matcap_set, 3)
		_rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), PUSH_CONSTANT_FLOATS * 4)
		_rd.compute_list_dispatch(compute_list, groups_x, groups_y, 1)
		_rd.compute_list_end()


## Compiles the shader the first time the effect renders. Runs on the
## rendering thread, where RenderingDevice resources must be made.
func _ensure_pipeline() -> bool:
	if _pipeline.is_valid():
		return true
	if _failed:
		return false
	var spirv := _shader_file.get_spirv()
	if spirv == null or spirv.compile_error_compute != "":
		push_error("Solid View: the compute shader failed to compile: %s" % (spirv.compile_error_compute if spirv != null else "no SPIR-V"))
		_failed = true
		return false
	_shader = _rd.shader_create_from_spirv(spirv)
	if not _shader.is_valid():
		push_error("Solid View: could not create the compute shader.")
		_failed = true
		return false
	_pipeline = _rd.compute_pipeline_create(_shader)
	if not _pipeline.is_valid():
		push_error("Solid View: could not create the compute pipeline.")
		_failed = true
		return false

	var nearest := RDSamplerState.new()
	nearest.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	nearest.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	nearest.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	nearest.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	_nearest_sampler = _rd.sampler_create(nearest)
	var linear := RDSamplerState.new()
	linear.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	linear.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	linear.mip_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	linear.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	linear.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	_linear_sampler = _rd.sampler_create(linear)
	return true


## The matcap as a RenderingDevice texture, through its sRGB view so the
## shader reads linear values. A white pixel stands in when there is none.
func _matcap_rd_texture() -> RID:
	var texture_rid := RenderingServer.get_white_texture()
	if matcap != null and matcap.get_rid().is_valid():
		texture_rid = matcap.get_rid()
	var rd_texture := RenderingServer.texture_get_rd_texture(texture_rid, true)
	if not rd_texture.is_valid():
		rd_texture = RenderingServer.texture_get_rd_texture(texture_rid, false)
	return rd_texture


static func _image_uniform(image: RID) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(image)
	return uniform


static func _sampler_uniform(sampler: RID, texture: RID) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	uniform.binding = 0
	uniform.add_id(sampler)
	uniform.add_id(texture)
	return uniform
