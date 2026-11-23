extends Node2D
## Персонажи рисуются из палитры игрока; белый используется только как нейтральный блик.

var kind := 0
var tint := Color("#54eaff")
var outfit := 0
var hat := 0
var anim_time := 0.0

func setup(p_kind: int, p_tint: Color, p_outfit: int, p_hat: int) -> void:
	kind = posmod(p_kind, 19)
	tint = p_tint
	outfit = posmod(p_outfit, 5)
	hat = posmod(p_hat, 5)
	queue_redraw()

func _process(dt: float) -> void:
	anim_time += dt
	queue_redraw()

func _poly(points: Array, fill: Color, edge: Color = Color.WHITE, width: float = 2.5) -> void:
	var polygon := PackedVector2Array(points)
	draw_colored_polygon(polygon, fill)
	var outline := polygon.duplicate()
	outline.append(polygon[0])
	draw_polyline(outline, edge, width, true)

func _line(a: Vector2, b: Vector2, color: Color, width: float = 2.5) -> void:
	draw_line(a, b, color, width, true)

func _ring(center: Vector2, radius: float, color: Color, width: float = 2.0, start: float = 0.0, finish: float = TAU) -> void:
	draw_arc(center, radius, start, finish, 32, color, width, true)

func _dot(pos: Vector2, radius: float, color: Color) -> void:
	draw_circle(pos, radius, color)

