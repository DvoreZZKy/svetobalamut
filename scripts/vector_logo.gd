extends Control
## Неоновый логотип. Сглаженная геометрия кешируется и перестраивается только при изменении размера.

const GLYPHS := {
	"С": [[[0.92,0.08],[0.20,0.08],[0.04,0.24],[0.04,0.76],[0.20,0.92],[0.92,0.92]]],
	"В": [[[0.08,0.08],[0.70,0.08],[0.92,0.22],[0.92,0.38],[0.76,0.50],[0.08,0.50]],[[0.08,0.50],[0.76,0.50],[0.92,0.62],[0.92,0.78],[0.70,0.92],[0.08,0.92]]],
	"Е": [[[0.92,0.08],[0.08,0.08],[0.08,0.92],[0.92,0.92]],[[0.08,0.50],[0.78,0.50]]],
	"Т": [[[0.02,0.08],[0.98,0.08]],[[0.50,0.08],[0.50,0.92]]],
	"О": [[[0.22,0.08],[0.78,0.08],[0.96,0.24],[0.96,0.76],[0.78,0.92],[0.22,0.92],[0.04,0.76],[0.04,0.24],[0.22,0.08]]],
	"Б": [[[0.92,0.08],[0.08,0.08],[0.08,0.92],[0.72,0.92],[0.94,0.76],[0.94,0.62],[0.76,0.50],[0.08,0.50]]],
	"А": [[[0.04,0.92],[0.40,0.08],[0.60,0.08],[0.96,0.92]],[[0.22,0.58],[0.78,0.58]]],
	"Л": [[[0.04,0.92],[0.40,0.08],[0.60,0.08],[0.96,0.92]]],
	"М": [[[0.06,0.92],[0.06,0.08],[0.50,0.56],[0.94,0.08],[0.94,0.92]]],
	"У": [[[0.04,0.08],[0.48,0.52],[0.96,0.08]],[[0.48,0.52],[0.24,0.92]]]
}
const WORD := "СВЕТОБАЛАМУТ"
var phase := 0.0
var _cached_size := Vector2.ZERO
var _cached_paths: Array[PackedVector2Array] = []
var _cached_left := Vector2.ZERO
var _cached_mid_left := Vector2.ZERO
var _cached_mid_right := Vector2.ZERO
var _cached_right := Vector2.ZERO
var _cached_triangle := PackedVector2Array()
var _cached_stroke_scale := 1.0


func _process(dt: float) -> void:
	phase += dt
	queue_redraw()


func _smooth_points(points: PackedVector2Array, steps: int = 5) -> PackedVector2Array:
	if points.size() < 3:
		return points
	var result := PackedVector2Array()
	for i in range(points.size() - 1):
		var p0: Vector2 = points[maxi(i - 1, 0)]
		var p1: Vector2 = points[i]
		var p2: Vector2 = points[i + 1]
		var p3: Vector2 = points[mini(i + 2, points.size() - 1)]
		for j in range(steps):
			var t := float(j) / float(steps)
			var t2 := t * t
			var t3 := t2 * t
			var point := 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
			result.append(point)
	result.append(points[-1])
	return result


func _rebuild_geometry() -> void:
	_cached_size = size
	_cached_paths.clear()
	var glyph_w := 45.0
	var glyph_h := 70.0
	var gap := 7.0
	var total := WORD.length() * glyph_w + (WORD.length() - 1) * gap
	var scale_factor := minf((size.x - 40.0) / total, (size.y - 24.0) / glyph_h)
	_cached_stroke_scale = scale_factor
	var w := glyph_w * scale_factor
	var h := glyph_h * scale_factor
	var spacing := gap * scale_factor
	var word_width := WORD.length() * w + (WORD.length() - 1) * spacing
	var start := Vector2((size.x - word_width) * 0.5, (size.y - h) * 0.5 - 5.0 * scale_factor)
	for i in WORD.length():
		var letter := WORD.substr(i, 1)
		var paths: Array = GLYPHS.get(letter, [])
		var origin := start + Vector2(i * (w + spacing), 0)
		for path in paths:
			var raw := PackedVector2Array()
			for point in path:
				raw.append(origin + Vector2(point[0] * w, point[1] * h))
			_cached_paths.append(_smooth_points(raw, 6))
	var y := start.y + h + 9.0 * scale_factor
	_cached_left = Vector2(start.x + 8.0 * scale_factor, y)
	_cached_mid_left = Vector2(size.x * 0.38, y)
	_cached_mid_right = Vector2(size.x * 0.62, y)
	_cached_right = Vector2(start.x + word_width - 8.0 * scale_factor, y)
	_cached_triangle = PackedVector2Array([
		_cached_mid_left, Vector2(size.x * 0.5, y - 3.0 * scale_factor), _cached_mid_right
	])


func _draw_tube(points: PackedVector2Array, width: float, color: Color) -> void:
	if points.size() < 2:
		return
	draw_polyline(points, color, width, true)
	var cap_radius := width * 0.5
	draw_circle(points[0], cap_radius, color, true)
	draw_circle(points[-1], cap_radius, color, true)


func _draw() -> void:
	if _cached_size != size:
		_rebuild_geometry()
	if _cached_paths.is_empty():
		return
	var pulse := 0.78 + 0.22 * sin(phase * 2.1)
	var glow_width := 18.0 * _cached_stroke_scale
	for path in _cached_paths:
		_draw_tube(path, glow_width, Color("#963cff", 0.10 * pulse))
	glow_width = 13.0 * _cached_stroke_scale
	for path in _cached_paths:
		_draw_tube(path, glow_width, Color("#12cfff", 0.16 * pulse))
	glow_width = 7.0 * _cached_stroke_scale
	for path in _cached_paths:
		_draw_tube(path, glow_width, Color("#43eaff", 0.9))
	glow_width = 2.5 * _cached_stroke_scale
	for path in _cached_paths:
		_draw_tube(path, glow_width, Color("#eaffff"))
	var accent := Color("#48eaff", 0.55 + 0.25 * pulse)
	draw_line(_cached_left, _cached_mid_left, accent, 1.5 * _cached_stroke_scale, true)
	draw_line(_cached_mid_right, _cached_right, Color("#a982ff", accent.a), 1.5 * _cached_stroke_scale, true)
	draw_colored_polygon(_cached_triangle, Color("#d8faff", 0.8))
