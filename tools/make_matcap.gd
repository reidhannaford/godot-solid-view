extends SceneTree
## Bakes the bundled clay matcap: a sphere lit by a warm key from the upper
## left, a cool fill from the right and a faint rim, written as an sRGB PNG.
## Run headless: godot --headless --path . -s res://tools/make_matcap.gd

const SIZE := 256
const OUTPUT := "res://addons/solid_view/matcaps/clay.png"


func _initialize() -> void:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y: int in SIZE:
		for x: int in SIZE:
			var p := Vector2((x + 0.5) / SIZE * 2.0 - 1.0, 1.0 - (y + 0.5) / SIZE * 2.0)
			if p.length_squared() > 1.0:
				p = p.normalized() * 0.9995
			var n := Vector3(p.x, p.y, sqrt(maxf(1.0 - p.length_squared(), 0.0)))
			var c := _shade(n)
			image.set_pixel(x, y, Color(c.x, c.y, c.z).linear_to_srgb())
	var error := image.save_png(OUTPUT)
	print("Wrote %s (%s)" % [OUTPUT, error_string(error)])
	quit(0 if error == OK else 1)


func _shade(n: Vector3) -> Vector3:
	var base := Vector3(0.80, 0.74, 0.68)
	var key_dir := Vector3(-0.45, 0.60, 0.65).normalized()
	var fill_dir := Vector3(0.80, 0.05, 0.40).normalized()
	var rim_dir := Vector3(0.20, -0.70, -0.40).normalized()
	var light := Vector3(0.07, 0.07, 0.08) \
			+ Vector3(0.66, 0.62, 0.56) * _wrap(n.dot(key_dir), 0.25) \
			+ Vector3(0.18, 0.20, 0.26) * _wrap(n.dot(fill_dir), 0.4) \
			+ Vector3(0.14, 0.13, 0.11) * _wrap(n.dot(rim_dir), 0.0)
	var half_dir := (key_dir + Vector3(0.0, 0.0, 1.0)).normalized()
	var spec := pow(maxf(n.dot(half_dir), 0.0), 40.0) * 0.14
	var fresnel := pow(1.0 - maxf(n.z, 0.0), 4.0) * 0.08
	return base * light + Vector3.ONE * (spec + fresnel)


func _wrap(ndl: float, wrap: float) -> float:
	return clampf((ndl + wrap) / (1.0 + wrap), 0.0, 1.0)
