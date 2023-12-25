shader_type canvas_item;
render_mode skip_vertex_transform;

uniform vec4 color_to_replace : source_color;
uniform vec4 new_color : source_color;

uniform sampler2D dijkstra_image : source_color, filter_nearest;
uniform int dijkstra_image_scale = 32;
uniform vec2 dijkstra_image_offset;
uniform int image_max_channel_value = 256;
uniform int dijkstra_pathfinding_rollover = 80;
uniform int dijkstra_max_cost = 100;
uniform float highlight_threshold = 3.0;
uniform float tilemap_fill_speed = 5.0;

uniform vec2 tilemap_cell_size = vec2(36, 22);
uniform vec2 tilemap_world_size = vec2(1152, 704);

varying vec2 full_uv_pos;

// Standard vec4 color channels are floats, so we need a threshold to check between
bool color_approx_equal(vec4 color1, vec4 color2){
	return (
	color1.r >= color2.r - 0.001 && color1.r <= color2.r + 0.001 &&
	color1.g >= color2.g - 0.001 && color1.g <= color2.g + 0.001 &&
	color1.b >= color2.b - 0.001 && color1.b <= color2.b + 0.001 && 
	color1.a >= color2.a - 0.001 && color1.a <= color2.a + 0.001);
}

void vertex(){
	VERTEX = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	full_uv_pos = (VERTEX) / tilemap_world_size;
}

void fragment() {
	if (color_approx_equal(COLOR, color_to_replace)){
		COLOR = new_color;
	}
	vec2 offset = dijkstra_image_offset / tilemap_world_size;
	float dijkstra_strength = texture(dijkstra_image, full_uv_pos - offset).r;
	float cost = ceil(dijkstra_strength * float(image_max_channel_value));
	
	float adjusted_dijkstra_stength = float(image_max_channel_value / dijkstra_max_cost) * dijkstra_strength;
	
	float highlight_midpoint = mod(
		TIME * tilemap_fill_speed, 
		(float(dijkstra_pathfinding_rollover)) + 2.0 * highlight_threshold
	) - highlight_threshold;
	
	float highlight_strength = 1.0 - abs(cost - highlight_midpoint) / highlight_threshold;
	
	if(COLOR != new_color && cost > 0.0 && highlight_strength > 0.0){
		COLOR.rgb *= (1.0 - highlight_strength);
		COLOR.r += highlight_strength * (1.0 - adjusted_dijkstra_stength);
		//COLOR.g += highlight_strength * (1.0 - abs(fract(adjusted_dijkstra_stength) - .5) * 2.0);
		COLOR.b += highlight_strength * adjusted_dijkstra_stength;
	}
}