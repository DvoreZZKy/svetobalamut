extends Node2D
class_name VectorActor

var kind := 0
var tint := Color("#54eaff")
var outfit := 0
var hat := 0

func setup(p_kind: int, p_tint: Color, p_outfit: int, p_hat: int) -> void:
	var next_kind := posmod(p_kind, 4)
	var next_outfit := posmod(p_outfit, 5)
	var next_hat := posmod(p_hat, 5)
	if kind == next_kind and tint == p_tint and outfit == next_outfit and hat == next_hat:
		return
	kind = next_kind
	tint = p_tint
	outfit = next_outfit
	hat = next_hat
	queue_redraw()

func _poly(points: Array, color: Color, outline := true) -> void:
	var p := PackedVector2Array(points)
	draw_colored_polygon(p, color)
	if outline:
		var closed := p.duplicate()
		closed.append(p[0])
		draw_polyline(closed, Color("#11182b"), 2.5, true)

func _draw() -> void:
	var dark := tint.darkened(0.58)
	var mid := tint
	var light := tint.lightened(0.48)
	match kind:
		0:
			# Firefly: segmented body, angular wings and antennae.
			_poly([Vector2(-8,-5),Vector2(-20,-18),Vector2(-25,-16),Vector2(-20,-3),Vector2(-9,5)], light)
			_poly([Vector2(8,-5),Vector2(20,-18),Vector2(25,-16),Vector2(20,-3),Vector2(9,5)], light)
			_poly([Vector2(-8,-7),Vector2(-4,-18),Vector2(4,-18),Vector2(8,-7),Vector2(7,12),Vector2(0,19),Vector2(-7,12)], dark)
			_poly([Vector2(-5,-5),Vector2(-2,-14),Vector2(3,-14),Vector2(5,-4),Vector2(4,10),Vector2(0,15),Vector2(-4,10)], mid, false)
			_poly([Vector2(-4,5),Vector2(4,5),Vector2(5,12),Vector2(0,17),Vector2(-5,12)], Color("#ffe47b"), false)
			draw_line(Vector2(-4,-16),Vector2(-12,-26),light,2.5,true)
			draw_line(Vector2(4,-16),Vector2(12,-26),light,2.5,true)
			draw_circle(Vector2(-2,-7),2.0,Color("#10182c"))
			draw_circle(Vector2(3,-7),2.0,Color("#10182c"))
		1:
			# Capsule: a clear upright capsule shell with flat end caps and visor.
			_poly([Vector2(-12,-22),Vector2(8,-22),Vector2(15,-15),Vector2(15,14),Vector2(8,22),Vector2(-8,22),Vector2(-15,14),Vector2(-15,-14)], dark)
			_poly([Vector2(-9,-18),Vector2(7,-18),Vector2(11,-13),Vector2(11,12),Vector2(6,17),Vector2(-6,17),Vector2(-11,12),Vector2(-11,-12)], mid, false)
			_poly([Vector2(-8,-12),Vector2(7,-12),Vector2(9,-8),Vector2(9,2),Vector2(-9,2),Vector2(-9,-8)], Color("#14243d"))
			_poly([Vector2(-6,-10),Vector2(0,-10),Vector2(-3,-3),Vector2(-8,-3)], Color("#d9fbff"), false)
			_poly([Vector2(-8,7),Vector2(8,7),Vector2(6,14),Vector2(-6,14)], light, false)
			_poly([Vector2(-20,-7),Vector2(-14,-10),Vector2(-12,9),Vector2(-19,7)], Color("#ffad58"))
			_poly([Vector2(20,-7),Vector2(14,-10),Vector2(12,9),Vector2(19,7)], Color("#ffad58"))
		2:
			# Ghost: domed head and a faceted, scalloped tail.
			_poly([Vector2(-17,14),Vector2(-19,-3),Vector2(-15,-17),Vector2(-7,-23),Vector2(7,-23),Vector2(15,-17),Vector2(19,-3),Vector2(17,14),Vector2(9,9),Vector2(2,17),Vector2(-5,10),Vector2(-12,17)], dark)
			_poly([Vector2(-13,11),Vector2(-15,-3),Vector2(-11,-15),Vector2(-5,-19),Vector2(5,-19),Vector2(11,-14),Vector2(15,-2),Vector2(13,10),Vector2(8,6),Vector2(2,13),Vector2(-5,6),Vector2(-10,12)], light, false)
			_poly([Vector2(-8,-12),Vector2(-1,-17),Vector2(8,-12),Vector2(11,-3),Vector2(5,1),Vector2(-7,1)], Color("#f5f1ff"), false)
			draw_circle(Vector2(-5,-3),2.3,Color("#24203e"))
			draw_circle(Vector2(6,-3),2.3,Color("#24203e"))
			draw_line(Vector2(-2,5),Vector2(3,5),Color("#7557b9"),2.0,true)
		3:
			# Crystal: faceted diamond prism, matching the heavy artillery class.
			_poly([Vector2(0,-25),Vector2(15,-12),Vector2(19,5),Vector2(0,24),Vector2(-19,5),Vector2(-15,-12)], dark)
			_poly([Vector2(0,-20),Vector2(10,-10),Vector2(13,4),Vector2(0,18),Vector2(-13,4),Vector2(-10,-10)], mid, false)
			_poly([Vector2(0,-20),Vector2(10,-10),Vector2(0,0),Vector2(-10,-10)], light, false)
			_poly([Vector2(0,0),Vector2(13,4),Vector2(0,18),Vector2(-2,3)], tint.darkened(0.12), false)
			_poly([Vector2(0,-20),Vector2(-10,-10),Vector2(-13,4),Vector2(-2,3)], tint.lightened(0.25), false)
			draw_line(Vector2(-7,-10),Vector2(0,-17),Color.WHITE,1.8,true)
	# Geometric costume overlay.
	if outfit > 0:
		var cloth := [Color("#26334f"),Color("#f4d35e"),Color("#3ddc97"),Color("#f05d9b"),Color("#d6e4ff")][outfit]
		match outfit:
			1:
				_poly([Vector2(-13,-1),Vector2(13,-1),Vector2(11,14),Vector2(5,19),Vector2(-5,19),Vector2(-11,14)], cloth)
				draw_line(Vector2(0,0),Vector2(0,16),Color.WHITE,2.0,true)
			2:
				_poly([Vector2(-15,0),Vector2(15,0),Vector2(11,17),Vector2(-11,17)], cloth)
				for yy in [-8,0,8]:
					draw_line(Vector2(-10,yy),Vector2(10,yy),Color("#26334f"),2.0,true)
			3:
				_poly([Vector2(-12,-3),Vector2(12,-3),Vector2(16,17),Vector2(0,12),Vector2(-16,17)], cloth)
				draw_line(Vector2(-9,2),Vector2(9,2),Color.WHITE,2.0,true)
			4:
				_poly([Vector2(-10,-3),Vector2(10,-3),Vector2(17,22),Vector2(0,16),Vector2(-17,22)], cloth)
	# Hats are separate angular silhouettes above the head.
	match hat:
		1:
			_poly([Vector2(-15,-21),Vector2(-11,-33),Vector2(-4,-27),Vector2(0,-39),Vector2(5,-27),Vector2(12,-33),Vector2(16,-21)], Color("#ffd65c"))
		2:
			_poly([Vector2(-17,-22),Vector2(17,-22),Vector2(12,-32),Vector2(-12,-32)], Color("#e85e7e"))
		3:
			_poly([Vector2(-15,-21),Vector2(-25,-35),Vector2(-5,-27),Vector2(0,-21),Vector2(7,-27),Vector2(25,-35),Vector2(15,-21)], Color("#b88cff"))
		4:
			_poly([Vector2(-16,-26),Vector2(-10,-39),Vector2(0,-44),Vector2(10,-39),Vector2(16,-26),Vector2(9,-30),Vector2(-9,-30)], Color("#9cefff"))
