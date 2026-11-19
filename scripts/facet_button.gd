extends Button
## Кнопка с гранёным контуром вместо прямоугольной рамки.

var hovered := false

func _ready() -> void:
	flat = true
	mouse_entered.connect(func(): hovered = true; queue_redraw())
	mouse_exited.connect(func(): hovered = false; queue_redraw())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	add_theme_color_override("font_color", Color("#d9f7ff"))
	add_theme_color_override("font_hover_color", Color("#ffffff"))
	add_theme_color_override("font_pressed_color", Color("#7feaff"))
	add_theme_color_override("font_focus_color", Color("#ffffff"))
	add_theme_color_override("font_disabled_color", Color("#647487"))
	add_theme_font_size_override("font_size", 21)

func _draw() -> void:
	var w := size.x
	var h := size.y
	var cut := minf(13.0, minf(w, h) * 0.22)
	var pts := PackedVector2Array([
		Vector2(cut, 1), Vector2(w * 0.36, 1), Vector2(w * 0.43, 4),
		Vector2(w - cut, 1), Vector2(w - 1, cut), Vector2(w - 1, h - cut),
		Vector2(w - cut, h - 1), Vector2(w * 0.62, h - 1), Vector2(w * 0.55, h - 4),
		Vector2(cut, h - 1), Vector2(1, h - cut), Vector2(1, cut)
	])
	var fill := Color("#101a2a", 0.94)
	var edge := Color("#35cce5", 0.95)
	if hovered:
		fill = Color("#182b42", 0.98)
		edge = Color("#82f1ff")
	if button_pressed:
		fill = Color("#203b52", 1.0)
		edge = Color("#c0fbff")
	draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, edge, 2.0, true)
	# Короткие внутренние фаски дают ощущение объёмной грани.
	draw_line(Vector2(cut + 4, 5), Vector2(w * 0.34, 5), Color(edge, 0.28), 1.0, true)
