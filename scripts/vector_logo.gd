extends Control
## Геометрический неоновый логотип: рубленые штрихи, фаски и многослойное свечение.

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


func _draw_segment(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	var delta := b - a
	if delta.length_squared() < 0.001:
		return
	var dir := delta.normalized()
	var normal := Vector2(-dir.y, dir.x) * width * 0.5
	var bevel := minf(width * 0.48, delta.length() * 0.14)
	var points := PackedVector2Array([
		a + dir * bevel + normal, b - dir * bevel + normal,
		b - dir * bevel * 0.35, b - dir * bevel - normal,
		a + dir * bevel - normal, a + dir * bevel * 0.35
	])
	draw_colored_polygon(points, color)


func _draw_path(points: Array, origin: Vector2, glyph_size: Vector2, width: float, color: Color) -> void:
	for i in range(points.size() - 1):
		var a := origin + Vector2(points[i][0] * glyph_size.x, points[i][1] * glyph_size.y)
		var b := origin + Vector2(points[i + 1][0] * glyph_size.x, points[i + 1][1] * glyph_size.y)
		_draw_segment(a, b, width, color)


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
			_draw_path(path, origin + Vector2(0, 1.2), Vector2(w, h), 12.0 * scale_factor, Color("#8b4dff", 0.11 * pulse))
		for path in paths:
			_draw_path(path, origin, Vector2(w, h), 9.0 * scale_factor, Color("#22dfff", 0.25 * pulse))
		for path in paths:
			_draw_path(path, origin, Vector2(w, h), 5.0 * scale_factor, Color("#e6fbff"))
		for path in paths:
			_draw_path(path, origin, Vector2(w, h), 1.35 * scale_factor, Color("#7ceeff"))
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
