shader_type canvas_item;
// Gravity-flip plein ecran (06 §3) : lisible, pas injouable.
// Utilise sur un ColorRect du HUD pendant gravity_inversion.
uniform vec4 tint : source_color = vec4(0.55, 0.3, 1.0, 0.25);
uniform float wobble_speed = 2.0;

void fragment() {
	float w = sin(UV.y * 20.0 + TIME * wobble_speed) * 0.02;
	vec2 uv = UV + vec2(w, 0.0);
	vec4 base = texture(TEXTURE, uv);
	// Inversion subtile : on teinte violet + ondule.
	COLOR = vec4(mix(base.rgb, tint.rgb, tint.a), base.a);
}