func _draw() -> void:
	var dark: Color = tint.darkened(0.66)
	var mid: Color = tint.darkened(0.28)
	var bright: Color = tint.lightened(0.38)
	var pale: Color = tint.lightened(0.68)
	var pulse := 0.5 + 0.5 * sin(anim_time * 2.4)
	var wobble := sin(anim_time * 4.0)
	var p := Vector2.ZERO

	match kind:
		0: # Светляк — крылья машут независимо от тела.
			var flap := sin(anim_time * 8.0) * 8.0
			_poly([Vector2(-7,-5),Vector2(-24,-20-flap),Vector2(-28,-7),Vector2(-15,8)], bright, pale)
			_poly([Vector2(7,-5),Vector2(24,-20+flap),Vector2(28,-7),Vector2(15,8)], bright, pale)
			_poly([Vector2(-10,-14),Vector2(10,-14),Vector2(13,8),Vector2(0,24),Vector2(-13,8)], dark, bright, 3.0)
			_poly([Vector2(-6,-8),Vector2(6,-8),Vector2(7,8),Vector2(0,16),Vector2(-7,8)], tint, pale)
			for i in 3:
				_dot(Vector2(sin(anim_time*1.8+float(i)*2.1)*32.0, cos(anim_time*1.8+float(i)*2.1)*20.0), 2.5, Color(bright, 0.8))
		1: # Капсула — бронированные створки сдвигаются.
			var gap := pulse * 3.0
			_poly([Vector2(-18,-22),Vector2(-3,-22-gap),Vector2(-3,21),Vector2(-12,24),Vector2(-21,12),Vector2(-21,-12)], dark, bright, 3.0)
			_poly([Vector2(18,-22),Vector2(3,-22+gap),Vector2(3,21),Vector2(12,24),Vector2(21,12),Vector2(21,-12)], mid, bright, 3.0)
			_poly([Vector2(-8,-13),Vector2(8,-13),Vector2(11,7),Vector2(0,17),Vector2(-11,7)], tint, pale)
			_line(Vector2(-5,-4),Vector2(5,-4),Color.WHITE,2.0)
			_line(Vector2(-4,3),Vector2(4,3),Color.WHITE,1.5)
		2: # Призрак — нижняя кромка плывёт волной.
			var bob := sin(anim_time*3.0)*3.0
			_poly([Vector2(-19,13+bob),Vector2(-20,-7),Vector2(-13,-21),Vector2(-6,-26),Vector2(7,-26),Vector2(15,-18),Vector2(20,-5),Vector2(18,13),Vector2(8,8+bob),Vector2(0,17-bob),Vector2(-9,9+bob)], dark, bright, 3.0)
			_poly([Vector2(-11,-10),Vector2(-5,-17),Vector2(5,-17),Vector2(11,-10),Vector2(9,0),Vector2(-9,0)], pale, Color.WHITE, 1.0)
			_line(Vector2(-7,7),Vector2(7,7),mid,2.5)
			_ring(Vector2(0,25), 5.0, Color(bright, 0.55+pulse*0.35), 1.5)
		3: # Кристалл — вращающиеся блики по неподвижным граням.
			_poly([Vector2(0,-29),Vector2(21,-8),Vector2(16,13),Vector2(0,29),Vector2(-16,13),Vector2(-21,-8)], dark, bright, 3.5)
			_poly([Vector2(0,-22),Vector2(13,-8),Vector2(0,2),Vector2(-13,-8)], bright, pale)
			_poly([Vector2(-13,-5),Vector2(0,4),Vector2(0,22),Vector2(-14,11)], tint, pale)
			_poly([Vector2(13,-5),Vector2(14,11),Vector2(0,22),Vector2(0,4)], mid, bright)
			var shine := Vector2.from_angle(anim_time*1.3) * 13.0
			_line(shine+Vector2(-4,-5),shine+Vector2(4,5),Color.WHITE,2.0)
		4: # Импульс — короткие рывки и электрические дуги.
			var jolt := Vector2(sin(anim_time*17.0)*2.8, sin(anim_time*23.0)*1.8)
			_poly([Vector2(-12,-17),Vector2(10,-20),Vector2(19,-5),Vector2(12,17),Vector2(-10,19),Vector2(-20,1)]+[jolt], dark, bright, 3.0)
			_poly([Vector2(-9,-9),Vector2(7,-12),Vector2(12,3),Vector2(0,13),Vector2(-12,3)], tint, pale)
			for side in [-1.0,1.0]:
				var phase: float = anim_time*15.0 + side
				_line(Vector2(side*17,-13),Vector2(side*(26+sin(phase)*5),-5),bright,2.5)
				_line(Vector2(side*(26+sin(phase)*5),-5),Vector2(side*20,5),Color.WHITE,1.5)
				_line(Vector2(side*20,5),Vector2(side*29,15),bright,2.5)
		5: # Магнит — два полюса притягивают движущиеся опилки.
			_poly([Vector2(-19,-13),Vector2(-7,-22),Vector2(7,-22),Vector2(19,-13),Vector2(17,13),Vector2(8,22),Vector2(-8,22),Vector2(-17,13)], dark, bright, 3.0)
			_poly([Vector2(-15,-10),Vector2(-2,-10),Vector2(-2,13),Vector2(-13,13)], tint, pale)
			_poly([Vector2(2,-10),Vector2(15,-10),Vector2(13,13),Vector2(2,13)], mid, bright)
			_line(Vector2(-12,0),Vector2(-5,0),Color.WHITE,2.0)
			_line(Vector2(-8,-4),Vector2(-8,4),Color.WHITE,2.0)
			_line(Vector2(5,0),Vector2(12,0),Color.WHITE,2.0)
			for i in 6:
				var a := anim_time*1.5 + TAU*float(i)/6.0
				var r := 29.0 + sin(anim_time*3.0+float(i))*4.0
				_dot(Vector2.from_angle(a)*r, 2.0, bright)
		6: # Слизень — вязкое тело с меняющимися боками.
			var squeeze := sin(anim_time*3.2)
			_poly([Vector2(-22,-5),Vector2(-16,-16-squeeze*3),Vector2(0,-18),Vector2(18,-13+squeeze*3),Vector2(23,3),Vector2(15,17),Vector2(-5,22),Vector2(-21,13)], tint, bright, 3.0)
			_poly([Vector2(-11,-5),Vector2(-5,-11),Vector2(5,-10),Vector2(12,-3),Vector2(8,4),Vector2(-8,4)], pale, Color.WHITE, 1.0)
			for i in 4:
				var y := sin(anim_time*2.0+float(i))*8.0
				_dot(Vector2(-12.0+float(i)*8.0,y+8.0),2.0,bright)
			_dot(Vector2(20.0+sin(anim_time*2.4)*3.0,-20.0-cos(anim_time*2.4)*3.0),3.0,pale)
		7: # Сверхнова — ядро сжимается, лучи вспыхивают по очереди.
			var core := 7.0 + pulse*4.0
			for i in 12:
				var a := TAU*float(i)/12.0
				var inner := 17.0 + pulse*3.0
				var outer := 27.0 + pulse*12.0
				_line(Vector2.from_angle(a)*inner,Vector2.from_angle(a)*outer,Color(bright,0.35+0.65*pulse),2.0)
			_dot(Vector2.ZERO,core,bright)
			_dot(Vector2.ZERO,core*0.42,Color.WHITE)
			_ring(Vector2.ZERO,14.0+pulse*5.0,Color(bright,0.55),1.5)
		8: # Мираж — две копии сдвигаются и растворяются.
			var drift := sin(anim_time*2.2)*7.0
			_poly([Vector2(-12,-19)+Vector2(-drift,0),Vector2(12,-19)+Vector2(-drift,0),Vector2(18,0)+Vector2(-drift,0),Vector2(0,22)+Vector2(-drift,0),Vector2(-18,0)+Vector2(-drift,0)],Color(tint,0.24),Color(bright,0.42),2.0)
			_poly([Vector2(-12,-19)+Vector2(drift,0),Vector2(12,-19)+Vector2(drift,0),Vector2(18,0)+Vector2(drift,0),Vector2(0,22)+Vector2(drift,0),Vector2(-18,0)+Vector2(drift,0)],Color(tint,0.24),Color(bright,0.42),2.0)
			_poly([Vector2(0,-21),Vector2(15,-7),Vector2(12,12),Vector2(0,24),Vector2(-12,12),Vector2(-15,-7)],dark,bright,3.0)
			_line(Vector2(-7,-3),Vector2(7,-3),Color.WHITE,2.0)
		9: # Осколок — сегменты вращаются вокруг острого ядра.
			for i in 3:
				var a := anim_time*0.7+TAU*float(i)/3.0
				var v := Vector2.from_angle(a)
				_poly([v*17.0,v.rotated(0.32)*31.0,v.rotated(0.62)*18.0],bright,Color.WHITE,1.5)
			_poly([Vector2(0,-17),Vector2(13,0),Vector2(0,17),Vector2(-13,0)],dark,bright,2.5)
			_line(Vector2(-5,-5),Vector2(5,5),Color.WHITE,1.5)
		10: # Сингулярность — линза изгибает дуги вокруг тёмного центра.
			for i in 3:
				var r := 22.0+float(i)*6.0
				var shift := sin(anim_time*1.4+float(i))*0.45
				_ring(Vector2(shift*7.0,0),r,Color(bright,0.5-float(i)*0.1),1.8,0.25+shift,2.7+shift)
				_ring(Vector2(-shift*7.0,0),r,Color(bright,0.5-float(i)*0.1),1.8,3.35+shift,5.8+shift)
			_dot(Vector2.ZERO,12.0,dark)
			_dot(Vector2.ZERO,4.0,bright)
		11: # Рикошет — последовательный пробег блика по шевронам.
			for i in 3:
				var yy := -14.0+float(i)*14.0
				var active := 0.35+0.65*(0.5+0.5*sin(anim_time*5.0-float(i)*1.7))
				_line(Vector2(-20,yy-7),Vector2(0,yy+7),Color(bright,active),3.0)
				_line(Vector2(0,yy+7),Vector2(20,yy-7),Color(bright,active),3.0)
		12: # Вулкан — трещины пульсируют, искры поднимаются.
			_poly([Vector2(-18,10),Vector2(-17,-9),Vector2(-7,-21),Vector2(7,-17),Vector2(19,-7),Vector2(17,12),Vector2(5,22),Vector2(-11,19)],dark,mid,3.0)
			var heat := 0.45+0.55*pulse
			_line(Vector2(-10,10),Vector2(-2,-2),Color(bright,heat),3.0)
			_line(Vector2(-2,-2),Vector2(8,5),Color(bright,heat),3.0)
			_line(Vector2(8,5),Vector2(13,-9),Color(bright,heat),2.0)
			for i in 4:
				var rise := fposmod(anim_time*22.0+float(i)*11.0,28.0)
				_dot(Vector2(sin(anim_time*3.0+float(i))*14.0,12.0-rise),1.5,Color(bright,1.0-rise/35.0))
		13: # Паразит — усики сокращаются, по ним бегут узлы.
			_poly([Vector2(-14,-12),Vector2(0,-21),Vector2(14,-12),Vector2(18,8),Vector2(0,22),Vector2(-18,8)],dark,bright,3.0)
			for side in [-1.0,1.0]:
				var tip := Vector2(side*(25.0+sin(anim_time*3.0+side)*5.0),-28.0+sin(anim_time*2.0+side)*4.0)
				_line(Vector2(side*9,-12),tip,bright,3.0)
				_dot(tip,3.0,Color.WHITE)
				_dot(Vector2(side*17,3)+Vector2(0,sin(anim_time*4.0+side)*7.0),2.5,pale)
			_ring(Vector2.ZERO,11.0+sin(anim_time*2.0)*2.0,bright,1.5)
		14: # Маятник — груз качается на подвесе.
			var angle := sin(anim_time*2.3)*0.72
			var end := Vector2(0,-2).rotated(angle)+Vector2(0,25)
			_poly([Vector2(-17,-18),Vector2(17,-18),Vector2(13,-5),Vector2(-13,-5)],dark,bright,2.5)
			_line(Vector2(0,-7),end,bright,3.0)
			_ring(Vector2(0,25),27.0,Color(bright,0.3),1.5,PI*1.15,PI*1.85)
			_poly([end+Vector2(0,-10),end+Vector2(10,0),end+Vector2(0,10),end+Vector2(-10,0)],tint,pale,2.0)
		15: # Губка — поры открываются и закрываются.
			var swell := 1.0+0.13*sin(anim_time*2.6)
			_poly([Vector2(-18,-17),Vector2(0,-22*swell),Vector2(18,-15),Vector2(22,4),Vector2(10,20),Vector2(-12,18),Vector2(-22,3)],dark,bright,3.0)
			for i in 9:
				var a := TAU*float(i)/9.0
				var r := 13.0*swell
				_ring(Vector2.from_angle(a)*r,2.0+1.2*pulse,bright,1.2)
			_dot(Vector2.ZERO,5.0,tint)
		16: # Генератор — четыре катушки включаются по кругу.
			_poly([Vector2(-16,-16),Vector2(16,-16),Vector2(21,0),Vector2(16,16),Vector2(-16,16),Vector2(-21,0)],dark,bright,3.0)
			for i in 4:
				var a := TAU*float(i)/4.0
				var lit := 0.3+0.7*(0.5+0.5*sin(anim_time*4.0-float(i)*PI/2.0))
				_dot(Vector2.from_angle(a)*27.0,4.0,Color(bright,lit))
				_line(Vector2.from_angle(a)*16.0,Vector2.from_angle(a)*23.0,Color(bright,lit),2.0)
			_ring(Vector2.ZERO,9.0,bright,2.0)
			_dot(Vector2.ZERO,4.0,Color.WHITE)
		17: # Полярность — две половины сближаются и расходятся.
			var separation := 12.0+sin(anim_time*2.0)*3.0
			_dot(Vector2(-separation,0),13.0,dark)
			_dot(Vector2(separation,0),13.0,mid)
			_ring(Vector2(-separation,0),13.0,bright,2.0,0.0,PI)
			_ring(Vector2(separation,0),13.0,bright,2.0,PI,TAU)
			_line(Vector2(-separation-5,0),Vector2(-separation+5,0),Color.WHITE,2.0)
			_line(Vector2(separation-5,0),Vector2(separation+5,0),Color.WHITE,2.0)
		18: # Фантом — быстрые послесвечения появляются и стираются.
			var offset := sin(anim_time*4.0)*9.0
			for i in 3:
				var trail := Vector2(-offset-float(i)*7.0,0)
				var alpha := 0.16+0.18*float(3-i)
				_poly([trail+Vector2(0,-19),trail+Vector2(14,-5),trail+Vector2(10,14),trail+Vector2(0,22),trail+Vector2(-10,14),trail+Vector2(-14,-5)],Color(tint,alpha),Color(bright,alpha+0.12),1.5)
			_poly([Vector2(0,-20),Vector2(15,-6),Vector2(12,12),Vector2(0,23),Vector2(-12,12),Vector2(-15,-6)],dark,bright,3.0)
			_line(Vector2(-7,-3),Vector2(7,-3),Color.WHITE,2.0)

	# Костюмы и головные уборы тонируются от палитры игрока, а не от жёстких RGB-констант.
	if outfit > 0:
		var cloth := tint.darkened(0.38+float(outfit)*0.045)
		match outfit:
			1: _poly([Vector2(-13,4),Vector2(13,4),Vector2(10,17),Vector2(-10,17)],cloth,bright,1.5)
			2:
				_line(Vector2(-13,0),Vector2(13,0),bright,2.0)
				_line(Vector2(-12,6),Vector2(12,6),bright,2.0)
			3: _ring(Vector2.ZERO,24.0,Color(bright,0.75),2.0)
			4: _poly([Vector2(-13,-2),Vector2(13,-2),Vector2(18,19),Vector2(0,25),Vector2(-18,19)],cloth,bright,2.0)
	if hat > 0:
		var hat_color := tint.lightened(0.22+float(hat)*0.08)
		match hat:
			1: _poly([Vector2(-17,-24),Vector2(-12,-38),Vector2(-4,-30),Vector2(0,-43),Vector2(5,-30),Vector2(13,-38),Vector2(18,-24)],hat_color,Color.WHITE,2.0)
			2: _poly([Vector2(-17,-23),Vector2(17,-23),Vector2(12,-34),Vector2(-12,-34)],hat_color,Color.WHITE,2.0)
			3: _poly([Vector2(-15,-22),Vector2(-25,-36),Vector2(-5,-28),Vector2(0,-22),Vector2(7,-28),Vector2(25,-36),Vector2(15,-22)],hat_color,Color.WHITE,2.0)
			4: _ring(Vector2(0,-28),13.0,Color(hat_color,0.9),3.0,PI,TAU)
