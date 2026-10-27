#[compute]
#version 450

// Solid View: after the opaque pass, every pixel that has geometry is
// re-shaded from the depth and normal buffers alone, the way Blender's Solid
// mode does. The scene's lights, materials, fog and post-processing never
// reach it. Runs before the sky and the transparent pass, so the editor's
// grid, gizmos and any see-through objects still draw on top.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(set = 1, binding = 0) uniform sampler2D depth_texture;
layout(set = 2, binding = 0) uniform sampler2D normal_roughness_texture;
layout(set = 3, binding = 0) uniform sampler2D matcap_texture;

layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	float z_near;
	float z_far;
	vec4 base_color; // Linear rgb; a unused.
	float shading; // 0 studio lighting, 1 matcap.
	float texture_color; // 1 multiplies by the colour buffer (the albedo, when the viewport draws unshaded).
	float cavity; // Ridge and valley strength, 0 off.
	float outline; // Silhouette darkening, 0 off.
	float orthographic;
	float reserved0;
	float reserved1;
	float reserved2;
} params;

ivec2 size = ivec2(params.raster_size);

ivec2 clamp_uv(ivec2 uv) {
	return clamp(uv, ivec2(0), size - ivec2(1));
}

float raw_depth(ivec2 uv) {
	return texelFetch(depth_texture, clamp_uv(uv), 0).r;
}

// Distance along the view axis. Godot's RenderingDevice renderers keep a
// reversed depth buffer: 1.0 at the near plane, 0.0 at the far plane.
float view_distance(float depth) {
	float n = params.z_near;
	float f = params.z_far;
	float z_ndc = 1.0 - 2.0 * depth;
	if (params.orthographic > 0.5) {
		return (z_ndc * (f - n) + (f + n)) * 0.5;
	}
	return 2.0 * f * n / ((f + n) - (f - n) * z_ndc);
}

// The depth buffer is cleared to 0 where nothing was drawn: sky, or a
// transparent object that draws later.
bool has_geometry(float depth) {
	return depth > 0.0;
}

// View-space normal: +X right, +Y up, +Z towards the viewer.
vec3 load_normal(ivec2 uv) {
	vec4 nr = texelFetch(normal_roughness_texture, clamp_uv(uv), 0);
	return normalize(nr.xyz * 2.0 - 1.0);
}

float wrap_lambert(float ndl, float wrap) {
	return clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0);
}

// Three fixed view-space lights and a little ambient, like Blender's default
// studio light: a warm key from the upper left, a cool fill from the right
// and a faint rim from below and behind.
vec3 shade_studio(vec3 n, vec3 base) {
	vec3 view = vec3(0.0, 0.0, 1.0);
	vec3 key_dir = normalize(vec3(-0.45, 0.55, 0.70));
	vec3 fill_dir = normalize(vec3(0.75, 0.10, 0.45));
	vec3 rim_dir = normalize(vec3(0.25, -0.65, -0.35));
	vec3 key_col = vec3(0.60, 0.59, 0.56);
	vec3 fill_col = vec3(0.20, 0.22, 0.26);
	vec3 rim_col = vec3(0.14, 0.13, 0.12);
	vec3 ambient = vec3(0.07);

	vec3 light = ambient
			+ key_col * wrap_lambert(dot(n, key_dir), 0.25)
			+ fill_col * wrap_lambert(dot(n, fill_dir), 0.40)
			+ rim_col * wrap_lambert(dot(n, rim_dir), 0.0);
	vec3 half_dir = normalize(key_dir + view);
	float spec = pow(max(dot(n, half_dir), 0.0), 24.0) * 0.08;
	return base * light + spec;
}

vec3 shade_matcap(vec3 n, vec3 base) {
	vec2 uv = vec2(n.x, -n.y) * 0.495 + 0.5;
	return texture(matcap_texture, uv).rgb * base;
}

// Screen-space curvature from the normal buffer, Blender's "screen" cavity:
// normals that spread apart across a pixel are a ridge, normals that converge
// are a valley. Neighbours on another surface (a depth jump) are ignored.
float curvature(ivec2 uv, float dist) {
	vec3 n_c = load_normal(uv);
	float limit = max(dist * 0.02, 0.005);
	vec3 n_l = abs(view_distance(raw_depth(uv + ivec2(-1, 0))) - dist) < limit ? load_normal(uv + ivec2(-1, 0)) : n_c;
	vec3 n_r = abs(view_distance(raw_depth(uv + ivec2(1, 0))) - dist) < limit ? load_normal(uv + ivec2(1, 0)) : n_c;
	vec3 n_u = abs(view_distance(raw_depth(uv + ivec2(0, -1))) - dist) < limit ? load_normal(uv + ivec2(0, -1)) : n_c;
	vec3 n_d = abs(view_distance(raw_depth(uv + ivec2(0, 1))) - dist) < limit ? load_normal(uv + ivec2(0, 1)) : n_c;
	float diff = (n_r.x - n_l.x) + (n_u.y - n_d.y);
	// Soft clamp so sharp creases don't blow out.
	float strength = params.cavity;
	if (diff < 0.0) {
		return -clamp(-diff * strength, 0.0, 0.6);
	}
	return clamp(diff * strength, 0.0, 0.6);
}

// How strongly this pixel sits on the near side of a depth discontinuity.
// 1/distance is linear across a flat surface in perspective, so a plane at
// any angle scores 0; only a jump to something farther (or to the sky) counts.
float silhouette(ivec2 uv, float dist) {
	bool ortho = params.orthographic > 0.5;
	float q_c = ortho ? -dist : 1.0 / dist;
	float edge = 0.0;
	ivec2 dirs[2] = ivec2[2](ivec2(1, 0), ivec2(0, 1));
	for (int i = 0; i < 2; i++) {
		float d_a = raw_depth(uv + dirs[i]);
		float d_b = raw_depth(uv - dirs[i]);
		float q_a = has_geometry(d_a) ? (ortho ? -view_distance(d_a) : 1.0 / view_distance(d_a)) : (ortho ? -params.z_far : 0.0);
		float q_b = has_geometry(d_b) ? (ortho ? -view_distance(d_b) : 1.0 / view_distance(d_b)) : (ortho ? -params.z_far : 0.0);
		// Positive only where a neighbour drops away farther than the slope
		// through the opposite neighbour predicts.
		edge = max(edge, (q_c - q_a) - (q_b - q_c));
		edge = max(edge, (q_c - q_b) - (q_a - q_c));
	}
	float threshold = ortho ? 0.01 * max(dist, 0.1) : 0.08 * q_c;
	return clamp((edge - threshold) / threshold, 0.0, 1.0);
}

void main() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	if (uv.x >= size.x || uv.y >= size.y) {
		return;
	}

	float depth = raw_depth(uv);
	if (!has_geometry(depth)) {
		return;
	}

	vec3 n = load_normal(uv);
	vec3 base = params.base_color.rgb;
	if (params.texture_color > 0.5) {
		base = imageLoad(color_image, uv).rgb;
	}

	vec3 color = params.shading > 0.5 ? shade_matcap(n, base) : shade_studio(n, base);

	float dist = view_distance(depth);
	if (params.cavity > 0.0) {
		color *= 1.0 + curvature(uv, dist);
	}
	if (params.outline > 0.0) {
		color = mix(color, vec3(0.015), silhouette(uv, dist) * params.outline);
	}

	imageStore(color_image, uv, vec4(color, 1.0));
}
