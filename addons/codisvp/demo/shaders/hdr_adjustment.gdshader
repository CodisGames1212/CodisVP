shader_type canvas_item;

uniform float contrast = 1.0;
uniform float saturation = 1.0;

void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	vec3 adjusted = (source.rgb - vec3(0.5)) * contrast + vec3(0.5);
	float luminance = dot(adjusted, vec3(0.2126, 0.7152, 0.0722));
	adjusted = mix(vec3(luminance), adjusted, saturation);
	COLOR = vec4(clamp(adjusted, vec3(0.0), vec3(1.0)), source.a);
}
