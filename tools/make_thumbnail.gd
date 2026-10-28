extends SceneTree
## Bakes the Asset Store thumbnail, docs/store/thumbnail.png at 1280x720: the
## scene as lit on the left and in Workbench on the right, from the README
## images, split down the middle with a thin seam. Both are cropped to a
## centred 16:9 first so the two halves line up.
## Run headless: godot --headless --path . -s res://tools/make_thumbnail.gd

const LEFT := "res://docs/images/before_fog.webp"
const RIGHT := "res://docs/images/studio.webp"
const OUTPUT := "res://docs/store/thumbnail.png"
const WIDTH := 1280
const HEIGHT := 720
const SEAM := 4
const SEAM_COLOR := Color(0.11, 0.11, 0.11)
## Fraction trimmed from each edge after the 16:9 crop, to leave the editor's
## viewport label and gizmo out of the picture.
const INSET := 0.08


func _initialize() -> void:
	var left := _load_16_9(LEFT)
	var right := _load_16_9(RIGHT)
	if left == null or right == null:
		quit(1)
		return
	var thumbnail := Image.create_empty(WIDTH, HEIGHT, false, Image.FORMAT_RGB8)
	var half := WIDTH / 2
	thumbnail.blit_rect(left, Rect2i(0, 0, half, HEIGHT), Vector2i.ZERO)
	thumbnail.blit_rect(right, Rect2i(half, 0, WIDTH - half, HEIGHT), Vector2i(half, 0))
	thumbnail.fill_rect(Rect2i(half - SEAM / 2, 0, SEAM, HEIGHT), SEAM_COLOR)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	var error := thumbnail.save_png(OUTPUT)
	print("Wrote %s (%s)" % [OUTPUT, error_string(error)])
	quit(0 if error == OK else 1)


## The image cropped to a centred 16:9 and resized to the thumbnail size.
func _load_16_9(path: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null:
		print("FAIL: can't load %s" % path)
		return null
	var width := image.get_width()
	var height := image.get_height()
	var wanted_height := int(round(width * 9.0 / 16.0))
	if wanted_height <= height:
		image = image.get_region(Rect2i(0, (height - wanted_height) / 2, width, wanted_height))
	else:
		var wanted_width := int(round(height * 16.0 / 9.0))
		image = image.get_region(Rect2i((width - wanted_width) / 2, 0, wanted_width, height))
	var inset := Vector2i(int(image.get_width() * INSET), int(image.get_height() * INSET))
	image = image.get_region(Rect2i(inset, image.get_size() - inset * 2))
	image.convert(Image.FORMAT_RGB8)
	image.resize(WIDTH, HEIGHT, Image.INTERPOLATE_LANCZOS)
	return image
