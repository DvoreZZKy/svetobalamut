extends Control
## Неоновый логотип из плавных световых трубок с мягкими изгибами и живым свечением.

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


func _draw_tube(points: PackedVector2Array, width: float, color: Color) -> void:
	if points.size() < 2:
		return
	draw_polyline(points, color, width, true)
	var cap_radius := width * 0.5
	draw_circle(points[0], cap_radius, color, true)
	draw_circle(points[-1], cap_radius, color, true)


func _draw_path(points: Array, origin: Vector2, glyph_size: Vector2, width: float, color: Color) -> void:
	var raw := PackedVector2Array()
	for point in points:
		raw.append(origin + Vector2(point[0] * glyph_size.x, point[1] * glyph_size.y))
	var smooth := _smooth_points(raw, 6)
	_draw_tube(smooth, width, color)


func _draw() -> void:
	var glyph_w := 45.0
	var glyph_h := 70.0
	var gap := 7.0
	var total := WORD.length() * glyph_w + (WORD.length() - 1) * gap
	var scale_factor := minf((size.x - 40.0) / total, (size.y - 24.0) / glyph_h)
	var w := glyph_w * scale_factor
	var h := glyph_h * scale_factor
	var spacing := gap * scale_factor
	var word_width := WORD.length() * w + (WORD.length() - 1) * spacing
	var start := Vector2((size.x - word_width) * 0.5, (size.y - h) * 0.5 - 5.0 * scale_factor)
	var pulse := 0.78 + 0.22 * sin(phase * 2.1)
	for i in WORD.length():
		var letter := WORD.substr(i, 1)
		var paths: Array = GLYPHS.get(letter, [])
		var origin := start + Vector2(i * (w + spacing), 0)
		for path in paths:
			_draw_path(path, origin + Vector2(0, 1.0), Vector2(w, h), 18.0 * scale_factor, Color("#963cff", 0.10 * pulse))
		for path in paths:
			_draw_path(path, origin, Vector2(w, h), 13.0 * scale_factor, Color("#12cfff", 0.16 * pulse))
		for path in paths:
			_draw_path(path, origin, Vector2(w, h), 7.0 * scale_factor, Color("#43eaff", 0.9))
		for path in paths:
			_draw_path(path, origin, Vector2(w, h), 2.5 * scale_factor, Color("#eaffff"))
	var y := start.y + h + 9.0 * scale_factor
	var left := start.x + 8.0 * scale_factor
	var right := start.x + word_width - 8.0 * scale_factor
	var accent := Color("#48eaff", 0.55 + 0.25 * pulse)
	draw_line(Vector2(left, y), Vector2(size.x * 0.38, y), accent, 1.5 * scale_factor, true)
	draw_line(Vector2(size.x * 0.62, y), Vector2(right, y), Color("#a982ff", accent.a), 1.5 * scale_factor, true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(size.x * 0.38, y), Vector2(size.x * 0.5, y - 3.0 * scale_factor),
		Vector2(size.x * 0.62, y)
	]), Color("#d8faff", 0.8))
