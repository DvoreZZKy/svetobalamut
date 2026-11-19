shader_type canvas_item;
render_mode blend_add;
// Неоновый трейл для Line2D: цвет берётся из uniform и поднимается в HDR,
// чтобы WorldEnvironment-glow разгонял его в яркое свечение.
// Альфа и сужение приходят из gradient / width_curve самого Line2D.

uniform vec4 tint : source_color = vec4(0.2, 1.0, 1.0, 1.0);
uniform float hdr = 3.0;

void fragment() {
	float core = smoothstep(0.0, 0.5, 1.0 - abs(UV.y - 0.5) * 2.0);
	vec3 c = tint.rgb * hdr * (0.55 + 0.9 * core);
	COLOR = vec4(c, COLOR.a * tint.a * (0.35 + 0.65 * core));
}
