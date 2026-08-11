// shaders/grass.gdshader
// Full-geometry grass shader (restored from 026850c, the USER-APPROVED look):
// shading (AO gradient, translucency, specular), patchiness via seamless
// world-space noise, and wind gusts. Blades are thin ribbon quads with
// UV.y = 1 at the base and 0 at the tip. Each MultiMesh instance is a tuft
// (sward disc + blades), so patch/wind noise is sampled per instance from the
// instance's world position (MODEL_MATRIX column 3 - NODE_POSITION_WORLD is
// only the chunk origin for MultiMesh, which would chunk-quantise the noise).

shader_type spatial;
render_mode cull_disabled;

uniform vec3 color_small : source_color = vec3(0.24, 0.42, 0.16);
uniform vec3 color_large : source_color = vec3(0.55, 0.78, 0.34);
uniform sampler2D patch_noise;
uniform float patch_scale = 6.0;
uniform float size_small = 1.0;
uniform float size_large = 1.15;
uniform float blade_bend = 0.35;

uniform sampler2D wind_noise;
uniform float wind_strength = 0.12;
uniform float wind_scale = 9.0;
uniform float wind_ao_affect = 0.35;
uniform vec2 wind_direction = vec2(0.7, -0.5);

uniform vec3 backlight : source_color = vec3(0.18, 0.3, 0.12);
uniform float roughness = 0.4;
uniform float specular = 0.2;

// Sun direction (set each frame by grass_system.gd from GameState.day_time, in
// sync with daynight.gd). The far-tier sward discs are flat and face straight
// up, so at low sun they catch almost no direct light while the near blades
// (outward-leaning faces) stay bright. Tilting the disc normal toward the sun
// the lower it gets makes the far field catch the sun exactly like the blades.
uniform float sun_elev = 0.0;
uniform float sun_azim = 0.0;

varying float bottom_to_top;
varying float patch_factor;
varying float current_wind_bend;
varying float mottle;
varying float mottle2;
varying vec3 world_vertex;

void vertex() {
	bottom_to_top = 1.0 - UV.y;

	vec2 inst_pos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xz;

	// Sward disc (UV.x = 2 marker): the solid base under a tuft - skip wind and
	// rest-bend so the lawn base never ripples or leans.
	if (UV.x <= 1.0) {
		// Wind: a scrolling world-space noise moves gusts through the field.
		vec2 wind_position = inst_pos / wind_scale;
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
	patch_factor = texture(patch_noise, inst_pos / patch_scale).r;
	VERTEX *= mix(size_small, size_large, patch_factor);

	// Fine mottle sampled at blade scale - breaks the lawn up so it never reads
	// as a flat uniform carpet (applied to ALBEDO in fragment()).
	mottle = texture(patch_noise, inst_pos / 0.3).r;
	// Medium-scale clump variation (mowed-lawn patches).
	mottle2 = texture(patch_noise, inst_pos / 1.4).r;

	world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
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

	// Per-blade base->tip gradient (COLOR) on top of the clump palette. The disc
	// sits darker so bright blade tips pop against the base. Three world-space
	// noise scales give the field a rich mottled look instead of a flat carpet.
	vec3 base_albedo = mix(color_small, color_large, patch_factor) * COLOR.rgb;
	float fm = texture(patch_noise, world_vertex.xz / 0.05).r;
	if (UV.x > 1.0)
		ALBEDO = base_albedo * mix(0.55, 1.05, mottle) * mix(0.8, 1.2, mottle2) * mix(0.85, 1.15, fm);
	else
		ALBEDO = base_albedo * mix(0.85, 1.15, mottle) * mix(0.9, 1.1, mottle2) * mix(0.9, 1.1, fm);

	// Translucency (grass glows through).
	BACKLIGHT = backlight;
	ROUGHNESS = roughness;
	SPECULAR = specular;
}
