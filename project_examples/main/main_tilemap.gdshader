// Shader applied to a TileMap designed to do the following:
// 1. Display a "crawling" color shifting visual effect onto the empty tiles of the tilemap where
//	early tiles start out red, and gradually shift to blue as the effect transitions to later tiles
//	in the map. This is achieved by passing in a "dijkstra image" - a red-channel-only image where
//	each pixel represents a tile on the map, and the value of each pixel's red channel indicates its
//	cost from the starting point (wall tiles have a value of 0).
// 2. Replace the gray color of the tiles' outline dashes with black for a cleaner look, without
//	needing to supply a new tile atlas image.
shader_type canvas_item;
// Manually calculate Vertex pos for easier alignment with the given dijkstra image.
render_mode skip_vertex_transform;
// Specify the exact gray color on the tiles to be replaced with another color (black).
uniform vec4 color_to_replace : source_color;
uniform vec4 new_color : source_color;
// Red-channel-only image where the value represents the Dijsktra cost at each node.
uniform sampler2D dijkstra_image : source_color, filter_nearest;
uniform vec2 dijkstra_image_offset; // Line up the image with the tilemap's offset
uniform int image_max_channel_value = 255; // Highest *possible* red channel value in the image
uniform int dijkstra_pathfinding_rollover = 100; // # of tiles to fill before restarting the effect
uniform int dijkstra_max_cost = 100; // Highest red channel value that actually appears in the image
uniform float highlight_threshold = 3.0; // Distance/radius of the color fill effect
uniform float tilemap_fill_speed = 10.0; // Speed multiplier applied to the color fill effect
uniform vec2 tilemap_world_size = vec2(1152, 704); // Full size of the tilemap to scale the image to

varying vec2 full_uv_pos; // Calculate the world vertex pos to align tiles on the dijkstra image

// Standard vec4 color channels are floats, so we need a threshold to check between
bool color_approx_equal(vec4 color1, vec4 color2){
	return (
	color1.r >= color2.r - 0.001 && color1.r <= color2.r + 0.001 &&
	color1.g >= color2.g - 0.001 && color1.g <= color2.g + 0.001 &&
	color1.b >= color2.b - 0.001 && color1.b <= color2.b + 0.001 && 
	color1.a >= color2.a - 0.001 && color1.a <= color2.a + 0.001);
}

// Calculate the world position of each point in the tilemap
void vertex(){
	VERTEX = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	full_uv_pos = (VERTEX) / tilemap_world_size;
}

// Replace gray dash colors with black, and apply the color shifting effect
void fragment() {
	// Replace colors as needed.
	if (color_approx_equal(COLOR, color_to_replace)){
		COLOR = new_color;
	}
	// Find the red channel value at this pixel and convert it back to a real cost value.
	vec2 offset = dijkstra_image_offset / tilemap_world_size;
	float dijkstra_strength = texture(dijkstra_image, full_uv_pos - offset).r;
	float cost = ceil(dijkstra_strength * float(image_max_channel_value));
	// Since the image will most likely have a much lower highest value than the maximum possible
	// red channel value, the endpoint won't be fully blue in color by default, so adjust the
	// strength of the effect to a value between 0.0 to 1.0.
	float adjusted_dijkstra_stength = float(image_max_channel_value / dijkstra_max_cost) * dijkstra_strength;
	// Find the value that should be fully highlighted at this point in time.
	float highlight_midpoint = mod(
		TIME * tilemap_fill_speed, 
		(float(dijkstra_pathfinding_rollover)) + 2.0 * highlight_threshold
	) - highlight_threshold;
	// Determine how strong the highlight effect should be for this tile.
	float highlight_strength = 1.0 - abs(cost - highlight_midpoint) / highlight_threshold;
	// If this tile should be highlighted, fill it in with a color ranging from full red to full
	// blue depending on the dijkstra cost.
	if(COLOR != new_color && cost > 0.0 && highlight_strength > 0.0){
		COLOR.rgb *= (1.0 - highlight_strength);
		COLOR.r += highlight_strength * (1.0 - adjusted_dijkstra_stength);
		COLOR.b += highlight_strength * adjusted_dijkstra_stength;
	}
}