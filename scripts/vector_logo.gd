extends Control
## Геометрический логотип: буквы собраны из прямых отрезков с фасками.

const GLYPHS := {
	"С": [[[0.92,0.08],[0.20,0.08],[0.04,0.24],[0.04,0.76],[0.20,0.92],[0.92,0.92]]],
	"В": [[[0.08,0.08],[0.72,0.08],[0.94,0.24],[0.94,0.40],[0.76,0.50],[0.08,0.50],[0.76,0.50],[0.94,0.62],[0.94,0.78],[0.74,0.92],[0.08,0.92],[0.08,0.08]]],
	"Е": [[[0.92,0.08],[0.08,0.08],[0.08,0.92],[0.92,0.92]],[[0.08,0.50],[0.78,0.50]]],
	"Т": [[[0.02,0.08],[0.98,0.08]],[[0.50,0.08],[0.50,0.92]]],
	"О": [[[0.22,0.08],[0.78,0.08],[0.96,0.24],[0.96,0.76],[0.78,0.92],[0.22,0.92],[0.04,0.76],[0.04,0.24],[0.22,0.08]]],
	"Б": [[[0.92,0.08],[0.08,0.08],[0.08,0.92],[0.74,0.92],[0.94,0.76],[0.94,0.62],[0.76,0.50],[0.08,0.50]]],
	"А": [[[0.04,0.92],[0.40,0.08],[0.60,0.08],[0.96,0.92]],[[0.22,0.58],[0.78,0.58]]],
	"Л": [[[0.04,0.92],[0.40,0.08],[0.60,0.08],[0.96,0.92]]],
	"М": [[[0.06,0.92],[0.06,0.08],[0.50,0.56],[0.94,0.08],[0.94,0.92]]],
	"У": [[[0.04,0.08],[0.48,0.52],[0.96,0.08]],[[0.48,0.52],[0.24,0.92]]]
}
const WORD := "СВЕТОБАЛАМУТ"


func _draw_segment(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	var dir := (b - a).normalized()
	var normal := Vector2(-dir.y, dir.x) * width * 0.5
	var bevel := minf(3.0, a.distance_to(b) * 0.12)
	var points := PackedVector2Array([
		a + dir * bevel + normal, b - dir * bevel + normal,
		b - dir * bevel * 0.45, b - dir * bevel - normal,
		a + dir * bevel - normal, a + dir * bevel * 0.45
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
	var scale_factor := minf((size.x - 40.0) / total, (size.y - 12.0) / glyph_h)
	var w := glyph_w * scale_factor
	var h := glyph_h * scale_factor
	var spacing := gap * scale_factor
	var start := Vector2((size.x - (WORD.length() * w + (WORD.length() - 1) * spacing)) * 0.5, (size.y - h) * 0.5)
	for i in WORD.length():
		var letter := WORD.substr(i, 1)
		var paths: Array = GLYPHS.get(letter, [])
		var origin := start + Vector2(i * (w + spacing), 0)
		for path in paths:
			_draw_path(path, origin, Vector2(w, h), 10.0 * scale_factor, Color("#39cfe9", 0.22))
		for path in paths:
			_draw_path(path, origin, Vector2(w, h), 5.2 * scale_factor, Color("#d9faff"))
		for path in paths:
			_draw_path(path, origin, Vector2(w, h), 1.2 * scale_factor, Color("#63eaff"))
