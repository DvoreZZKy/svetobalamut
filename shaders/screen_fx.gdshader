shader_type canvas_item;
// Полноэкранные хаос-эффекты: инверсия света/тьмы, слепота (виден круг вокруг игрока),
// хроматическая аберрация на вспышках, лёгкая виньетка.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float invert : hint_range(0.0, 1.0) = 0.0;
uniform float blind : hint_range(0.0, 1.0) = 0.0;
uniform vec2 center = vec2(0.5, 0.5);
uniform float radius = 0.16;
uniform float aspect = 1.7778;
uniform float aberr = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c;
	c.r = texture(screen_tex, uv + vec2(aberr, 0.0)).r;
	c.g = texture(screen_tex, uv).g;
	c.b = texture(screen_tex, uv - vec2(aberr, 0.0)).b;
	vec3 inv = max(vec3(1.0) - min(c, vec3(1.0)), vec3(0.0));
	c = mix(c, inv, invert);
	vec2 d = (uv - center) * vec2(aspect, 1.0);
	float m = 1.0 - smoothstep(radius * 0.55, radius, length(d));
	c *= mix(1.0, m, blind);
	float vig = 1.0 - 0.35 * smoothstep(0.55, 1.1, length((uv - 0.5) * vec2(1.0, 0.9)));
	COLOR = vec4(c * vig, 1.0);
}
