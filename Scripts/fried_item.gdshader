shader_type canvas_item;
// Two-sided doneness: the top half of the texture is side A, the bottom half is side B.
// Because the sprite rotates with the body you can see which side has browned.

uniform vec4 side_a_color : source_color = vec4(1.0);
uniform vec4 side_b_color : source_color = vec4(1.0);
// Where the split between the two sides is, in texture UV (fishball.png is centred a bit high).
uniform float split = 0.46;
uniform float softness = 0.12;
// 0..1 white flash used for the "perfectly golden" pulse.
uniform float flash = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float t = smoothstep(split - softness, split + softness, UV.y);
	vec3 tint = mix(side_a_color.rgb, side_b_color.rgb, t);
	vec3 rgb = mix(tex.rgb * tint, vec3(1.0), flash);
	COLOR = vec4(rgb, tex.a * COLOR.a);
}
