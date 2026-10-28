extends SceneTree
## Bakes the bundled matcaps into addons/workbench/matcaps/ as 256px sRGB
## PNGs. Each is a function of the view-space normal of a sphere, +X right,
## +Y up, +Z towards the viewer. Lit ones are shaded in linear light and
## converted; the stylised ones (normal, zebra) are written in display
## colours as they are, since the effect shows a matcap with linear tonemapping.
## Run headless: godot --headless --path . -s res://tools/make_matcap.gd

const SIZE := 256
const DIR := "res://addons/workbench/matcaps/"
const VIEW := Vector3(0.0, 0.0, 1.0)

## Name to shader; each returns the display colour for a normal.
var _matcaps: Dictionary[String, Callable] = {
	"clay": _clay,
	"normal": _normal,
	"contrast": _contrast,
	"toon": _toon,
	"zebra": _zebra,
	"wax": _wax,
	"chrome": _chrome,
}


func _initialize() -> void:
	var failed := 0
	for name: String in _matcaps:
		var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGB8)
		var shade: Callable = _matcaps[name]
		for y: int in SIZE:
			for x: int in SIZE:
				var p := Vector2((x + 0.5) / SIZE * 2.0 - 1.0, 1.0 - (y + 0.5) / SIZE * 2.0)
				if p.length_squared() > 1.0:
					p = p.normalized() * 0.9995
				var n := Vector3(p.x, p.y, sqrt(maxf(1.0 - p.length_squared(), 0.0)))
				image.set_pixel(x, y, shade.call(n) as Color)
		var path := DIR + name + ".png"
		var error := image.save_png(path)
		print("Wrote %s (%s)" % [path, error_string(error)])
		if error != OK:
			failed += 1
	quit(0 if failed == 0 else 1)


## The default: a warm key from the upper left, a cool fill from the right
## and a faint rim, on a light clay. Kept at 80% so flat colour and the
## studio light sit at the same brightness.
static func _clay(n: Vector3) -> Color:
	var base := Vector3(0.80, 0.74, 0.68) * 0.8
	var key_dir := Vector3(-0.45, 0.60, 0.65).normalized()
	var fill_dir := Vector3(0.80, 0.05, 0.40).normalized()
	var rim_dir := Vector3(0.20, -0.70, -0.40).normalized()
	var light := Vector3(0.07, 0.07, 0.08) \
			+ Vector3(0.66, 0.62, 0.56) * _wrap(n.dot(key_dir), 0.25) \
			+ Vector3(0.18, 0.20, 0.26) * _wrap(n.dot(fill_dir), 0.4) \
			+ Vector3(0.14, 0.13, 0.11) * _wrap(n.dot(rim_dir), 0.0)
	var spec := pow(maxf(n.dot(_half(key_dir)), 0.0), 40.0) * 0.14
	var fresnel := pow(1.0 - maxf(n.z, 0.0), 4.0) * 0.08
	return _lit(base * light + Vector3.ONE * (spec + fresnel) * 0.8)


## The normal itself as a colour, the way a tangent-space normal map stores
## it: facing the viewer is lavender, right is pink, up is green. Blender's
## check_normal+y.
static func _normal(n: Vector3) -> Color:
	return Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5)


## Two tones, white towards an upper-left light and black away from it,
## with a soft terminator and a thin bright rim so silhouettes stay
## readable against the dark side.
static func _contrast(n: Vector3) -> Color:
	var key_dir := Vector3(-0.50, 0.55, 0.60).normalized()
	var lit := smoothstep(0.30, 0.62, n.dot(key_dir))
	var rim := pow(1.0 - maxf(n.z, 0.0), 6.0) * 0.9
	var v := maxf(lerpf(0.03, 0.97, lit), rim)
	return _lit(Vector3(v, v, v))


## Three cel bands and a hard specular dot, like Blender's toon matcap, on a
## pale yellow.
static func _toon(n: Vector3) -> Color:
	var key_dir := Vector3(-0.45, 0.55, 0.65).normalized()
	var ndl := n.dot(key_dir)
	var band := 0.22
	if ndl > 0.55:
		band = 0.95
	elif ndl > 0.05:
		band = 0.58
	var spec := 1.0 if n.dot(_half(key_dir)) > 0.985 else 0.0
	var base := Vector3(0.96, 0.90, 0.72)
	return _lit(base * band + Vector3.ONE * spec * 0.6)


## Black and white stripes across the reflection of a horizontal striped
## room: a reflection check. Smooth surfaces show smooth stripes; a kink or
## a bad normal breaks them. Blender's reflection_check_horizontal.
static func _zebra(n: Vector3) -> Color:
	var r := 2.0 * n.dot(VIEW) * n - VIEW
	var stripes := 7.0
	var phase := fmod(r.y * 0.5 + 0.5, 1.0 / stripes) * stripes
	var edge := 0.04
	var v := smoothstep(0.5 - edge, 0.5 + edge, phase) * (1.0 - smoothstep(1.0 - edge, 1.0, phase))
	return Color(v, v, v)


## Red sculpting wax: a soft warm key, a deep shadow, a broad glossy
## highlight and a dark rim, in the spirit of ZBrush's red wax.
static func _wax(n: Vector3) -> Color:
	var base := Vector3(0.70, 0.17, 0.09)
	var key_dir := Vector3(-0.40, 0.60, 0.70).normalized()
	var fill_dir := Vector3(0.70, -0.10, 0.50).normalized()
	var light := Vector3(0.10, 0.03, 0.02) \
			+ Vector3(0.95, 0.80, 0.70) * _wrap(n.dot(key_dir), 0.35) \
			+ Vector3(0.25, 0.10, 0.08) * _wrap(n.dot(fill_dir), 0.5)
	var spec := pow(maxf(n.dot(_half(key_dir)), 0.0), 18.0) * 0.35
	var rim := pow(1.0 - maxf(n.z, 0.0), 3.0) * 0.12
	return _lit(base * light + Vector3(1.0, 0.85, 0.75) * spec - Vector3.ONE * rim)


## Polished metal reflecting a bright sky above a dark floor, with a soft
## horizon and a Fresnel brightening at the rim. Blender's metal_shiny.
static func _chrome(n: Vector3) -> Color:
	var r := 2.0 * n.dot(VIEW) * n - VIEW
	var horizon := smoothstep(-0.08, 0.10, r.y)
	var sky := Vector3(0.78, 0.84, 0.92) * (0.6 + 0.4 * clampf(r.y, 0.0, 1.0))
	var ground := Vector3(0.16, 0.14, 0.12) * (0.5 + 0.5 * clampf(-r.y, 0.0, 1.0))
	var color := ground.lerp(sky, horizon)
	var key_dir := Vector3(-0.45, 0.55, 0.70).normalized()
	var spec := pow(maxf(n.dot(_half(key_dir)), 0.0), 120.0) * 0.5
	var fresnel := pow(1.0 - maxf(n.z, 0.0), 3.0) * 0.25
	return _lit(color + Vector3.ONE * (spec + fresnel))


static func _wrap(ndl: float, wrap: float) -> float:
	return clampf((ndl + wrap) / (1.0 + wrap), 0.0, 1.0)


static func _half(light_dir: Vector3) -> Vector3:
	return (light_dir + VIEW).normalized()


static func _lit(linear: Vector3) -> Color:
	return Color(clampf(linear.x, 0.0, 1.0), clampf(linear.y, 0.0, 1.0), clampf(linear.z, 0.0, 1.0)).linear_to_srgb()

