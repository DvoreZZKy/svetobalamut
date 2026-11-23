extends Node2D
## Четыре читаемых силуэта с небольшим количеством крупных граней.

var kind := 0
var tint := Color("#54eaff")
var outfit := 0
var hat := 0
var anim_time := 0.0

func setup(p_kind: int, p_tint: Color, p_outfit: int, p_hat: int) -> void:
	kind = maxi(0, p_kind)
	tint = p_tint
	outfit = posmod(p_outfit, 5)
	hat = posmod(p_hat, 5)
	queue_redraw()


func _process(dt: float) -> void:
	anim_time += dt
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
	if kind < 4:
		match posmod(kind, 4):
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
		# Newer classes use their own animated core instead of reusing one of the four
		# original silhouettes underneath their class-specific ornaments.
		var core_pulse := 1.0 + 0.07 * sin(anim_time * 5.2 + float(kind))
		_shape([Vector2(0, -20), Vector2(16, -12), Vector2(20, 5), Vector2(10, 20), Vector2(-10, 20), Vector2(-20, 5), Vector2(-16, -12)], dark, bright, 3.0)
		draw_circle(Vector2.ZERO, 11.0 * core_pulse, tint.lightened(0.22))
		draw_circle(Vector2.ZERO, 4.0 * core_pulse, Color.WHITE)
		var orbit_angle := anim_time * (1.1 if kind % 2 == 0 else -1.1) + float(kind)
		draw_arc(Vector2.ZERO, 32.0 + 2.0 * sin(anim_time * 3.0), orbit_angle, orbit_angle + PI * 1.35, 28, Color(bright, 0.82), 2.4, true)
		var spark_pos := Vector2.from_angle(orbit_angle) * 32.0
		draw_circle(spark_pos, 3.2, Color.WHITE)
		var emblem_id := posmod(kind - 4, 15)
		# Каждый новый класс получает собственный силуэтный декор и фактуру.
		match emblem_id:
			0: # Импульс — электрические плавники и молнии.
				_shape([Vector2(-16,-8),Vector2(-34,-20),Vector2(-28,0),Vector2(-34,20),Vector2(-13,9)], bright, bright, 2.0)
				_shape([Vector2(16,-8),Vector2(34,-20),Vector2(28,0),Vector2(34,20),Vector2(13,9)], bright, bright, 2.0)
				draw_line(Vector2(-8,-17),Vector2(2,-5),Color.WHITE,2.5,true)
				draw_line(Vector2(2,-5),Vector2(-5,5),Color.WHITE,2.5,true)
				draw_line(Vector2(-5,5),Vector2(8,17),Color.WHITE,2.5,true)
			1: # Магнит — полюса и металлические дуги.
				draw_arc(Vector2.ZERO, 29.0, PI, TAU, 24, Color("#ff657d"), 5.0, true)
				draw_arc(Vector2.ZERO, 29.0, 0.0, PI, 24, Color("#62caff"), 5.0, true)
				draw_rect(Rect2(-20,-4,10,9), Color("#ff657d"))
				draw_rect(Rect2(10,-4,10,9), Color("#62caff"))
			2: # Слизень — мягкие капли и пузырьки.
				_shape([Vector2(-22,8),Vector2(-19,-8),Vector2(-8,-16),Vector2(12,-13),Vector2(23,0),Vector2(18,15),Vector2(0,22),Vector2(-18,17)], tint.lightened(0.18), bright, 2.5)
				for i in 4:
					draw_circle(Vector2(-12.0 + float(i) * 8.0, 2.0 + float(i % 2) * 7.0), 2.2, Color("#eaffc2"))
				draw_circle(Vector2(20,-22), 4.0, bright)
			3: # Сверхнова — корона солнечных лучей.
				for i in 12:
					var angle := TAU * float(i) / 12.0
					draw_line(Vector2.from_angle(angle) * 25.0, Vector2.from_angle(angle) * 36.0, bright, 3.0, true)
				draw_circle(Vector2.ZERO, 8.0, Color("#fff0a1"))
				draw_circle(Vector2.ZERO, 4.0, Color.WHITE)
			4: # Мираж — двойной контур-призрак.
				draw_arc(Vector2(-13,-3), 22.0, -1.3, 1.3, 20, Color(bright, 0.7), 3.0, true)
				draw_arc(Vector2(13,3), 22.0, PI - 1.3, PI + 1.3, 20, Color(bright, 0.7), 3.0, true)
				draw_circle(Vector2(-11,-4), 3.0, Color.WHITE)
				draw_circle(Vector2(11,4), 3.0, Color.WHITE)
			5: # Осколок — острые кристаллические грани.
				_shape([Vector2(0,-34),Vector2(8,-10),Vector2(28,-19),Vector2(13,0),Vector2(30,15),Vector2(6,10),Vector2(0,34),Vector2(-7,10),Vector2(-29,17),Vector2(-13,0),Vector2(-27,-19),Vector2(-7,-10)], bright, Color.WHITE, 2.0)
				draw_line(Vector2(-10,-3),Vector2(10,4),Color.WHITE,2.0,true)
			6: # Сингулярность — чёрное ядро и линза.
				draw_arc(Vector2.ZERO, 30.0, 0.2, 2.9, 28, bright, 3.0, true)
				draw_arc(Vector2.ZERO, 30.0, 3.35, 6.05, 28, bright, 3.0, true)
				draw_circle(Vector2.ZERO, 12.0, Color("#090719"))
				draw_circle(Vector2.ZERO, 5.0, Color("#c9a5ff"))
			7: # Рикошет — три отражающих шеврона.
				for i in 3:
					var yy := -13.0 + float(i) * 13.0
					draw_line(Vector2(-20,yy),Vector2(0,yy + 8.0),bright,3.0,true)
					draw_line(Vector2(0,yy + 8.0),Vector2(20,yy),bright,3.0,true)
			8: # Вулкан — раскалённые трещины.
				_shape([Vector2(-18,8),Vector2(-15,-8),Vector2(-5,-18),Vector2(6,-12),Vector2(18,-19),Vector2(16,5),Vector2(7,19),Vector2(-9,18)], Color("#54202b"), Color("#ff9a45"), 2.5)
				draw_line(Vector2(-8,9),Vector2(0,-2),Color("#ffe58a"),3.0,true)
				draw_line(Vector2(0,-2),Vector2(10,7),Color("#ffe58a"),3.0,true)
				draw_circle(Vector2(0,-9),4.0,Color("#fff1a1"))
			9: # Паразит — усики и сегменты.
				for side in [-1.0, 1.0]:
					draw_line(Vector2(side * 10,-13),Vector2(side * 23,-29),bright,3.0,true)
					draw_line(Vector2(side * 17,5),Vector2(side * 29,16),bright,3.0,true)
					draw_circle(Vector2(side * 24,-29),3.0,Color.WHITE)
				for i in 3:
					draw_arc(Vector2(0,0), 11.0 + float(i) * 5.0, 0.2, 2.9, 16, bright, 1.8, true)
			10: # Маятник — подвес и качающийся груз.
				draw_line(Vector2(0,-24),Vector2(0,2),bright,3.0,true)
				draw_arc(Vector2(0,0), 28.0, 0.2, 2.95, 20, bright, 2.0, true)
				_shape([Vector2(0,-2),Vector2(12,10),Vector2(0,25),Vector2(-12,10)], tint.lightened(0.3), bright, 2.5)
			11: # Губка — пористая поверхность.
				for i in 9:
					var angle := TAU * float(i) / 9.0
					draw_circle(Vector2.from_angle(angle) * 17.0, 3.0 + float(i % 2), bright)
				draw_circle(Vector2.ZERO, 6.0, tint.lightened(0.65))
			12: # Фантом — следы рывка.
				for i in 4:
					var yy := -18.0 + float(i) * 12.0
					draw_line(Vector2(-34,yy),Vector2(-20,yy),Color(bright, 0.85 - float(i) * 0.14),3.0,true)
				draw_line(Vector2(12,-13),Vector2(28,-24),bright,3.0,true)
				draw_line(Vector2(12,13),Vector2(28,24),bright,3.0,true)
			13: # Генератор — катушки и энергетическое ядро.
				draw_arc(Vector2.ZERO, 27.0, 0.0, TAU, 24, bright, 3.0, true)
				for i in 4:
					draw_circle(Vector2.from_angle(TAU * float(i) / 4.0) * 27.0, 4.0, Color("#fff0a1"))
				draw_circle(Vector2.ZERO, 8.0, bright)
			14: # Полярность — разноимённые полюса.
				draw_circle(Vector2(-13,0), 12.0, Color("#ff647d"))
				draw_circle(Vector2(13,0), 12.0, Color("#62caff"))
				draw_line(Vector2(-18,0),Vector2(-8,0),Color.WHITE,2.5,true)
				draw_line(Vector2(-13,-5),Vector2(-13,5),Color.WHITE,2.5,true)
				draw_line(Vector2(8,0),Vector2(18,0),Color.WHITE,2.5,true)
		# Световые насечки подчёркивают материал каждого нового корпуса.
		for i in 3:
			var yy := -10.0 + float(i) * 10.0
			draw_line(Vector2(-5, yy), Vector2(5, yy), Color(bright, 0.72), 1.4, true)

	if outfit > 0 and kind < 4:
		var cloth: Color = [Color("#26334f"), Color("#f4d35e"), Color("#3ddc97"), Color("#f05d9b"), Color("#d6e4ff")][outfit]
		match posmod(kind, 4):
			0: _shape([Vector2(-7,-3),Vector2(7,-3),Vector2(5,10),Vector2(0,15),Vector2(-5,10)], cloth, cloth.lightened(0.35), 2.0)
			1: _shape([Vector2(-14,4),Vector2(14,4),Vector2(10,17),Vector2(-10,17)], cloth, cloth.lightened(0.35), 2.0)
			2: _shape([Vector2(-14,1),Vector2(14,1),Vector2(16,13),Vector2(0,20),Vector2(-16,13)], cloth, cloth.lightened(0.35), 2.0)
			3: _shape([Vector2(0,-8),Vector2(10,0),Vector2(6,12),Vector2(0,17),Vector2(-6,12),Vector2(-10,0)], cloth, cloth.lightened(0.35), 2.0)
	match hat:
		1: _shape([Vector2(-17,-24),Vector2(-12,-38),Vector2(-4,-30),Vector2(0,-43),Vector2(5,-30),Vector2(13,-38),Vector2(18,-24)], Color("#ffd65c"), Color("#fff0ad"), 2.5)
		2: _shape([Vector2(-17,-23),Vector2(17,-23),Vector2(12,-34),Vector2(-12,-34)], Color("#e85e7e"), Color("#ffafc0"), 2.5)
		3: _shape([Vector2(-15,-22),Vector2(-25,-36),Vector2(-5,-28),Vector2(0,-22),Vector2(7,-28),Vector2(25,-36),Vector2(15,-22)], Color("#b88cff"), Color("#e0caff"), 2.5)
		4: _shape([Vector2(-16,-27),Vector2(-10,-40),Vector2(0,-45),Vector2(10,-40),Vector2(16,-27)], Color("#9cefff"), Color("#e3fcff"), 2.5)
