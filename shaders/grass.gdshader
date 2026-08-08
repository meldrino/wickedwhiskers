// shaders/grass.gdshader
// Full-geometry grass shader, adapted from the hexaquo.at grass-rendering series
// (parts 2 + 3): shading (AO gradient, translucency, specular), patchiness via
// seamless world-space noise, and wind gusts. Blades are thin ribbon quads with
// UV.y = 1 at the base and 0 at the tip. Each MultiMesh instance is a tuft of
// several blades, so patch/wind noise is sampled per instance from
// NODE_POSITION_WORLD.

shader_type spatial;
render_mode cull_disabled;

uniform vec3 color_small : source_color = vec3(0.24, 0.42, 0.16);
uniform vec3 color_large : source_color = vec3(0.55, 0.78, 0.34);
uniform sampler2D patch_noise;
uniform float patch_scale = 6.0;
uniform float size_small = 0.8;
uniform float size_large = 1.25;
uniform float blade_bend = 0.35;

uniform sampler2D wind_noise;
uniform float wind_strength = 0.12;
uniform float wind_scale = 9.0;
uniform float wind_ao_affect = 0.35;
uniform vec2 wind_direction = vec2(0.7, -0.5);

uniform vec3 backlight : source_color = vec3(0.18, 0.3, 0.12);
uniform float roughness = 0.4;
uniform float specular = 0.2;

varying float bottom_to_top;
varying float patch_factor;
varying float current_wind_bend;

void vertex() {
	bottom_to_top = 1.0 - UV.y;

	// Sward disc (UV.x = 2 marker): the solid base under a tuft - skip wind and
	// rest-bend so the lawn base never ripples or leans.
	if (UV.x <= 1.0) {
		// Wind: a scrolling world-space noise moves gusts through the field.
		vec2 wind_position = NODE_POSITION_WORLD.xz / wind_scale;
		wind_position -= (TIME + 8.0) * wind_direction * wind_strength;
		current_wind_bend = texture(wind_noise, wind_position).x;
		current_wind_bend *= wind_strength;
		current_wind_bend *= bottom_to_top * 2.0;

		// Gentle rest bend of the tip (more bend the higher up the blade).
		VERTEX.z += blade_bend * pow(bottom_to_top, 2.0);

		// Wind direction is world-space, but blades are randomly rotated, so
		// rotate the direction into this instance's local space.
		mat4 inv_model = inverse(MODEL_MATRIX);
		vec2 local_direction = (inv_model * vec4(wind_direction.x, 0.0, wind_direction.y, 0.0)).xz;
		VERTEX.xz += current_wind_bend * local_direction;
	}

	// Patchiness: clumps of taller/shorter grass from seamless world-space noise.
	patch_factor = texture(patch_noise, NODE_POSITION_WORLD.xz / patch_scale).r;
	VERTEX *= mix(size_small, size_large, patch_factor);
}

void fragment() {
	// With cull_disabled the renderer flips back-face normals; undo that so the
	// custom up-mixing normals stay consistent on both sides of a blade.
	if (!FRONT_FACING)
		NORMAL = -NORMAL;

	if (UV.x > 1.0) {
		// Sward disc: fully lit flat base (darkening comes from its vertex color).
		AO = 1.0;
		NORMAL = vec3(0.0, 1.0, 0.0);
	} else {
		// Self-shadowing: tips bright, base dark; wind-bent grass darkens further.
		AO = bottom_to_top - current_wind_bend * wind_ao_affect;
		// Fake rounded tips: normals lean toward straight-up at the top, which is
		// what gives individual blades their bright specular catch.
		NORMAL = mix(NORMAL, vec3(0.0, 1.0, 0.0), bottom_to_top);
	}
	AO_LIGHT_AFFECT = 1.0;

	// Per-blade base->tip gradient (COLOR) on top of the clump palette.
	ALBEDO = mix(color_small, color_large, patch_factor) * COLOR.rgb;

	// Translucency (grass glows through) + softer specular highlights.
	BACKLIGHT = backlight;
	ROUGHNESS = roughness;
	SPECULAR = specular;
}
