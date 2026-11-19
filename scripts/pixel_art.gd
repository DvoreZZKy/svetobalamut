class_name PixelArt
extends RefCounted

static var _cache: Dictionary = {}

static func make_player(kind: int) -> Texture2D:
	var k := posmod(kind, 4)
	if _cache.has(k):
		return _cache[k]
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match k:
		0:
			_ellipse(img, 6, 10, 4, 5, Color("#10264e"), Color("#62eaff"))
			_ellipse(img, 18, 10, 4, 5, Color("#10264e"), Color("#62eaff"))
			_ellipse(img, 12, 12, 5, 6, Color("#10264e"), Color("#263f78"))
			_rect(img, 10, 11, 2, 2, Color.WHITE)
			_rect(img, 14, 11, 2, 2, Color.WHITE)
			_ellipse(img, 12, 17, 3, 3, Color("#ff9d22"), Color("#fff07a"))
			_rect(img, 8, 3, 1, 3, Color("#172650"))
			_rect(img, 15, 3, 1, 3, Color("#172650"))
			_rect(img, 7, 2, 2, 2, Color("#ffe77a"))
			_rect(img, 15, 2, 2, 2, Color("#ffe77a"))
			_rect(img, 8, 17, 2, 3, Color("#172650"))
			_rect(img, 14, 17, 2, 3, Color("#172650"))
		1:
			_rect(img, 7, 3, 10, 18, Color("#10264e"))
			_ellipse(img, 12, 5, 5, 3, Color("#10264e"), Color("#35eaff"))
			_rect(img, 8, 5, 8, 13, Color("#28c9e8"))
			_rect(img, 9, 3, 6, 2, Color("#5df3ff"))
			_rect(img, 8, 17, 8, 2, Color("#1689b8"))
			_rect(img, 9, 8, 6, 5, Color("#10264e"))
			_rect(img, 10, 9, 2, 2, Color.WHITE)
			_rect(img, 13, 9, 2, 2, Color.WHITE)
			_rect(img, 5, 9, 2, 6, Color("#ff9b3d"))
			_rect(img, 17, 9, 2, 6, Color("#ff9b3d"))
			_rect(img, 8, 20, 3, 2, Color("#10264e"))
			_rect(img, 13, 20, 3, 2, Color("#10264e"))
			_rect(img, 11, 15, 2, 2, Color("#ffe36e"))
		2:
			_ellipse(img, 12, 9, 8, 8, Color("#33245f"), Color("#d9c4ff"))
			_rect(img, 5, 9, 14, 8, Color("#d9c4ff"))
			_rect(img, 5, 14, 3, 4, Color("#d9c4ff"))
			_rect(img, 10, 14, 3, 5, Color("#d9c4ff"))
			_rect(img, 16, 14, 3, 4, Color("#d9c4ff"))
			_rect(img, 7, 8, 10, 8, Color("#f1eaff"))
			_rect(img, 8, 10, 2, 4, Color("#302052"))
			_rect(img, 14, 10, 2, 4, Color("#302052"))
			_rect(img, 10, 15, 4, 1, Color("#9c7ee8"))
			_rect(img, 6, 17, 3, 2, Color("#d9c4ff"))
			_rect(img, 11, 18, 3, 2, Color("#d9c4ff"))
			_rect(img, 16, 17, 3, 2, Color("#d9c4ff"))
		3:
			var widths := [1, 2, 3, 4, 5, 6, 5, 4, 3, 2, 1]
			for row in widths.size():
				var w: int = widths[row]
				var y := 4 + row
				_rect(img, 12 - w, y, w * 2, 1, Color("#17265d"))
				_rect(img, 13 - w, y, w * 2 - 2, 1, Color("#5b42d7") if row > 5 else Color("#24c9f5"))
			_rect(img, 10, 7, 2, 7, Color("#8af8ff"))
			_rect(img, 12, 8, 3, 6, Color("#a48aff"))
			_rect(img, 10, 11, 4, 3, Color.WHITE)
			_rect(img, 8, 7, 2, 2, Color("#36eaff"))
			_rect(img, 14, 13, 2, 2, Color("#8b5cff"))
			_rect(img, 6, 12, 2, 4, Color("#1e9de5"))
			_rect(img, 16, 12, 2, 4, Color("#1e9de5"))
	var tex := ImageTexture.create_from_image(img)
	_cache[k] = tex
	return tex

static func _rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h), color)

static func _ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, outline: Color, fill: Color) -> void:
	for y in range(cy - ry, cy + ry + 1):
		for x in range(cx - rx, cx + rx + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var d := pow(float(x - cx) / float(rx), 2.0) + pow(float(y - cy) / float(ry), 2.0)
			if d <= 1.0:
				img.set_pixel(x, y, fill)
			elif d <= 1.55:
				img.set_pixel(x, y, outline)
