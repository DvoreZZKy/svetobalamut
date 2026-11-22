extends Node2D
## Четыре читаемых силуэта с небольшим количеством крупных граней.

var kind := 0
var tint := Color("#54eaff")
var outfit := 0
var hat := 0

func setup(p_kind: int, p_tint: Color, p_outfit: int, p_hat: int) -> void:
	kind = maxi(0, p_kind)
	tint = p_tint
	outfit = posmod(p_outfit, 5)
	hat = posmod(p_hat, 5)
	queue_redraw()


func _shape(points: Array, fill: Color, edge: Color = Color.WHITE, width: float = 3.0) -> void:
	var poly := PackedVector2Array(points)
	draw_colored_polygon(poly, fill)
	var closed := poly.duplicate()
	closed.append(poly[0])
	draw_polyline(closed, edge, width, true)


func _draw() -> void:
	var dark := tint.darkened(0.62)
	var bright := tint.lightened(0.42)
	match kind:
		0: # Светляк: крылья и короткое светящееся тело.
			_shape([Vector2(-8,-4),Vector2(-23,-18),Vector2(-27,-14),Vector2(-17,5),Vector2(-7,8)], bright, bright, 2.5)
			_shape([Vector2(8,-4),Vector2(23,-18),Vector2(27,-14),Vector2(17,5),Vector2(7,8)], bright, bright, 2.5)
			_shape([Vector2(-10,-14),Vector2(10,-14),Vector2(13,8),Vector2(0,23),Vector2(-13,8)], dark, bright, 3.5)
			_shape([Vector2(-7,-9),Vector2(7,-9),Vector2(8,8),Vector2(0,17),Vector2(-8,8)], tint, tint.lightened(0.7), 2.0)
			draw_line(Vector2(-5,-14),Vector2(-12,-27),bright,3.0,true)
			draw_line(Vector2(5,-14),Vector2(12,-27),bright,3.0,true)
		1: # Капсула: широкий корпус и одно большое окно.
			_shape([Vector2(-17,-22),Vector2(12,-22),Vector2(20,-12),Vector2(20,13),Vector2(10,24),Vector2(-10,24),Vector2(-20,13),Vector2(-20,-12)], dark, bright, 4.0)
			_shape([Vector2(-12,-15),Vector2(12,-15),Vector2(14,3),Vector2(9,15),Vector2(-9,15),Vector2(-14,3)], tint, bright, 2.5)
			_shape([Vector2(-8,-9),Vector2(8,-9),Vector2(8,1),Vector2(-8,1)], Color("#d9fbff"), Color("#d9fbff"), 1.0)
		2: # Призрак: плавающий силуэт с гранёным низом.
			_shape([Vector2(-19,17),Vector2(-20,-5),Vector2(-14,-20),Vector2(-7,-25),Vector2(7,-25),Vector2(14,-20),Vector2(20,-5),Vector2(19,17),Vector2(8,10),Vector2(0,20),Vector2(-8,10)], dark, bright, 3.5)
			_shape([Vector2(-12,-10),Vector2(-5,-17),Vector2(5,-17),Vector2(12,-10),Vector2(10,1),Vector2(-10,1)], Color("#f5f1ff"), Color("#f5f1ff"), 1.0)
			draw_line(Vector2(-7,7),Vector2(7,7),Color("#7557b9"),3.0,true)
		3: # Кристалл: ромб с тремя крупными плоскостями.
			_shape([Vector2(0,-28),Vector2(20,-9),Vector2(16,12),Vector2(0,28),Vector2(-16,12),Vector2(-20,-9)], dark, bright, 4.0)
			_shape([Vector2(0,-21),Vector2(12,-8),Vector2(0,2),Vector2(-12,-8)], bright, bright, 1.0)
			_shape([Vector2(-12,-5),Vector2(0,4),Vector2(0,21),Vector2(-13,10)], tint, bright, 1.5)
			_shape([Vector2(12,-5),Vector2(13,10),Vector2(0,21),Vector2(0,4)], tint.darkened(0.2), bright, 1.5)
	if kind >= 4:
		var emblem_id := posmod(kind - 4, 15)
		match emblem_id:
			0:
				draw_arc(Vector2.ZERO, 25.0, -1.2, 1.2, 18, bright, 3.0, true)
			1:
				draw_circle(Vector2.ZERO, 5.0, bright)
				draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 24, bright, 2.0, true)
			2:
				_shape([Vector2(-9,-8),Vector2(9,-8),Vector2(15,8),Vector2(0,18),Vector2(-15,8)], bright, bright, 2.0)
			3:
				for i in 8:
					draw_line(Vector2.ZERO, Vector2.from_angle(TAU * float(i) / 8.0) * 25.0, bright, 2.5, true)
			4:
				draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 24, bright, 3.0, true)
				draw_circle(Vector2.ZERO, 4.0, Color.WHITE)
			5:
				for i in 3:
					draw_line(Vector2(-18, -12 + i * 12), Vector2(18, -12 + i * 12), bright, 2.0, true)
			6:
				_shape([Vector2(0,-20),Vector2(17,0),Vector2(0,20),Vector2(-17,0)], bright, bright, 2.0)
			7:
				draw_arc(Vector2.ZERO, 24.0, -0.8, 0.8, 16, bright, 4.0, true)
			8:
				draw_line(Vector2(-18,-18), Vector2(18,18), bright, 4.0, true)
				draw_line(Vector2(-18,18), Vector2(18,-18), bright, 4.0, true)
			9:
				for i in 4:
					draw_circle(Vector2.from_angle(TAU * float(i) / 4.0) * 22.0, 4.0, bright)
			10:
				draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 24, bright, 3.0, true)
				draw_circle(Vector2.ZERO, 8.0, dark)
			11:
				for i in 3:
					draw_line(Vector2(-18, -12 + i * 12), Vector2(18, -12 + i * 12), bright, 3.0, true)
			12:
				draw_circle(Vector2.ZERO, 8.0, bright)
				draw_arc(Vector2.ZERO, 23.0, 0.0, TAU, 24, bright, 2.5, true)
			13:
				draw_line(Vector2(-20,0), Vector2(20,0), bright, 4.0, true)
				draw_line(Vector2(0,-20), Vector2(0,20), bright, 4.0, true)
			14:
				draw_arc(Vector2.ZERO, 27.0, -1.0, 1.0, 20, bright, 3.5, true)
				draw_arc(Vector2.ZERO, 19.0, 2.1, 4.2, 20, bright, 2.5, true)
	if outfit > 0:
		var cloth: Color = [Color("#26334f"), Color("#f4d35e"), Color("#3ddc97"), Color("#f05d9b"), Color("#d6e4ff")][outfit]
		match kind:
			0: _shape([Vector2(-7,-3),Vector2(7,-3),Vector2(5,10),Vector2(0,15),Vector2(-5,10)], cloth, cloth.lightened(0.35), 2.0)
			1: _shape([Vector2(-14,4),Vector2(14,4),Vector2(10,17),Vector2(-10,17)], cloth, cloth.lightened(0.35), 2.0)
			2: _shape([Vector2(-14,1),Vector2(14,1),Vector2(16,13),Vector2(0,20),Vector2(-16,13)], cloth, cloth.lightened(0.35), 2.0)
			3: _shape([Vector2(0,-8),Vector2(10,0),Vector2(6,12),Vector2(0,17),Vector2(-6,12),Vector2(-10,0)], cloth, cloth.lightened(0.35), 2.0)
	match hat:
		1: _shape([Vector2(-17,-24),Vector2(-12,-38),Vector2(-4,-30),Vector2(0,-43),Vector2(5,-30),Vector2(13,-38),Vector2(18,-24)], Color("#ffd65c"), Color("#fff0ad"), 2.5)
		2: _shape([Vector2(-17,-23),Vector2(17,-23),Vector2(12,-34),Vector2(-12,-34)], Color("#e85e7e"), Color("#ffafc0"), 2.5)
		3: _shape([Vector2(-15,-22),Vector2(-25,-36),Vector2(-5,-28),Vector2(0,-22),Vector2(7,-28),Vector2(25,-36),Vector2(15,-22)], Color("#b88cff"), Color("#e0caff"), 2.5)
		4: _shape([Vector2(-16,-27),Vector2(-10,-40),Vector2(0,-45),Vector2(10,-40),Vector2(16,-27)], Color("#9cefff"), Color("#e3fcff"), 2.5)
