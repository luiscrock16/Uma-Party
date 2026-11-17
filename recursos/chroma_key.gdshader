shader_type canvas_item;

uniform vec4 chroma_key_color : source_color = vec4(0.0, 1.0, 0.0, 1.0);
uniform float similarity : hint_range(0.0, 1.0) = 0.4;
uniform float smoothness : hint_range(0.0, 1.0) = 0.05;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	float diff = distance(tex_color.rgb, chroma_key_color.rgb);
	tex_color.a *= smoothstep(similarity, similarity + smoothness, diff);
	COLOR = tex_color;
}
